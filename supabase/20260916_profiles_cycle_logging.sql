-- Upgrade an existing Mahila Mitr database.
-- Run once in the Supabase SQL editor before using the updated mobile app.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 2 and 50),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists profiles_self_write on public.profiles;
create policy profiles_self_write on public.profiles for insert to authenticated
  with check (auth.uid() = id);
drop policy if exists profiles_self_update on public.profiles;
create policy profiles_self_update on public.profiles for update to authenticated
  using (auth.uid() = id) with check (auth.uid() = id);
drop policy if exists profiles_linked_read on public.profiles;
create policy profiles_linked_read on public.profiles for select to authenticated
  using (auth.uid() = id or exists (
    select 1 from public.links l
    where (l.owner_id = profiles.id and l.partner_id = auth.uid())
       or (l.partner_id = profiles.id and l.owner_id = auth.uid())
  ));

alter table public.cycles add column if not exists flow text;
alter table public.cycles add column if not exists symptoms text[] not null default '{}';
alter table public.cycles add column if not exists notes text;

alter table public.cycles drop constraint if exists cycles_flow_check;
alter table public.cycles add constraint cycles_flow_check
  check (flow is null or flow in ('light','medium','heavy'));
alter table public.cycles drop constraint if exists cycles_notes_check;
alter table public.cycles add constraint cycles_notes_check
  check (notes is null or char_length(notes) <= 500);

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

revoke all on function public.create_invite() from public, anon;
grant execute on function public.create_invite() to authenticated;

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
