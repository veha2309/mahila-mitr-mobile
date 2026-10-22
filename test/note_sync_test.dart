import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mahila_mitr/note_sync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late HttpServer server;
  late SupabaseClient api;
  late int status;
  late Map<String, dynamic> response;
  late List<Map<String, dynamic>> sentRows;
  final note = <String, dynamic>{
    'id': '00000000-0000-0000-0000-000000000001',
    'link_id': '00000000-0000-0000-0000-000000000002',
    'sender_id': '00000000-0000-0000-0000-000000000003',
    'recipient_id': '00000000-0000-0000-0000-000000000004',
    'body': 'Thinking of you',
    'style': 'letter',
  };

  setUp(() async {
    status = 201;
    response = {};
    sentRows = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/rest/v1/notes');
      expect(request.uri.queryParameters, isNot(contains('on_conflict')));
      final prefer = request.headers.value('prefer') ?? '';
      expect(prefer, isNot(contains('resolution=')));
      expect(prefer, isNot(contains('return=representation')));
      sentRows.add(Map<String, dynamic>.from(
          jsonDecode(await utf8.decoder.bind(request).join()) as Map));
      request.response.statusCode = status;
      if (status != 201) {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(response));
      }
      await request.response.close();
    });
    api = SupabaseClient('http://127.0.0.1:${server.port}', 'test-key');
  });

  tearDown(() async {
    await api.dispose();
    await server.close(force: true);
  });

  test('sender inserts without upsert or requesting recipient-only read access',
      () async {
    await insertPendingNote(api, note);
    expect(sentRows, [note]);
  });

  test('retry acknowledges an already committed UUID without updating the note',
      () async {
    await insertPendingNote(api, note);
    status = 409;
    response = {
      'code': '23505',
      'message': 'duplicate key value violates unique constraint "notes_pkey"',
    };
    await insertPendingNote(api, note);
    expect(sentRows, [note, note]);
  });

  test('RLS rejection remains a failure so the outbox retains the note',
      () async {
    status = 403;
    response = {
      'code': '42501',
      'message': 'new row violates row-level security policy for table "notes"',
    };
    await expectLater(
        insertPendingNote(api, note),
        throwsA(
            isA<PostgrestException>().having((e) => e.code, 'code', '42501')));
  });

  test('unrelated unique constraint failures are not acknowledged', () async {
    status = 409;
    response = {
      'code': '23505',
      'message': 'duplicate key value violates unique constraint "another_key"',
    };
    await expectLater(
        insertPendingNote(api, note), throwsA(isA<PostgrestException>()));
  });

  test('server failures remain retryable', () async {
    status = 500;
    response = {'code': 'XX000', 'message': 'Database unavailable'};
    await expectLater(
        insertPendingNote(api, note), throwsA(isA<PostgrestException>()));
  });
}
