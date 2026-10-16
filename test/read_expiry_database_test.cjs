// Run: node test/read_expiry_database_test.cjs [path-to-@electric-sql/pglite]
// Isolated PostgreSQL regression tests. Crypto is stubbed: these verify expiry,
// authorization and cleanup, not encryption. No live Supabase connection is used.
const { PGlite } = require(process.argv[2] || '@electric-sql/pglite');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const assert = require('node:assert/strict');

(async () => {
  const db = new PGlite();
  const owner = '00000000-0000-0000-0000-000000000001';
  const partner = '00000000-0000-0000-0000-000000000002';
  const outsider = '00000000-0000-0000-0000-000000000003';
  const link = '00000000-0000-0000-0000-000000000004';
  const room = '00000000-0000-0000-0000-000000000005';
  await db.exec(`
    create role anon; create role authenticated;
    create schema auth; create schema extensions;
    create function auth.uid() returns uuid language sql as
      $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
    create function extensions.gen_random_bytes(integer) returns bytea language sql as $$ select decode('abcd', 'hex') $$;
    create function extensions.pgp_sym_encrypt(text, text, text) returns bytea language sql as $$ select convert_to($1, 'UTF8') $$;
    create function extensions.pgp_sym_decrypt(bytea, text) returns text language sql as $$ select convert_from($1, 'UTF8') $$;
    create table public.links(id uuid primary key, owner_id uuid, partner_id uuid);
    create table public.link_chat_keys(link_id uuid primary key, secret text);
    create table public.ephemeral_conversations(id uuid primary key default gen_random_uuid(),
      link_id uuid references public.links(id), subject text, created_by uuid,
      ttl_minutes integer, created_at timestamptz default now(), expires_at timestamptz,
      has_messages boolean default false);
    create table public.ephemeral_messages(id uuid primary key default gen_random_uuid(),
      link_id uuid references public.links(id), conversation_id uuid references public.ephemeral_conversations(id) on delete cascade,
      sender_id uuid, encrypted_body bytea, kind text, reply_to uuid references public.ephemeral_messages(id) on delete set null,
      created_at timestamptz default now(), expires_at timestamptz not null,
      constraint ephemeral_messages_expiry_check check(expires_at > created_at));
    insert into public.links values ('${link}', '${owner}', '${partner}');
    insert into public.ephemeral_conversations(id, link_id, subject, created_by, ttl_minutes, has_messages)
      values ('${room}', '${link}', 'Test room', '${owner}', 60, true);
    insert into public.ephemeral_messages(link_id, conversation_id, sender_id, encrypted_body, kind, expires_at)
      values ('${link}', '${room}', '${owner}', convert_to('Legacy', 'UTF8'), 'message', now() + interval '1 hour');
  `);
  await db.exec(readFileSync(join(__dirname, '../supabase/20261016_read_triggered_expiry.sql'), 'utf8'));
  const query = async (sql, params = []) => (await db.query(sql, params)).rows;
  const as = async (user) => query("select set_config('request.jwt.claim.sub', $1, false)", [user]);
  const message = async (id) => (await query('select * from public.ephemeral_messages where id=$1', [id]))[0];
  const count = async (table) => Number((await query(`select count(*) as n from public.${table}`))[0].n);
  const legacy = (await query('select * from public.ephemeral_messages'))[0];
  assert.equal(legacy.expires_at, null, 'migration preserves surviving legacy messages');
  await as(owner);
  const emptyRoom = (await query("select public.create_ephemeral_conversation('Empty room', 60) as id"))[0].id;
  assert.equal((await query('select expires_at from public.ephemeral_conversations where id=$1', [emptyRoom]))[0].expires_at, null, 'empty rooms have no clock');
  await query('select public.cleanup_expired_conversations()');
  assert.equal(await count('ephemeral_conversations'), 2, 'empty room persists');
  await query('select public.delete_ephemeral_conversation($1)', [emptyRoom]);
  const id = (await query("select public.send_ephemeral_message($1, 'Hello') as id", [room]))[0].id;
  assert.equal((await message(id)).expires_at, null, 'sending must not start timer');
  await query('select public.get_ephemeral_messages($1)', [room]);
  await query('select public.mark_ephemeral_messages_read($1, $2::uuid[])', [room, [id]]);
  assert.equal((await message(id)).read_at, null, 'sender cannot acknowledge own message');
  await query('select public.extend_message_expiry($1, 10)', [id]);
  assert.equal((await message(id)).expires_at, null, 'extending unread must keep timer paused');
  assert.equal((await message(id)).ttl_minutes, 70);
  await as(outsider);
  await assert.rejects(query('select public.mark_ephemeral_messages_read($1, $2::uuid[])', [room, [id]]), /Conversation unavailable/);
  await as(partner);
  await query('select public.get_ephemeral_messages($1)', [room]);
  assert.equal((await message(id)).read_at, null, 'recipient fetch must not count as read');
  await query('select public.mark_ephemeral_messages_read($1, $2::uuid[])', [room, [id]]);
  const first = await message(id);
  assert.equal(new Date(first.expires_at) - new Date(first.read_at), 70 * 60000);
  await query('select public.mark_ephemeral_messages_read($1, $2::uuid[])', [room, [id]]);
  assert.equal(new Date((await message(id)).expires_at).getTime(), new Date(first.expires_at).getTime(), 'repeated receipts must not reset timer');
  await query('select public.update_conversation_expiry($1, 10)', [room]);
  assert.equal((await message(id)).ttl_minutes, 70, 'settings must not shorten existing messages');
  await db.exec(`update public.ephemeral_messages set read_at=now()-interval '2 hours', expires_at=now()-interval '1 hour' where id='${id}';`);
  await query('select public.cleanup_expired_conversations()');
  assert.equal(await message(id), undefined, 'read expired messages are deleted');
  assert.equal(await count('ephemeral_conversations'), 1, 'unread legacy message keeps room alive');
  await query('select public.mark_ephemeral_messages_read($1, $2::uuid[])', [room, [legacy.id]]);
  await db.exec("update public.ephemeral_messages set read_at=now()-interval '2 hours', expires_at=now()-interval '1 hour';");
  await query('select public.cleanup_expired_conversations()');
  assert.equal(await count('ephemeral_conversations'), 0, 'last read expiry removes room');
  assert.equal((await query("select has_function_privilege('anon', 'public.mark_ephemeral_messages_read(uuid,uuid[])', 'execute') as allowed"))[0].allowed, false);
  assert.equal((await query("select has_function_privilege('authenticated', 'public.get_ephemeral_conversations()', 'execute') as allowed"))[0].allowed, true);
  await db.close();
  console.log('Passed: migration, unread preservation, sender/outsider rejection, fetch safety, pending extension, read TTL, idempotency, settings, cleanup, RPC grants.');
})().catch(error => { console.error(error); process.exitCode = 1; });
