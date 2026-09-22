-- Server-encrypted, self-expiring chat for a linked pair.
-- Message plaintext is never stored in the message table. Run once in Supabase SQL Editor.

create table if not exists public.link_chat_keys (
  link_id uuid primary key references public.links(id) on delete cascade,
  secret text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.ephemeral_messages (
  id uuid primary key default gen_random_uuid(),
  link_id uuid not null references public.links(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  reply_to uuid references public.ephemeral_messages(id) on delete set null,
  encrypted_body bytea not null,
  kind text not null default 'message' check (kind in ('message', 'status')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  check (expires_at > created_at and expires_at <= created_at + interval '24 hours')
);
create index if not exists ephemeral_messages_link_expiry_idx
  on public.ephemeral_messages(link_id, expires_at);
alter table public.ephemeral_messages
  add column if not exists reply_to uuid references public.ephemeral_messages(id) on delete set null;

alter table public.link_chat_keys enable row level security;
alter table public.ephemeral_messages enable row level security;
-- No direct table policies: paired users can only use the narrow RPCs below.

do $$ begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'ephemeral_messages'
  ) then
    alter publication supabase_realtime add table public.ephemeral_messages;
  end if;
end $$;

drop function if exists public.send_ephemeral_message(text, integer, text);
create or replace function public.send_ephemeral_message(
  message_body text,
  ttl_minutes integer,
  message_kind text default 'message',
  reply_to uuid default null
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  active_link public.links%rowtype;
  chat_secret text;
  new_id uuid;
  cleaned_body text := trim(message_body);
begin
  if auth.uid() is null then raise exception 'Sign in first'; end if;
  if char_length(cleaned_body) not between 1 and 500 then
    raise exception 'Message must be between 1 and 500 characters';
  end if;
  if ttl_minutes < 10 or ttl_minutes > 1440 then
    raise exception 'Expiry must be between 10 minutes and 24 hours';
  end if;
  if message_kind not in ('message', 'status') then
    raise exception 'Invalid message type';
  end if;

  select * into active_link from public.links
    where auth.uid() in (owner_id, partner_id);
  if not found then raise exception 'No active partner connection'; end if;
  if reply_to is not null and not exists (
    select 1 from public.ephemeral_messages r
    where r.id = reply_to and r.link_id = active_link.id and r.expires_at > now()
  ) then
    raise exception 'Reply target is unavailable';
  end if;

  insert into public.link_chat_keys(link_id, secret)
    values (active_link.id, encode(extensions.gen_random_bytes(32), 'hex'))
    on conflict (link_id) do nothing;
  select secret into chat_secret from public.link_chat_keys
    where link_id = active_link.id;

  delete from public.ephemeral_messages where expires_at <= now();
  insert into public.ephemeral_messages(
    link_id, sender_id, reply_to, encrypted_body, kind, expires_at
  ) values (
    active_link.id,
    auth.uid(),
    reply_to,
    extensions.pgp_sym_encrypt(cleaned_body, chat_secret, 'cipher-algo=aes256'),
    message_kind,
    now() + make_interval(mins => ttl_minutes)
  ) returning id into new_id;
  return new_id;
end $$;

drop function if exists public.get_ephemeral_messages();
create function public.get_ephemeral_messages()
returns table (
  id uuid,
  sender_id uuid,
  body text,
  kind text,
  reply_to uuid,
  reply_body text,
  created_at timestamptz,
  expires_at timestamptz
) language plpgsql security definer set search_path = '' as $$
declare
  active_link_id uuid;
  chat_secret text;
begin
  if auth.uid() is null then raise exception 'Sign in first'; end if;
  select l.id into active_link_id from public.links l
    where auth.uid() in (l.owner_id, l.partner_id);
  if active_link_id is null then return; end if;

  delete from public.ephemeral_messages m where m.expires_at <= now();
  select k.secret into chat_secret from public.link_chat_keys k
    where k.link_id = active_link_id;
  if chat_secret is null then return; end if;

  return query
    select m.id, m.sender_id,
      extensions.pgp_sym_decrypt(m.encrypted_body, chat_secret),
      m.kind, m.reply_to,
      case when r.id is null then null
        else extensions.pgp_sym_decrypt(r.encrypted_body, chat_secret) end,
      m.created_at, m.expires_at
    from public.ephemeral_messages m
    left join public.ephemeral_messages r on r.id = m.reply_to
    where m.link_id = active_link_id and m.expires_at > now()
    order by m.created_at asc
    limit 100;
end $$;

revoke all on table public.link_chat_keys from public, anon, authenticated;
revoke all on table public.ephemeral_messages from public, anon, authenticated;
drop policy if exists ephemeral_messages_linked_realtime on public.ephemeral_messages;
create policy ephemeral_messages_linked_realtime on public.ephemeral_messages
  for select to authenticated using (exists (
    select 1 from public.links l
    where l.id = ephemeral_messages.link_id
      and auth.uid() in (l.owner_id, l.partner_id)
  ));
grant select on public.ephemeral_messages to authenticated;
revoke all on function public.send_ephemeral_message(text, integer, text, uuid) from public, anon;
revoke all on function public.get_ephemeral_messages() from public, anon;
grant execute on function public.send_ephemeral_message(text, integer, text, uuid) to authenticated;
grant execute on function public.get_ephemeral_messages() to authenticated;
