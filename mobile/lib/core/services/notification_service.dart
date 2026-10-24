import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local notifications: streak reminder at 20.00, slot-open and invite alerts.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _streakId = 2000;
  static const _channel = AndroidNotificationDetails(
    'klubby_main',
    'Ajakan & pengingat',
    channelDescription: 'Ajakan main, slot mabar terbuka & pengingat streak',
    importance: Importance.high,
    priority: Priority.high,
  );
  static const _details = NotificationDetails(android: _channel, iOS: DarwinNotificationDetails());

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(_guessLocation());
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permission is requested later from A8, not at launch.
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ),
    );
    _ready = true;
  }

  Future<void> show(int id, String title, String body) async {
    await init();
    await _plugin.show(id: id, title: title, body: body, notificationDetails: _details);
  }

  /// Daily "streak kamu belum aman" nudge at 20.00 local time.
  Future<void> scheduleStreakReminder({int hour = 20}) async {
    await init();
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id: _streakId,
      title: 'Streak kamu belum aman! 🔥',
      body: 'Rekam aktivitas 10 menit biar maskotmu tetap semangat.',
      scheduledDate: at,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelStreakReminder() async {
    await init();
    await _plugin.cancel(id: _streakId);
  }

  /// Indonesia spans three zones; pick by device offset (no extra plugin needed).
  tz.Location _guessLocation() {
    final h = DateTime.now().timeZoneOffset.inHours;
    final name = switch (h) {
      7 => 'Asia/Jakarta',
      8 => 'Asia/Makassar',
      9 => 'Asia/Jayapura',
      _ => 'UTC',
    };
    try {
      return tz.getLocation(name);
    } on Exception {
      return tz.UTC;
    }
  }
}
