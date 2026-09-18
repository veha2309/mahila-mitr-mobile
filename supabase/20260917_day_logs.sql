-- Migration: Add day_logs table for daily mood, flow, energy, and symptoms tracking
-- Run in the Supabase SQL editor to enable per-day wellness logging.

create table if not exists public.day_logs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  date_on date not null,
  mood text check (mood is null or mood in ('happy', 'calm', 'energetic', 'sad', 'irritable', 'anxious')),
  flow text check (flow is null or flow in ('none', 'spotting', 'light', 'medium', 'heavy')),
  energy text check (energy is null or energy in ('high', 'normal', 'low')),
  symptoms text[] not null default '{}',
  note text check (note is null or char_length(note) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, date_on)
);

create index if not exists day_logs_owner_date_idx on public.day_logs(owner_id, date_on desc);

alter table public.day_logs enable row level security;

-- Owner can manage their own daily logs
drop policy if exists day_logs_owner_insert on public.day_logs;
create policy day_logs_owner_insert on public.day_logs for insert to authenticated
  with check (auth.uid() = owner_id);

drop policy if exists day_logs_owner_update on public.day_logs;
create policy day_logs_owner_update on public.day_logs for update to authenticated
  using (auth.uid() = owner_id) with check (auth.uid() = owner_id);

drop policy if exists day_logs_owner_delete on public.day_logs;
create policy day_logs_owner_delete on public.day_logs for delete to authenticated
  using (auth.uid() = owner_id);

-- Owner and paired partner can read day logs
drop policy if exists day_logs_linked_read on public.day_logs;
create policy day_logs_linked_read on public.day_logs for select to authenticated
  using (
    auth.uid() = owner_id or exists (
      select 1 from public.links l
      where l.owner_id = day_logs.owner_id and l.partner_id = auth.uid()
    )
  );
