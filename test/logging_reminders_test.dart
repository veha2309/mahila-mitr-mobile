import 'package:flutter_test/flutter_test.dart';
import 'package:mahila_mitr/logging_reminders.dart';

void main() {
  final now = DateTime(2026, 10, 21, 12);
  final active = <Map<String, dynamic>>[
    {'start_date': '2026-10-19', 'end_date': null},
  ];
  List<DateTime> dates({
    bool enabled = true,
    List<Map<String, dynamic>>? cycles,
    List<Map<String, dynamic>> logs = const [],
    DateTime? at,
  }) =>
      reminderDates(
          now: at ?? now,
          enabled: enabled,
          cycles: cycles ?? active,
          logs: logs);

  test('ongoing period with no log schedules one evening check-in per day', () {
    expect(dates().first, DateTime(2026, 10, 21, 20));
    expect(dates().length, 30);
    expect(dates().last, DateTime(2026, 11, 19, 20));
  });

  test('any daily log suppresses that date only, including no-flow logs', () {
    final result = dates(logs: [
      {'date_on': '2026-10-21', 'flow': 'none'},
      {'date_on': '2026-10-23', 'note': 'Feeling well'},
    ]);
    expect(result.first, DateTime(2026, 10, 22, 20));
    expect(result, isNot(contains(DateTime(2026, 10, 23, 20))));
    expect(result.length, 28);
  });

  test('ended periods, no periods, and disabled owners schedule nothing', () {
    expect(dates(enabled: false), isEmpty);
    expect(dates(cycles: []), isEmpty);
    expect(
        dates(cycles: [
          ...active,
          {'start_date': '2026-10-20', 'end_date': '2026-10-21'},
        ]),
        isEmpty);
  });

  test('does not send past reminders or reminders before period starts', () {
    expect(dates(at: DateTime(2026, 10, 21, 20)).first,
        DateTime(2026, 10, 22, 20));
    expect(
        dates(cycles: [
          {'start_date': '2026-10-23', 'end_date': null},
        ]).first,
        DateTime(2026, 10, 23, 20));
  });
}
