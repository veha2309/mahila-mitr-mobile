import 'package:flutter/material.dart';
import 'app_design.dart';

class HomeHeading extends StatelessWidget {
  const HomeHeading(
      {required this.date,
      required this.name,
      required this.onProfile,
      super.key});
  final DateTime date;
  final String name;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    const months = [
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}',
              style: const TextStyle(color: AppPalette.muted, fontSize: 12)),
          const SizedBox(height: 8),
          Text('Today', style: Theme.of(context).textTheme.headlineLarge),
        ])),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xffdfc8d2))),
          child: IconButton.filledTonal(
            tooltip: 'Profile and settings for $name',
            onPressed: onProfile,
            style: IconButton.styleFrom(
                backgroundColor: AppPalette.lilac,
                fixedSize: const Size(46, 46)),
            icon: Text(
                name.trim().isEmpty
                    ? 'M'
                    : name.trim().characters.first.toUpperCase(),
                style: const TextStyle(
                    fontSize: 18,
                    color: AppPalette.plum,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}

class DailyCheckInCard extends StatelessWidget {
  const DailyCheckInCard(
      {required this.onEdit,
      this.mood,
      this.flow,
      this.energy,
      this.symptoms = const [],
      this.note,
      super.key});
  final VoidCallback onEdit;
  final String? mood;
  final String? flow;
  final String? energy;
  final List<String> symptoms;
  final String? note;

  @override
  Widget build(BuildContext context) =>
      AppSurface(title: 'Today’s check-in', children: [
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth < 260 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.3
              ? 1
              : 3;
          final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
          return Wrap(spacing: 8, runSpacing: 8, children: [
            _reading(width, Icons.sentiment_satisfied_alt_outlined, 'Mood',
                mood, AppPalette.lilac),
            _reading(width, Icons.water_drop_outlined, 'Flow', flow,
                const Color(0xfffaeee5)),
            _reading(
                width, Icons.bolt_outlined, 'Energy', energy, AppPalette.sage),
          ]);
        }),
        if (symptoms.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
              spacing: 6,
              runSpacing: 6,
              children: symptoms
                  .map((symptom) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            border: Border.all(color: AppPalette.border),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(symptom,
                            style: const TextStyle(
                                fontSize: 12, color: AppPalette.muted)),
                      ))
                  .toList()),
        ],
        if (note != null && note!.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(note!,
              style: const TextStyle(
                  fontSize: 13, height: 1.5, color: AppPalette.ink)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.check_circle_outline,
              size: 15, color: AppPalette.plum),
          const SizedBox(width: 6),
          const Expanded(
              child: Text('Saved today',
                  style: TextStyle(fontSize: 11, color: AppPalette.muted))),
          TextButton(onPressed: onEdit, child: const Text('Edit entry')),
        ]),
      ]);

  Widget _reading(double width, IconData icon, String label, String? value,
          Color color) =>
      Container(
        width: width,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 21, color: AppPalette.plum),
          const SizedBox(height: 12),
          Text(value ?? 'Not logged',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppPalette.ink)),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(color: AppPalette.muted, fontSize: 11)),
        ]),
      );
}

class PeriodHistoryTile extends StatelessWidget {
  const PeriodHistoryTile(
      {required this.start,
      required this.end,
      this.isActive = false,
      this.onTap,
      super.key});
  final DateTime start;
  final DateTime? end;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final duration = end == null ? null : end!.difference(start).inDays + 1;
    final text = duration == null ? 'End date not logged' : '$duration days';
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: AppPalette.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                  color:
                      isActive ? const Color(0xffddb0c2) : AppPalette.border)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(
                      width: 52,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                          color: AppPalette.lilac,
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(children: [
                        Text(months[start.month - 1],
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppPalette.plum,
                                fontWeight: FontWeight.w600)),
                        Text('${start.day}',
                            style: const TextStyle(
                                fontSize: 23,
                                height: 1.3,
                                color: AppPalette.plum,
                                fontWeight: FontWeight.w600)),
                      ])),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                            isActive
                                ? 'Period in progress'
                                : '$text · ${start.year}',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 7),
                        if (duration != null && duration > 0)
                          Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: List.generate(
                                  duration.clamp(0, 12),
                                  (_) => Container(
                                      width: 7,
                                      height: 14,
                                      decoration: BoxDecoration(
                                          color: const Color(0xffc6809d),
                                          borderRadius:
                                              BorderRadius.circular(3))))),
                        if (isActive || duration == null)
                          Text(isActive ? 'Tap to record an end date' : text,
                              style: const TextStyle(
                                  fontSize: 12, color: AppPalette.muted)),
                      ])),
                  if (onTap != null) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right,
                        color: AppPalette.muted, size: 20),
                  ],
                ]),
              )),
        ));
  }
}
