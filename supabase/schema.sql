-- Run in the Supabase SQL editor. Configure the Email OTP template in Supabase Auth.
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 2 and 50),
  updated_at timestamptz not null default now()
);

create table public.links (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null unique references auth.users(id) on delete cascade,
  partner_id uuid not null unique references auth.users(id) on delete cascade,
  owner_nickname text check (owner_nickname is null or char_length(trim(owner_nickname)) between 1 and 30),
  partner_nickname text check (partner_nickname is null or char_length(trim(partner_nickname)) between 1 and 30),
  created_at timestamptz not null default now(),
  check (owner_id <> partner_id)
);

create table public.invites (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  code_hash text not null unique,
  expires_at timestamptz not null default now() + interval '10 minutes',
  used_at timestamptz,
  created_at timestamptz not null default now()
);
create index invites_owner_idx on public.invites(owner_id);

create table public.cycles (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  start_date date not null,
  end_date date,
  flow text check (flow is null or flow in ('light','medium','heavy')),
  symptoms text[] not null default '{}',
  notes text check (notes is null or char_length(notes) <= 500),
  created_at timestamptz not null default now(),
  unique (owner_id, start_date),
  check (end_date is null or end_date >= start_date)
);

create table public.notes (
  id uuid primary key default gen_random_uuid(),
  link_id uuid not null references public.links(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 500),
  style text not null check (style in ('letter','bloom','star')),
  created_at timestamptz not null default now(),
  opened_at timestamptz
);
create index notes_recipient_idx on public.notes(recipient_id,created_at desc);

create table public.date_ratings (
  id uuid primary key default gen_random_uuid(),
  link_id uuid not null references public.links(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  date_on date not null,
  stars integer not null check (stars between 1 and 5),
  reflection text check (char_length(reflection) <= 300),
  created_at timestamptz not null default now(),
  unique(link_id,author_id,date_on)
);

alter table public.links enable row level security;
alter table public.profiles enable row level security;
alter table public.invites enable row level security;
alter table public.cycles enable row level security;
alter table public.notes enable row level security;
alter table public.date_ratings enable row level security;

create policy links_read on public.links for select to authenticated
  using (auth.uid() = owner_id or auth.uid() = partner_id);
create policy profiles_self_write on public.profiles for insert to authenticated
  with check (auth.uid() = id);
create policy profiles_self_update on public.profiles for update to authenticated
  using (auth.uid() = id) with check (auth.uid() = id);
create policy profiles_linked_read on public.profiles for select to authenticated
  using (auth.uid() = id or exists (
    select 1 from public.links l
    where (l.owner_id = profiles.id and l.partner_id = auth.uid())
       or (l.partner_id = profiles.id and l.owner_id = auth.uid())
  ));
create policy cycles_linked_read on public.cycles for select to authenticated
  using (auth.uid() = owner_id or exists (
    select 1 from public.links l where l.owner_id = cycles.owner_id and l.partner_id = auth.uid()
  ));
create policy cycles_owner_write on public.cycles for insert to authenticated with check (auth.uid() = owner_id);
create policy cycles_owner_update on public.cycles for update to authenticated using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy cycles_owner_delete on public.cycles for delete to authenticated using (auth.uid() = owner_id);
create policy notes_owner_read on public.notes for select to authenticated using (auth.uid() = recipient_id);
create policy notes_partner_insert on public.notes for insert to authenticated
  with check (
    auth.uid() = sender_id and
    exists (select 1 from public.links l where l.id = link_id and l.partner_id = auth.uid() and l.owner_id = recipient_id)
  );
create policy ratings_linked_read on public.date_ratings for select to authenticated
  using (exists (select 1 from public.links l where l.id = link_id and auth.uid() in (l.owner_id,l.partner_id)));
create policy ratings_linked_insert on public.date_ratings for insert to authenticated
  with check (auth.uid() = author_id and exists (
    select 1 from public.links l where l.id = link_id and auth.uid() in (l.owner_id,l.partner_id)
  ));
-- Note content is immutable. Opening is done through a narrow RPC below.

-- Direct access to invites is intentionally disallowed. Only these RPCs can touch them.
create or replace function public.create_invite()
returns text language plpgsql security definer set search_path = '' as $$
declare
  generated text;
begin
  if auth.uid() is null then raise exception 'Sign in first'; end if;
  if exists (select 1 from public.links where owner_id = auth.uid() or partner_id = auth.uid()) then
    raise exception 'Already paired';
  end if;
  update public.invites set used_at = now()
    where owner_id = auth.uid() and used_at is null;
  generated := upper(encode(extensions.gen_random_bytes(6), 'hex'));
  insert into public.invites(owner_id, code_hash) values (auth.uid(), encode(extensions.digest(generated, 'sha256'), 'hex'));
  return generated;
end $$;

create or replace function public.accept_invite(invite_code text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  chosen public.invites%rowtype;
  new_link uuid;
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
  insert into public.links(owner_id,partner_id) values (chosen.owner_id,auth.uid()) returning id into new_link;
  update public.invites set used_at = now() where id = chosen.id;
  return new_link;
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

create or replace function public.open_note(note_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.notes set opened_at = coalesce(opened_at, now())
    where id = note_id and recipient_id = auth.uid();
  if not found then raise exception 'Note unavailable'; end if;
end $$;

create or replace function public.unlink_partner()
returns void language plpgsql security definer set search_path = '' as $$
begin
  delete from public.links where owner_id = auth.uid() or partner_id = auth.uid();
end $$;

create or replace function public.set_partner_nickname(new_nickname text)
returns void language plpgsql security definer set search_path = '' as $$
declare cleaned text := nullif(trim(new_nickname), '');
begin
  if auth.uid() is null then raise exception 'Sign in first'; end if;
  if cleaned is not null and char_length(cleaned) > 30 then
    raise exception 'Nickname must be 30 characters or fewer';
  end if;

  update public.links
  set partner_nickname = cleaned
  where owner_id = auth.uid();
  if found then return; end if;

  update public.links
  set owner_nickname = cleaned
  where partner_id = auth.uid();
  if not found then raise exception 'No active partner connection'; end if;
end $$;

revoke all on function public.create_invite() from public, anon;
revoke all on function public.accept_invite(text) from public, anon;
revoke all on function public.preview_invite(text) from public, anon;
revoke all on function public.open_note(uuid) from public, anon;
revoke all on function public.unlink_partner() from public, anon;
revoke all on function public.set_partner_nickname(text) from public, anon;
grant execute on function public.create_invite() to authenticated;
grant execute on function public.accept_invite(text) to authenticated;
grant execute on function public.preview_invite(text) to authenticated;
grant execute on function public.open_note(uuid) to authenticated;
grant execute on function public.unlink_partner() to authenticated;
grant execute on function public.set_partner_nickname(text) to authenticated;
