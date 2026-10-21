import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// One-shot reminders, refreshed whenever cycle/log data is synchronized.
class LoggingReminders {
  LoggingReminders(this.notifications);

  final FlutterLocalNotificationsPlugin notifications;
  static const payload = 'daily_log';
  static const firstId = 110000;
  static const horizon = 30;
  Future<void> _queue = Future.value();

  Future<void> sync({
    required bool enabled,
    required List<Map<String, dynamic>> cycles,
    required List<Map<String, dynamic>> logs,
    DateTime? now,
  }) {
    final dates = reminderDates(
      now: now ?? DateTime.now(),
      enabled: enabled,
      cycles: cycles,
      logs: logs,
    );
    _queue = _queue.then((_) async {
      for (var i = 0; i < horizon; i++) {
        await notifications.cancel(id: firstId + i);
      }
      for (var i = 0; i < dates.length; i++) {
        await notifications.zonedSchedule(
          id: firstId + i,
          title: 'Mahila Mitr',
          body: 'A moment for you: add your daily check-in.',
          // Convert each device-local calendar date to an absolute instant.
          scheduledDate: tz.TZDateTime.from(dates[i], tz.UTC),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'daily_logging',
              'Daily check-ins',
              channelDescription: 'Gentle reminders to add your daily log',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              visibility: NotificationVisibility.private,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
      }
    }).catchError((Object error) {
      debugPrint('Logging reminder sync failed: $error');
    });
    return _queue;
  }
}

List<DateTime> reminderDates({
  required DateTime now,
  required bool enabled,
  required List<Map<String, dynamic>> cycles,
  required List<Map<String, dynamic>> logs,
}) {
  if (!enabled || cycles.isEmpty) return [];
  final latest = cycles.reduce((a, b) =>
      (a['start_date'] as String).compareTo(b['start_date'] as String) >= 0
          ? a
          : b);
  if (latest['end_date'] != null) return [];
  final start = DateTime.parse(latest['start_date'] as String);
  final loggedDates = logs.map((log) => log['date_on']).toSet();
  return [
    for (var i = 0; i < LoggingReminders.horizon; i++)
      DateTime(now.year, now.month, now.day + i, 20),
  ].where((date) {
    final key = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return date.isAfter(now) &&
        !date.isBefore(start) &&
        !loggedDates.contains(key);
  }).toList();
}
