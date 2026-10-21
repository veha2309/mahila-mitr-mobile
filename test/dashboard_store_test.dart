import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mahila_mitr/dashboard_store.dart';

void main() {
  late Directory directory;
  late Box<String> box;
  late DashboardStore store;
  const key = 'owner:owner';
  final cycle = <String, dynamic>{
    'id': 'cycle-1', 'owner_id': 'owner', 'start_date': '2026-10-10', 'end_date': null,
  };
  Map<String, dynamic> remote() => {
    'displayName': 'Test', 'cycles': [cycle], 'dayLogs': [], 'ratings': [], 'notes': [],
  };

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('dashboard_test_');
    Hive.init(directory.path);
    box = await Hive.openBox<String>('test', encryptionCipher: HiveAesCipher(List.generate(32, (i) => i)));
    store = DashboardStore(box);
    await store.acceptRemote(key, remote());
  });
  tearDown(() async {
    await box.close();
    await directory.delete(recursive: true);
  });

  test('offline end-date survives closing and reopening encrypted Hive', () async {
    await store.enqueue(key, 'cycles', {...cycle, 'end_date': '2026-10-21'});
    await box.close();
    box = await Hive.openBox<String>('test', encryptionCipher: HiveAesCipher(List.generate(32, (i) => i)));
    store = DashboardStore(box);
    expect(store.snapshot(key)!['cycles'][0]['end_date'], '2026-10-21');
    expect(store.pendingCount(key), 1);
    expect(store.snapshot('another-user:owner'), isNull);
    expect(store.snapshot('owner:partner'), isNull);
  });

  test('failed sync keeps pending edits; stale fetch cannot undo them', () async {
    await store.enqueue(key, 'cycles', {...cycle, 'end_date': '2026-10-21'});
    await expectLater(store.flush(key, (_) async => throw const SocketException('offline'),
        isCurrentAccount: () => true), throwsA(isA<SocketException>()));
    await store.acceptRemote(key, remote());
    expect(store.snapshot(key)!['cycles'][0]['end_date'], '2026-10-21');
    expect(store.pendingCount(key), 1);
    final sent = <DashboardMutation>[];
    await store.flush(key, (item) async => sent.add(item), isCurrentAccount: () => true);
    expect(sent.single['row']['end_date'], '2026-10-21');
    expect(store.pendingCount(key), 0);
  });

  test('edit during an in-flight save remains queued and is sent next', () async {
    await store.enqueue(key, 'cycles', cycle);
    final started = Completer<void>();
    final release = Completer<void>();
    final sent = <DashboardMutation>[];
    final syncing = store.flush(key, (item) async {
      sent.add(item);
      if (sent.length == 1) { started.complete(); await release.future; }
    }, isCurrentAccount: () => true);
    await started.future;
    await store.enqueue(key, 'cycles', {...cycle, 'end_date': '2026-10-21'});
    expect(store.pendingCount(key), 2);
    release.complete();
    await syncing;
    expect(sent.length, 2);
    expect(sent.last['row']['end_date'], '2026-10-21');
    expect(store.pendingCount(key), 0);
  });

  test('unsent daily edits coalesce, deletes stay deleted through refresh', () async {
    final log = {'id': 'log-1', 'owner_id': 'owner', 'date_on': '2026-10-21', 'flow': 'light'};
    await store.enqueue(key, 'day_logs', log);
    await store.enqueue(key, 'day_logs', {...log, 'flow': 'heavy'});
    expect(store.pendingCount(key), 1);
    expect(store.snapshot(key)!['dayLogs'][0]['flow'], 'heavy');
    await store.enqueue(key, 'cycles', cycle, delete: true);
    await store.acceptRemote(key, remote());
    expect(store.snapshot(key)!['cycles'], isEmpty);
    expect(store.snapshot(key)!['dayLogs'].length, 1);
  });

  test('account change stops replay and never touches another account queue', () async {
    await store.enqueue(key, 'cycles', cycle);
    await store.enqueue('another:owner', 'cycles', {...cycle, 'owner_id': 'another'});
    var sent = 0;
    await store.flush(key, (_) async { sent++; }, isCurrentAccount: () => false);
    expect(sent, 0);
    expect(store.pendingCount(key), 1);
    expect(store.pendingCount('another:owner'), 1);
  });
}
