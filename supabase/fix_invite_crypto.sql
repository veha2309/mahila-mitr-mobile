-- Run this once in the Supabase SQL Editor for an existing installation.
-- pgcrypto is normally installed in the extensions schema on Supabase.
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

create or replace function public.create_invite()
returns text language plpgsql security definer set search_path = '' as $$
declare generated text;
begin
  if auth.uid() is null then raise exception 'Sign in first'; end if;
  if exists (select 1 from public.links where owner_id = auth.uid() or partner_id = auth.uid()) then
    raise exception 'Already paired';
  end if;
  update public.invites set used_at = now()
    where owner_id = auth.uid() and used_at is null;
  generated := upper(encode(extensions.gen_random_bytes(6), 'hex'));
  insert into public.invites(owner_id, code_hash)
    values (auth.uid(), encode(extensions.digest(generated, 'sha256'), 'hex'));
  return generated;
end $$;

create or replace function public.preview_invite(invite_code text)
returns text language plpgsql security definer set search_path = '' as $$
declare owner_name text;
begin
  if auth.uid() is null then raise exception 'Sign in first'; end if;
  select p.display_name into owner_name
    from public.invites i
    join public.profiles p on p.id = i.owner_id
    where i.code_hash = encode(extensions.digest(upper(trim(invite_code)), 'sha256'), 'hex')
      and i.used_at is null and i.expires_at > now();
  if owner_name is null then raise exception 'Invitation unavailable'; end if;
  return owner_name;
end $$;

revoke all on function public.preview_invite(text) from public, anon;
grant execute on function public.preview_invite(text) to authenticated;

create or replace function public.accept_invite(invite_code text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare chosen public.invites%rowtype; new_link uuid;
begin
  if auth.uid() is null then raise exception 'Sign in first'; end if;
  if exists (select 1 from public.links where owner_id = auth.uid() or partner_id = auth.uid()) then
    raise exception 'Already paired';
  end if;
  select * into chosen from public.invites
    where code_hash = encode(extensions.digest(upper(trim(invite_code)), 'sha256'), 'hex')
      and used_at is null and expires_at > now()
    for update;
  if not found then raise exception 'Code is invalid or expired'; end if;
  if chosen.owner_id = auth.uid() then raise exception 'Cannot pair with yourself'; end if;
  if exists (select 1 from public.links where owner_id = chosen.owner_id or partner_id = chosen.owner_id) then
    raise exception 'This account is already paired';
  end if;
  insert into public.links(owner_id, partner_id) values (chosen.owner_id, auth.uid()) returning id into new_link;
  update public.invites set used_at = now() where id = chosen.id;
  return new_link;
end $$;
