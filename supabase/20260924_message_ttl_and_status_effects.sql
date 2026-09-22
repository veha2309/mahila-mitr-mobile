-- Persistent conversation subjects with per-message TTL and receiver-only status effects.
-- Run after 20260923_conversation_rooms.sql.

alter table public.ephemeral_conversations
  add column if not exists has_messages boolean not null default false;
alter table public.ephemeral_conversations alter column expires_at drop not null;
update public.ephemeral_conversations set expires_at = null;
alter table public.ephemeral_messages drop constraint if exists ephemeral_messages_check;
alter table public.ephemeral_messages drop constraint if exists ephemeral_messages_expiry_check;
alter table public.ephemeral_messages add constraint ephemeral_messages_expiry_check
  check (expires_at > created_at);

create or replace function public.cleanup_expired_conversations()
returns void language plpgsql security definer set search_path = '' as $$
begin
  delete from public.ephemeral_messages where expires_at <= now();
  delete from public.ephemeral_conversations c
    where c.has_messages and not exists (
      select 1 from public.ephemeral_messages m where m.conversation_id = c.id
    );
end $$;

drop function if exists public.get_ephemeral_conversations();
create function public.get_ephemeral_conversations()
returns table(id uuid, subject text, created_by uuid, ttl_minutes integer,
  created_at timestamptz, message_count bigint, last_message_at timestamptz)
language plpgsql security definer set search_path = '' as $$
declare active_link_id uuid;
begin
  if auth.uid() is null then raise exception 'Sign in first'; end if;
  perform public.cleanup_expired_conversations();
  select l.id into active_link_id from public.links l
    where auth.uid() in (l.owner_id, l.partner_id);
  if active_link_id is null then return; end if;
  return query select c.id, c.subject, c.created_by, c.ttl_minutes,
    c.created_at, count(m.id), max(m.created_at)
    from public.ephemeral_conversations c
    left join public.ephemeral_messages m
      on m.conversation_id = c.id and m.expires_at > now()
    where c.link_id = active_link_id
    group by c.id order by coalesce(max(m.created_at), c.created_at) desc;
end $$;

create or replace function public.update_conversation_expiry(
  target_conversation_id uuid,
  new_ttl_minutes integer
) returns void language plpgsql security definer set search_path = '' as $$
begin
  if new_ttl_minutes < 10 or new_ttl_minutes > 1440 then
    raise exception 'Expiry must be 10 minutes to 24 hours';
  end if;
  update public.ephemeral_conversations c set ttl_minutes = new_ttl_minutes
    where c.id = target_conversation_id and exists (
      select 1 from public.links l where l.id = c.link_id
        and auth.uid() in (l.owner_id, l.partner_id)
    );
  if not found then raise exception 'Conversation unavailable'; end if;
end $$;

drop function if exists public.send_ephemeral_message(uuid, text, text, uuid);
create function public.send_ephemeral_message(
  target_conversation_id uuid,
  message_body text,
  message_kind text default 'message',
  reply_message_id uuid default null
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
    where c.id = target_conversation_id
      and auth.uid() in (l.owner_id, l.partner_id);
  if not found then raise exception 'Conversation unavailable'; end if;
  if reply_message_id is not null and not exists (
    select 1 from public.ephemeral_messages r
    where r.id = reply_message_id and r.conversation_id = convo.id
      and r.expires_at > now()
  ) then raise exception 'Reply unavailable'; end if;
  insert into public.link_chat_keys(link_id, secret)
    values (convo.link_id, encode(extensions.gen_random_bytes(32), 'hex'))
    on conflict (link_id) do nothing;
  select k.secret into chat_secret from public.link_chat_keys k where k.link_id = convo.link_id;
  insert into public.ephemeral_messages(link_id, conversation_id, sender_id,
    reply_to, encrypted_body, kind, expires_at)
  values (convo.link_id, convo.id, auth.uid(), reply_message_id,
    extensions.pgp_sym_encrypt(cleaned, chat_secret, 'cipher-algo=aes256'),
    message_kind, now() + make_interval(mins => convo.ttl_minutes))
  returning id into new_id;
  update public.ephemeral_conversations set has_messages = true where id = convo.id;
  return new_id;
end $$;

drop function if exists public.get_ephemeral_messages(uuid);
create function public.get_ephemeral_messages(target_conversation_id uuid)
returns table(id uuid, sender_id uuid, body text, kind text, reply_to uuid,
  reply_body text, created_at timestamptz, expires_at timestamptz)
language plpgsql security definer set search_path = '' as $$
declare convo public.ephemeral_conversations%rowtype; chat_secret text;
begin
  perform public.cleanup_expired_conversations();
  select c.* into convo from public.ephemeral_conversations c
    join public.links l on l.id = c.link_id
    where c.id = target_conversation_id
      and auth.uid() in (l.owner_id, l.partner_id);
  if not found then return; end if;
  select k.secret into chat_secret from public.link_chat_keys k where k.link_id = convo.link_id;
  if chat_secret is null then return; end if;
  return query select m.id, m.sender_id,
    extensions.pgp_sym_decrypt(m.encrypted_body, chat_secret), m.kind, m.reply_to,
    case when r.id is null then null else extensions.pgp_sym_decrypt(r.encrypted_body, chat_secret) end,
    m.created_at, m.expires_at
    from public.ephemeral_messages m
    left join public.ephemeral_messages r on r.id = m.reply_to
    where m.conversation_id = convo.id and m.expires_at > now()
    order by m.created_at asc limit 200;
end $$;

create or replace function public.extend_message_expiry(
  target_message_id uuid,
  additional_minutes integer
) returns timestamptz language plpgsql security definer set search_path = '' as $$
declare new_expiry timestamptz;
begin
  if additional_minutes < 10 or additional_minutes > 1440 then
    raise exception 'Extension must be 10 minutes to 24 hours';
  end if;
  update public.ephemeral_messages m
    set expires_at = greatest(m.expires_at, now()) + make_interval(mins => additional_minutes)
    where m.id = target_message_id and exists (
      select 1 from public.links l where l.id = m.link_id
        and auth.uid() in (l.owner_id, l.partner_id)
    ) returning expires_at into new_expiry;
  if new_expiry is null then raise exception 'Message unavailable'; end if;
  return new_expiry;
end $$;

create or replace function public.delete_ephemeral_conversation(
  target_conversation_id uuid
) returns void language plpgsql security definer set search_path = '' as $$
begin
  delete from public.ephemeral_conversations c where c.id = target_conversation_id
    and exists (select 1 from public.links l where l.id = c.link_id
      and auth.uid() in (l.owner_id, l.partner_id));
  if not found then raise exception 'Conversation unavailable'; end if;
end $$;

revoke all on function public.send_ephemeral_message(uuid, text, text, uuid) from public, anon;
revoke all on function public.get_ephemeral_messages(uuid) from public, anon;
revoke all on function public.extend_message_expiry(uuid, integer) from public, anon;
revoke all on function public.delete_ephemeral_conversation(uuid) from public, anon;
grant execute on function public.send_ephemeral_message(uuid, text, text, uuid) to authenticated;
grant execute on function public.get_ephemeral_messages(uuid) to authenticated;
grant execute on function public.extend_message_expiry(uuid, integer) to authenticated;
grant execute on function public.delete_ephemeral_conversation(uuid) to authenticated;
