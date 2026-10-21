import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

typedef DashboardMutation = Map<String, dynamic>;

/// One atomic Hive value holds a snapshot and its outbox for each account/role.
/// Never remove an outbox item until the server has acknowledged that exact id.
class DashboardStore {
  DashboardStore(this.box);

  final Box<String> box;
  Future<void> _writes = Future.value();
  final Set<String> _syncing = {};
  final Set<String> _inFlight = {};
  static const _tables = {
    'cycles': 'cycles',
    'day_logs': 'dayLogs',
    'date_ratings': 'ratings',
    'notes': 'notes',
    'profiles': 'profiles',
  };

  static Future<DashboardStore>? _opening;
  static Future<DashboardStore> open() => _opening ??= _open().onError((Object error, StackTrace stack) {
    _opening = null;
    Error.throwWithStackTrace(error, stack);
  });

  static Future<DashboardStore> _open() async {
    await Hive.initFlutter();
    const storage = FlutterSecureStorage();
    const keyName = 'dashboard_hive_key_v1';
    var encoded = await storage.read(key: keyName);
    if (encoded == null) {
      encoded = base64UrlEncode(Hive.generateSecureKey());
      await storage.write(key: keyName, value: encoded);
    }
    final box = await Hive.openBox<String>('dashboard_v1',
        encryptionCipher: HiveAesCipher(base64Url.decode(encoded)));
    return DashboardStore(box);
  }

  static String accountKey(String userId, String role) => '$userId:$role';

  Map<String, dynamic> _read(String key) => box.containsKey(key)
      ? Map<String, dynamic>.from(jsonDecode(box.get(key)!) as Map)
      : {'snapshot': <String, dynamic>{}, 'pending': <dynamic>[]};

  Map<String, dynamic>? snapshot(String key) {
    final data = _read(key)['snapshot'] as Map;
    return data.isEmpty ? null : Map<String, dynamic>.from(data);
  }

  int pendingCount(String key) => (_read(key)['pending'] as List).length;

  Future<void> _write(String key, void Function(Map<String, dynamic>) edit) {
    final next = _writes.then((_) async {
      final state = _read(key);
      edit(state);
      await box.put(key, jsonEncode(state));
    });
    // A failed write is reported to its caller and cannot poison later writes.
    _writes = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  Future<void> acceptRemote(String key, Map<String, dynamic> remote) =>
      _write(key, (state) {
        final snapshot = Map<String, dynamic>.from(remote);
        for (final item in state['pending'] as List) {
          _apply(snapshot, Map<String, dynamic>.from(item as Map));
        }
        state['snapshot'] = snapshot;
      });

  Future<void> enqueue(String key, String table, Map<String, dynamic> row,
      {bool delete = false, String? conflict, String? rpc}) {
    if (!_tables.containsKey(table)) throw ArgumentError.value(table);
    final item = <String, dynamic>{
      'operationId': const Uuid().v4(),
      'table': table,
      'row': Map<String, dynamic>.from(row),
      'delete': delete,
      'conflict': conflict ?? 'id',
      'rpc': rpc,
    };
    return _write(key, (state) {
      final pending = state['pending'] as List;
      // Replace unsent edits to the same row with the latest complete value.
      pending.removeWhere((old) => !_inFlight.contains(old['operationId']) &&
          old['table'] == table && _sameRow(old['row'] as Map, row, table));
      pending.add(item);
      _apply(state['snapshot'] as Map<String, dynamic>, item);
    });
  }

  static bool _sameRow(Map a, Map b, String table) {
    if (a['id'] != null && a['id'] == b['id']) return true;
    if (table == 'day_logs') {
      return a['owner_id'] == b['owner_id'] && a['date_on'] == b['date_on'];
    }
    if (table == 'date_ratings') {
      return a['author_id'] == b['author_id'] &&
          a['link_id'] == b['link_id'] && a['date_on'] == b['date_on'];
    }
    return false;
  }

  static void _apply(Map<String, dynamic> snapshot, DashboardMutation item) {
    final table = item['table'] as String;
    final row = Map<String, dynamic>.from(item['row'] as Map);
    if (table == 'profiles') {
      snapshot['displayName'] = row['display_name'];
      return;
    }
    final field = _tables[table]!;
    final rows = List<Map<String, dynamic>>.from(
        (snapshot[field] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
    rows.removeWhere((old) => _sameRow(old, row, table));
    if (item['delete'] != true) rows.add(row);
    final sortField = table == 'cycles' ? 'start_date' :
        table == 'notes' ? 'created_at' : 'date_on';
    rows.sort((a, b) => (b[sortField]?.toString() ?? '')
        .compareTo(a[sortField]?.toString() ?? ''));
    snapshot[field] = rows;
  }

  /// Retry-safe UUID upserts are supplied by the caller. Connectivity events
  /// trigger retries, but only a successful server response means synced.
  Future<void> flush(String key,
      Future<void> Function(DashboardMutation) send,
      {required bool Function() isCurrentAccount}) async {
    if (!_syncing.add(key)) return;
    try {
      await _writes;
      while (isCurrentAccount()) {
        final pending = _read(key)['pending'] as List;
        if (pending.isEmpty) return;
        final item = Map<String, dynamic>.from(pending.first as Map);
        final id = item['operationId'] as String;
        _inFlight.add(id);
        try {
          await send(item);
          await _write(key, (state) {
            (state['pending'] as List).removeWhere((e) => e['operationId'] == id);
          });
        } finally {
          _inFlight.remove(id);
        }
      }
    } finally {
      _syncing.remove(key);
    }
  }
}
