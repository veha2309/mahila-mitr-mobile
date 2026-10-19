import 'package:flutter/material.dart';
import 'app_design.dart';

/// A year overview; each month opens the existing detailed month calendar.
class YearCalendar extends StatelessWidget {
  const YearCalendar(
      {required this.selectedDay,
      required this.isPeriodDay,
      required this.isPredictedDay,
      required this.onYearChanged,
      required this.onMonthSelected,
      this.today,
      super.key});
  final DateTime selectedDay;
  final bool Function(DateTime) isPeriodDay;
  final bool Function(DateTime) isPredictedDay;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<DateTime> onMonthSelected;
  final DateTime? today;

  static const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  @override
  Widget build(BuildContext context) {
    final now = today ?? DateTime.now();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text('${selectedDay.year}',
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.6)),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(
                  child: TextButton(
                      onPressed: () => onYearChanged(now.year),
                      child: const Text('This year'))),
              IconButton(
                  tooltip: 'Previous year',
                  onPressed: () => onYearChanged(selectedDay.year - 1),
                  icon: const Icon(Icons.chevron_left)),
              IconButton(
                  tooltip: 'Next year',
                  onPressed: () => onYearChanged(selectedDay.year + 1),
                  icon: const Icon(Icons.chevron_right)),
            ]),
          ]),
      const SizedBox(height: 6),
      Wrap(spacing: 16, runSpacing: 8, children: [
        _legend(const Color(0xffb96285), 'Logged period'),
        _legend(const Color(0xfff3dce5), 'Predicted'),
      ]),
      const SizedBox(height: 18),
      LayoutBuilder(builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final columns = scale > 1.3
            ? (constraints.maxWidth >= 600 ? 2 : 1)
            : constraints.maxWidth >= 560
                ? 3
                : 2;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(spacing: 10, runSpacing: 12, children: [
          for (var month = 1; month <= 12; month++)
            SizedBox(width: width, child: _month(context, month, now)),
        ]);
      }),
    ]);
  }

  Widget _legend(Color color, String label) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppPalette.muted)),
      ]);

  Widget _month(BuildContext context, int month, DateTime now) {
    final first = DateTime(selectedDay.year, month);
    final count = DateUtils.getDaysInMonth(first.year, month);
    final offset = first.weekday - 1;
    final selected = selectedDay.month == month;
    final current = now.year == first.year && now.month == month;
    final logged =
        List.generate(count, (i) => DateTime(first.year, month, i + 1))
            .where(isPeriodDay)
            .length;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return Semantics(
      button: true,
      selected: selected,
      onTap: () => onMonthSelected(first),
      label:
          '${months[month - 1]} ${first.year}, $logged logged period days. Open month.',
      child: ExcludeSemantics(
          child: Material(
        color: AppPalette.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
                color: selected ? AppPalette.plum : AppPalette.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onMonthSelected(first),
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(months[month - 1],
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? AppPalette.plum
                                    : AppPalette.ink))),
                    if (current)
                      Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                              color: AppPalette.plum, shape: BoxShape.circle)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    for (final day in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                      Expanded(
                          child: Center(
                              child: Text(day,
                                  style: const TextStyle(
                                      fontSize: 8, color: AppPalette.muted)))),
                  ]),
                  const SizedBox(height: 6),
                  for (var week = 0; week < 6; week++)
                    Row(children: [
                      for (var weekday = 0; weekday < 7; weekday++)
                        Expanded(
                            child: SizedBox(
                                height: 18 * scale,
                                child: _day(
                                    first.year,
                                    month,
                                    week * 7 + weekday - offset + 1,
                                    count,
                                    now))),
                    ]),
                ],
              )),
        ),
      )),
    );
  }

  Widget _day(int year, int month, int day, int count, DateTime now) {
    if (day < 1 || day > count) return const SizedBox.shrink();
    final date = DateTime(year, month, day);
    final logged = isPeriodDay(date);
    final predicted = !logged && isPredictedDay(date);
    final isToday = DateUtils.isSameDay(date, now);
    return Container(
      key: ValueKey('year-day-$year-$month-$day'),
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: logged
            ? const Color(0xffb96285)
            : predicted
                ? const Color(0xfff3dce5)
                : null,
        borderRadius: BorderRadius.circular(5),
        border: isToday ? Border.all(color: AppPalette.plum, width: 1.5) : null,
      ),
      alignment: Alignment.center,
      child: Text('$day',
          style: TextStyle(
              fontSize: 9,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
              color: logged ? Colors.white : AppPalette.ink)),
    );
  }
}
