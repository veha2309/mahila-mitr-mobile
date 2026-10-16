-- Read-triggered message expiry. Run after all 20260926 migrations.
-- No historical read receipts exist: preserve every surviving message as unread.
-- Previously deleted messages cannot be recovered. Apply before deploying the client.
begin;

alter table public.ephemeral_messages
  add column if not exists read_at timestamptz,
  add column if not exists ttl_minutes integer;
alter table public.ephemeral_messages alter column expires_at drop not null;
alter table public.ephemeral_messages drop constraint if exists ephemeral_messages_expiry_check;
update public.ephemeral_messages m set
  ttl_minutes = coalesce(c.ttl_minutes, 60), expires_at = null
  from public.ephemeral_conversations c
  where c.id = m.conversation_id and m.ttl_minutes is null;
update public.ephemeral_messages set ttl_minutes = 60, expires_at = null
  where ttl_minutes is null;
alter table public.ephemeral_messages alter column ttl_minutes set not null;
alter table public.ephemeral_messages add constraint ephemeral_messages_read_expiry_check
  check ((read_at is null and expires_at is null)
    or (read_at is not null and expires_at is not null and expires_at > read_at));
alter table public.ephemeral_messages add constraint ephemeral_messages_ttl_positive
  check (ttl_minutes >= 10);
update public.ephemeral_conversations set expires_at = null;
update public.ephemeral_conversations c set has_messages = true
  where exists (select 1 from public.ephemeral_messages m where m.conversation_id = c.id);

create or replace function public.create_ephemeral_conversation(
  conversation_subject text, ttl_minutes integer
) returns uuid language plpgsql security definer set search_path = '' as $$
declare active_link_id uuid; new_id uuid; cleaned text := trim(conversation_subject);
begin
  if auth.uid() is null then raise exception 'Sign in first'; end if;
  if cleaned is null or char_length(cleaned) not between 1 and 80 then
    raise exception 'Subject must be 1 to 80 characters';
  end if;
  if ttl_minutes is null or ttl_minutes not between 10 and 1440 then
    raise exception 'Expiry must be 10 minutes to 24 hours';
  end if;
  select l.id into active_link_id from public.links l
    where auth.uid() in (l.owner_id, l.partner_id);
  if active_link_id is null then raise exception 'No active partner connection'; end if;
  insert into public.ephemeral_conversations(link_id, subject, created_by, ttl_minutes, expires_at)
    values (active_link_id, cleaned, auth.uid(), ttl_minutes, null) returning id into new_id;
  return new_id;
end $$;

create or replace function public.cleanup_expired_conversations()
returns void language plpgsql security definer set search_path = '' as $$
declare candidate uuid;
begin
  delete from public.ephemeral_messages where read_at is not null and expires_at <= now();
  -- Serialize final room removal with sends; never cascade-delete a new unread message.
  for candidate in select c.id from public.ephemeral_conversations c
    where c.has_messages and not exists (
      select 1 from public.ephemeral_messages m where m.conversation_id = c.id
    ) for update of c
  loop
    delete from public.ephemeral_conversations c where c.id = candidate
      and not exists (select 1 from public.ephemeral_messages m where m.conversation_id = c.id);
  end loop;
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
      on m.conversation_id = c.id and (m.expires_at is null or m.expires_at > now())
    where c.link_id = active_link_id
    group by c.id order by coalesce(max(m.created_at), c.created_at) desc;
end $$;

create or replace function public.update_conversation_expiry(
  target_conversation_id uuid,
  new_ttl_minutes integer
) returns void language plpgsql security definer set search_path = '' as $$
begin
  if new_ttl_minutes is null or new_ttl_minutes not between 10 and 1440 then
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
      and auth.uid() in (l.owner_id, l.partner_id)
    for update of c;
  if not found then raise exception 'Conversation unavailable'; end if;
  if reply_message_id is not null and not exists (
    select 1 from public.ephemeral_messages r
    where r.id = reply_message_id and r.conversation_id = convo.id
      and (r.expires_at is null or r.expires_at > now())
  ) then raise exception 'Reply unavailable'; end if;
  insert into public.link_chat_keys(link_id, secret)
    values (convo.link_id, encode(extensions.gen_random_bytes(32), 'hex'))
    on conflict (link_id) do nothing;
  select k.secret into chat_secret from public.link_chat_keys k where k.link_id = convo.link_id;
  insert into public.ephemeral_messages(link_id, conversation_id, sender_id,
    reply_to, encrypted_body, kind, ttl_minutes, expires_at)
  values (convo.link_id, convo.id, auth.uid(), reply_message_id,
    extensions.pgp_sym_encrypt(cleaned, chat_secret, 'cipher-algo=aes256'),
    message_kind, convo.ttl_minutes, null)
  returning id into new_id;
  update public.ephemeral_conversations set has_messages = true where id = convo.id;
  return new_id;
end $$;

drop function if exists public.get_ephemeral_messages(uuid);
create function public.get_ephemeral_messages(target_conversation_id uuid)
returns table(id uuid, sender_id uuid, body text, kind text, reply_to uuid,
  reply_body text, created_at timestamptz, expires_at timestamptz,
  read_at timestamptz, ttl_minutes integer)
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
    m.created_at, m.expires_at, m.read_at, m.ttl_minutes
    from public.ephemeral_messages m
    left join public.ephemeral_messages r on r.id = m.reply_to
    where m.conversation_id = convo.id and (m.expires_at is null or m.expires_at > now())
    order by m.created_at asc limit 200;
end $$;

-- Extending an unread message changes its pending duration without starting it.
create or replace function public.extend_message_expiry(
  target_message_id uuid, additional_minutes integer
) returns timestamptz language plpgsql security definer set search_path = '' as $$
declare new_expiry timestamptz;
begin
  if additional_minutes is null or additional_minutes not between 10 and 1440 then
    raise exception 'Extension must be 10 minutes to 24 hours';
  end if;
  update public.ephemeral_messages m
    set ttl_minutes = m.ttl_minutes + additional_minutes,
        expires_at = case when m.read_at is null then null
          else m.expires_at + make_interval(mins => additional_minutes) end
    where m.id = target_message_id
      and (m.expires_at is null or m.expires_at > now())
      and exists (select 1 from public.links l where l.id = m.link_id
        and auth.uid() in (l.owner_id, l.partner_id))
    returning expires_at into new_expiry;
  if not found then raise exception 'Message unavailable'; end if;
  return new_expiry;
end $$;

-- Fetching a room or notification preview must never acknowledge a read.
-- The client submits only incoming messages actually visible in the foreground.
create or replace function public.mark_ephemeral_messages_read(
  target_conversation_id uuid, message_ids uuid[]
) returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Sign in first'; end if;
  if not exists (select 1 from public.ephemeral_conversations c
    join public.links l on l.id = c.link_id
    where c.id = target_conversation_id
      and auth.uid() in (l.owner_id, l.partner_id)) then
    raise exception 'Conversation unavailable';
  end if;
  update public.ephemeral_messages m
    set read_at = now(), expires_at = now() + make_interval(mins => m.ttl_minutes)
    where m.conversation_id = target_conversation_id
      and m.id = any(message_ids) and m.sender_id <> auth.uid()
      and m.read_at is null;
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

revoke all on function public.mark_ephemeral_messages_read(uuid, uuid[]) from public, anon;
grant execute on function public.mark_ephemeral_messages_read(uuid, uuid[]) to authenticated;
revoke all on function public.get_ephemeral_conversations() from public, anon;
grant execute on function public.get_ephemeral_conversations() to authenticated;
revoke all on function public.create_ephemeral_conversation(text, integer) from public, anon;
grant execute on function public.create_ephemeral_conversation(text, integer) to authenticated;
commit;
