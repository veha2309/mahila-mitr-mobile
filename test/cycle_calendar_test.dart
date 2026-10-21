import 'package:flutter_test/flutter_test.dart';
import 'package:mahila_mitr/cycle_calendar.dart';

void main() {
  final today = DateTime(2026, 10, 21);
  test('open period continues past the average length, through today only', () {
    final cycles = [{'start_date': '2026-10-10', 'end_date': null}];
    for (var day = 10; day <= 21; day++) {
      expect(isRecordedPeriodDay(cycles, DateTime(2026, 10, day), today: today), isTrue);
    }
    expect(isRecordedPeriodDay(cycles, DateTime(2026, 10, 9), today: today), isFalse);
    expect(isRecordedPeriodDay(cycles, DateTime(2026, 10, 22), today: today), isFalse);
  });
  test('an explicit end date is inclusive and stops the period', () {
    final cycles = [{'start_date': '2026-10-10', 'end_date': '2026-10-18'}];
    expect(isRecordedPeriodDay(cycles, DateTime(2026, 10, 18, 23), today: today), isTrue);
    expect(isRecordedPeriodDay(cycles, DateTime(2026, 10, 19), today: today), isFalse);
  });
  test('an older unfinished record does not overwrite a later completed cycle', () {
    final cycles = [
      {'start_date': '2026-10-10', 'end_date': '2026-10-14'},
      {'start_date': '2026-09-10', 'end_date': null},
    ];
    expect(isRecordedPeriodDay(cycles, today, today: today), isFalse);
  });
}
