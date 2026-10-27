import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit);

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        print('🔔 Notif diklik: ${response.payload}');
      },
    );

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'daily_channel',
        'Pengingat Harian',
        description: 'Pengingat belajar setiap hari',
        importance: Importance.high,
      ),
    );

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'ghosting_channel',
        'Ghosting Reminder',
        description: 'Pengingat saat tidak aktif',
        importance: Importance.high,
      ),
    );

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'gamifikasi_channel',
        'Gamifikasi & Pengingat',
        description: 'Notifikasi untuk tugas macet dan pengingat belajar',
        importance: Importance.high,
      ),
    );

    // ✅ Minta izin POST_NOTIFICATIONS via plugin (Android 13+)
    final granted = await androidPlugin?.requestNotificationsPermission();
    print('📱 Android POST_NOTIFICATIONS granted: $granted');
  }

  static Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_channel',
      'Pengingat Harian',
      channelDescription: 'Notifikasi instan',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    await _notificationsPlugin.cancel(id: id);

    final scheduleTime = _nextInstanceOfTime(hour, minute);
    print('⏰ Scheduling daily reminder id=$id at $scheduleTime');

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_channel',
        'Pengingat Harian',
        channelDescription: 'Pengingat belajar harian',
        importance: Importance.high,
        priority: Priority.high
      ),
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduleTime,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      print('✅ Daily reminder terjadwal (exact)');
    } catch (e) {
      print('⚠️ Exact gagal, fallback ke inexact: $e');
      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduleTime,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      print('✅ Daily reminder terjadwal (inexact)');
    }
  }
  static Future<void> scheduleGhostingReminder() async {
    await _notificationsPlugin.cancel(id: 3);

    final scheduleDate =
        tz.TZDateTime.now(tz.local).add(const Duration(days: 3));
    print('⏰ Scheduling ghosting reminder at $scheduleDate');

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'ghosting_channel',
        'Ghosting Reminder',
        channelDescription: 'Pengingat saat tidak aktif',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        id: 3,
        title: 'Avatarmu kangen nih 🥺',
        body:
            'Udah 3 hari kamu gak belajar bareng. Yuk cek 1 tugas kecil aja hari ini!',
        scheduledDate: scheduleDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      print('✅ Ghosting reminder terjadwal (exact)');
    } catch (e) {
      print('⚠️ Exact gagal, fallback ke inexact: $e');
      await _notificationsPlugin.zonedSchedule(
        id: 3,
        title: 'Avatarmu kangen nih 🥺',
        body:
            'Udah 3 hari kamu gak belajar bareng. Yuk cek 1 tugas kecil aja hari ini!',
        scheduledDate: scheduleDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      print('✅ Ghosting reminder terjadwal (inexact)');
    }
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static Future<List<PendingNotificationRequest>>
      getPendingNotifications() async {
    return await _notificationsPlugin.pendingNotificationRequests();
  }
}