/// Calendar dates for recorded periods never use the average period length.
/// An open period extends through today; future days are not recorded yet.
bool isRecordedPeriodDay(
  Iterable<Map<String, dynamic>> cycles,
  DateTime date, {
  required DateTime today,
}) {
  DateTime day(DateTime value) => DateTime(value.year, value.month, value.day);
  final target = day(date);
  final records = cycles.toList()
    ..sort((a, b) => (a['start_date'] as String)
        .compareTo(b['start_date'] as String));
  for (var i = 0; i < records.length; i++) {
    final cycle = records[i];
    final start = day(DateTime.parse(cycle['start_date'] as String));
    var end = cycle['end_date'] == null
        ? day(today)
        : day(DateTime.parse(cycle['end_date'] as String));
    // An older unfinished record cannot cover a newer cycle.
    if (i + 1 < records.length) {
      final next = day(DateTime.parse(records[i + 1]['start_date'] as String));
      if (!end.isBefore(next)) end = next.subtract(const Duration(days: 1));
    }
    if (!target.isBefore(start) && !target.isAfter(end)) return true;
  }
  return false;
}
