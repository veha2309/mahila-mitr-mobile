-- Fix connected-partner identity display and add nicknames shared by the pair.
-- Run once in the Supabase SQL editor before using the updated mobile app.

alter table public.links
  add column if not exists owner_nickname text,
  add column if not exists partner_nickname text;

alter table public.links drop constraint if exists links_owner_nickname_check;
alter table public.links add constraint links_owner_nickname_check
  check (owner_nickname is null or char_length(trim(owner_nickname)) between 1 and 30);
alter table public.links drop constraint if exists links_partner_nickname_check;
alter table public.links add constraint links_partner_nickname_check
  check (partner_nickname is null or char_length(trim(partner_nickname)) between 1 and 30);

create or replace function public.set_partner_nickname(new_nickname text)
returns void language plpgsql security definer set search_path = '' as $$
declare cleaned text := nullif(trim(new_nickname), '');
begin
  if auth.uid() is null then raise exception 'Sign in first'; end if;
  if cleaned is not null and char_length(cleaned) > 30 then
    raise exception 'Nickname must be 30 characters or fewer';
  end if;

  -- Each user can only set the nickname belonging to the other member.
  update public.links
  set partner_nickname = cleaned
  where owner_id = auth.uid();
  if found then return; end if;

  update public.links
  set owner_nickname = cleaned
  where partner_id = auth.uid();
  if not found then raise exception 'No active partner connection'; end if;
end $$;

revoke all on function public.set_partner_nickname(text) from public, anon;
grant execute on function public.set_partner_nickname(text) to authenticated;
