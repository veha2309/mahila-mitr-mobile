-- Conversation subjects with one adjustable expiry shared by every message.
-- Run after 20260922_ephemeral_chat.sql.

create table if not exists public.ephemeral_conversations (
  id uuid primary key default gen_random_uuid(),
  link_id uuid not null references public.links(id) on delete cascade,
  subject text not null check (char_length(trim(subject)) between 1 and 80),
  created_by uuid not null references auth.users(id) on delete cascade,
  ttl_minutes integer not null check (ttl_minutes between 10 and 1440),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null
);
create index if not exists ephemeral_conversations_link_expiry_idx
  on public.ephemeral_conversations(link_id, expires_at desc);
alter table public.ephemeral_conversations enable row level security;
drop policy if exists ephemeral_conversations_linked_realtime on public.ephemeral_conversations;
create policy ephemeral_conversations_linked_realtime on public.ephemeral_conversations
  for select to authenticated using (exists (
    select 1 from public.links l where l.id = ephemeral_conversations.link_id
      and auth.uid() in (l.owner_id, l.partner_id)
  ));
grant select on public.ephemeral_conversations to authenticated;

do $$ begin
  if not exists (select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
      and tablename = 'ephemeral_conversations') then
    alter publication supabase_realtime add table public.ephemeral_conversations;
  end if;
end $$;

alter table public.ephemeral_messages
  add column if not exists conversation_id uuid
    references public.ephemeral_conversations(id) on delete cascade;
create index if not exists ephemeral_messages_conversation_idx
  on public.ephemeral_messages(conversation_id, created_at);

drop function if exists public.send_ephemeral_message(text, integer, text, uuid);
drop function if exists public.get_ephemeral_messages();

create or replace function public.cleanup_expired_conversations()
returns void language sql security definer set search_path = '' as $$
  delete from public.ephemeral_conversations where expires_at <= now();
  delete from public.ephemeral_messages
    where conversation_id is null and expires_at <= now();
$$;

create or replace function public.create_ephemeral_conversation(
  conversation_subject text,
  ttl_minutes integer
) returns uuid language plpgsql security definer set search_path = '' as $$
declare active_link_id uuid; new_id uuid; cleaned text := trim(conversation_subject);
begin
  if auth.uid() is null then raise exception 'Sign in first'; end if;
  if char_length(cleaned) not between 1 and 80 then raise exception 'Subject must be 1 to 80 characters'; end if;
  if ttl_minutes < 10 or ttl_minutes > 1440 then raise exception 'Expiry must be 10 minutes to 24 hours'; end if;
  perform public.cleanup_expired_conversations();
  select l.id into active_link_id from public.links l
    where auth.uid() in (l.owner_id, l.partner_id);
  if active_link_id is null then raise exception 'No active partner connection'; end if;
  insert into public.ephemeral_conversations(link_id, subject, created_by, ttl_minutes, expires_at)
    values (active_link_id, cleaned, auth.uid(), ttl_minutes,
      now() + make_interval(mins => ttl_minutes)) returning id into new_id;
  return new_id;
end $$;

create or replace function public.get_ephemeral_conversations()
returns table(id uuid, subject text, created_by uuid, ttl_minutes integer,
  created_at timestamptz, expires_at timestamptz, message_count bigint,
  last_message_at timestamptz)
language plpgsql security definer set search_path = '' as $$
declare active_link_id uuid;
begin
  if auth.uid() is null then raise exception 'Sign in first'; end if;
  perform public.cleanup_expired_conversations();
  select l.id into active_link_id from public.links l
    where auth.uid() in (l.owner_id, l.partner_id);
  if active_link_id is null then return; end if;
  return query select c.id, c.subject, c.created_by, c.ttl_minutes,
    c.created_at, c.expires_at, count(m.id), max(m.created_at)
    from public.ephemeral_conversations c
    left join public.ephemeral_messages m on m.conversation_id = c.id
    where c.link_id = active_link_id and c.expires_at > now()
    group by c.id order by coalesce(max(m.created_at), c.created_at) desc;
end $$;

create or replace function public.update_conversation_expiry(
  target_conversation_id uuid,
  new_ttl_minutes integer
) returns void language plpgsql security definer set search_path = '' as $$
begin
  if new_ttl_minutes < 10 or new_ttl_minutes > 1440 then raise exception 'Expiry must be 10 minutes to 24 hours'; end if;
  update public.ephemeral_conversations c
    set ttl_minutes = new_ttl_minutes,
        expires_at = now() + make_interval(mins => new_ttl_minutes)
    where c.id = target_conversation_id and c.expires_at > now()
      and exists (select 1 from public.links l where l.id = c.link_id
        and auth.uid() in (l.owner_id, l.partner_id));
  if not found then raise exception 'Conversation unavailable'; end if;
end $$;

create or replace function public.send_ephemeral_message(
  conversation_id uuid,
  message_body text,
  message_kind text default 'message',
  reply_to uuid default null
) returns uuid language plpgsql security definer set search_path = '' as $$
declare convo public.ephemeral_conversations%rowtype; chat_secret text;
  new_id uuid; cleaned text := trim(message_body);
begin
  if auth.uid() is null then raise exception 'Sign in first'; end if;
  if char_length(cleaned) not between 1 and 500 then raise exception 'Message must be 1 to 500 characters'; end if;
  if message_kind not in ('message', 'status') then raise exception 'Invalid message type'; end if;
  perform public.cleanup_expired_conversations();
  select c.* into convo from public.ephemeral_conversations c
    join public.links l on l.id = c.link_id
    where c.id = conversation_id and c.expires_at > now()
      and auth.uid() in (l.owner_id, l.partner_id);
  if not found then raise exception 'Conversation unavailable'; end if;
  if reply_to is not null and not exists (select 1 from public.ephemeral_messages r
    where r.id = reply_to and r.conversation_id = convo.id) then raise exception 'Reply unavailable'; end if;
  insert into public.link_chat_keys(link_id, secret)
    values (convo.link_id, encode(extensions.gen_random_bytes(32), 'hex'))
    on conflict (link_id) do nothing;
  select k.secret into chat_secret from public.link_chat_keys k where k.link_id = convo.link_id;
  insert into public.ephemeral_messages(link_id, conversation_id, sender_id, reply_to,
    encrypted_body, kind, expires_at)
  values (convo.link_id, convo.id, auth.uid(), reply_to,
    extensions.pgp_sym_encrypt(cleaned, chat_secret, 'cipher-algo=aes256'),
    message_kind, convo.expires_at) returning id into new_id;
  return new_id;
end $$;

create or replace function public.get_ephemeral_messages(conversation_id uuid)
returns table(id uuid, sender_id uuid, body text, kind text, reply_to uuid,
  reply_body text, created_at timestamptz, expires_at timestamptz)
language plpgsql security definer set search_path = '' as $$
declare convo public.ephemeral_conversations%rowtype; chat_secret text;
begin
  perform public.cleanup_expired_conversations();
  select c.* into convo from public.ephemeral_conversations c
    join public.links l on l.id = c.link_id
    where c.id = conversation_id and c.expires_at > now()
      and auth.uid() in (l.owner_id, l.partner_id);
  if not found then return; end if;
  select k.secret into chat_secret from public.link_chat_keys k where k.link_id = convo.link_id;
  if chat_secret is null then return; end if;
  return query select m.id, m.sender_id,
    extensions.pgp_sym_decrypt(m.encrypted_body, chat_secret), m.kind, m.reply_to,
    case when r.id is null then null else extensions.pgp_sym_decrypt(r.encrypted_body, chat_secret) end,
    m.created_at, convo.expires_at
    from public.ephemeral_messages m
    left join public.ephemeral_messages r on r.id = m.reply_to
    where m.conversation_id = convo.id order by m.created_at asc limit 200;
end $$;

revoke all on table public.ephemeral_conversations from public, anon;
revoke all on function public.cleanup_expired_conversations() from public, anon;
revoke all on function public.create_ephemeral_conversation(text, integer) from public, anon;
revoke all on function public.get_ephemeral_conversations() from public, anon;
revoke all on function public.update_conversation_expiry(uuid, integer) from public, anon;
revoke all on function public.send_ephemeral_message(uuid, text, text, uuid) from public, anon;
revoke all on function public.get_ephemeral_messages(uuid) from public, anon;
grant execute on function public.create_ephemeral_conversation(text, integer) to authenticated;
grant execute on function public.get_ephemeral_conversations() to authenticated;
grant execute on function public.update_conversation_expiry(uuid, integer) to authenticated;
grant execute on function public.send_ephemeral_message(uuid, text, text, uuid) to authenticated;
grant execute on function public.get_ephemeral_messages(uuid) to authenticated;

-- Best-effort database cleanup every minute when pg_cron is available.
do $$ begin
  create extension if not exists pg_cron;
  if not exists (select 1 from cron.job where jobname = 'mahila-mitr-expired-conversations') then
    perform cron.schedule('mahila-mitr-expired-conversations', '* * * * *',
      'select public.cleanup_expired_conversations()');
  end if;
exception when others then
  raise notice 'pg_cron unavailable; cleanup will run on every room API call instead.';
end $$;
