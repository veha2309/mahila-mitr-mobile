-- Make chat Postgres Changes subscriptions observable and reliable.
-- Run after all earlier chat migrations.

alter table public.ephemeral_messages replica identity full;
alter table public.ephemeral_conversations replica identity full;

do $$ begin
  if not exists (select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
      and tablename = 'ephemeral_messages') then
    alter publication supabase_realtime add table public.ephemeral_messages;
  end if;
  if not exists (select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
      and tablename = 'ephemeral_conversations') then
    alter publication supabase_realtime add table public.ephemeral_conversations;
  end if;
end $$;

alter table public.ephemeral_messages enable row level security;
alter table public.ephemeral_conversations enable row level security;

drop policy if exists ephemeral_messages_linked_realtime on public.ephemeral_messages;
create policy ephemeral_messages_linked_realtime on public.ephemeral_messages
  for select to authenticated using (exists (
    select 1 from public.links l where l.id = ephemeral_messages.link_id
      and auth.uid() in (l.owner_id, l.partner_id)
  ));

drop policy if exists ephemeral_conversations_linked_realtime on public.ephemeral_conversations;
create policy ephemeral_conversations_linked_realtime on public.ephemeral_conversations
  for select to authenticated using (exists (
    select 1 from public.links l where l.id = ephemeral_conversations.link_id
      and auth.uid() in (l.owner_id, l.partner_id)
  ));

grant select on public.ephemeral_messages to authenticated;
grant select on public.ephemeral_conversations to authenticated;
