import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/note.dart';

/// Wraps flutter_local_notifications to schedule/cancel a single reminder
/// per note. Notification id is derived from Note.notificationId so
/// scheduling the same note twice replaces the previous reminder.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
    } catch (_) {
      // Falls back to UTC if the platform timezone lookup fails.
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    _initialized = true;
  }

  Future<void> scheduleReminder(Note note) async {
    if (!note.reminderEnabled || note.reminderTime == null) {
      await cancelReminder(note);
      return;
    }

    final scheduledDate = tz.TZDateTime.from(note.reminderTime!, tz.local);
    final now = tz.TZDateTime.now(tz.local);
    if (scheduledDate.isBefore(now)) {
      // Reminder time already passed; don't schedule a stale notification.
      return;
    }

    await _plugin.zonedSchedule(
      note.notificationId,
      note.title.isEmpty ? 'Reminder' : note.title,
      note.description.isEmpty ? 'You have a reminder in Calendar Wala' : note.description,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'calendar_wala_reminders',
          'Reminders',
          channelDescription: 'Reminders for notes added in Calendar Wala',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      // alarmClock delivers on-time even if the app is closed/killed, and
      // unlike exactAllowWhileIdle it doesn't depend on the user manually
      // granting the "Alarms & reminders" permission on Android 12+.
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelReminder(Note note) async {
    await _plugin.cancel(note.notificationId);
  }
}
