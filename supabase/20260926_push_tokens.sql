-- Private FCM device-token registry used by the push-chat-notification Edge Function.

create table if not exists public.push_tokens (
  token text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('android', 'ios')),
  updated_at timestamptz not null default now()
);
create index if not exists push_tokens_user_idx on public.push_tokens(user_id);
alter table public.push_tokens enable row level security;
-- No client table policies: registration happens only through narrow RPCs.

create or replace function public.register_push_token(
  device_token text,
  device_platform text
) returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Sign in first'; end if;
  if char_length(device_token) < 20 or char_length(device_token) > 4096 then
    raise exception 'Invalid device token';
  end if;
  if device_platform not in ('android', 'ios') then
    raise exception 'Invalid device platform';
  end if;
  insert into public.push_tokens(token, user_id, platform, updated_at)
    values (device_token, auth.uid(), device_platform, now())
    on conflict (token) do update set
      user_id = excluded.user_id,
      platform = excluded.platform,
      updated_at = now();
end $$;

create or replace function public.unregister_push_token(device_token text)
returns void language sql security definer set search_path = '' as $$
  delete from public.push_tokens
    where token = device_token and user_id = auth.uid();
$$;

revoke all on table public.push_tokens from public, anon, authenticated;
revoke all on function public.register_push_token(text, text) from public, anon;
revoke all on function public.unregister_push_token(text) from public, anon;
grant execute on function public.register_push_token(text, text) to authenticated;
grant execute on function public.unregister_push_token(text) to authenticated;
