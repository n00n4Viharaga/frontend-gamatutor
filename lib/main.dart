import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gamatutor_kanban/service/middleware.dart';
import 'package:gamatutor_kanban/service/notifService.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:gamatutor_kanban/utils/theme_provider.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  tz_data.initializeTimeZones();
  String timeZoneName = 'Asia/Jakarta';
  try {
    final TimezoneInfo currentTimeZone =
        await FlutterTimezone.getLocalTimezone();
    timeZoneName = currentTimeZone.identifier;
  } catch (e) {
    print('⚠️ Gagal mendapatkan timezone, menggunakan default: $e');
  }
  tz.setLocalLocation(tz.getLocation(timeZoneName));
  print('🌍 TIMEZONE SEKARANG: ${tz.local.name}');

  await NotificationService.init();

  final notifStatus = await Permission.notification.request();
  print('📱 POST_NOTIFICATIONS granted: ${notifStatus.isGranted}');
  if (!notifStatus.isGranted) {
    print('❌ Notifikasi DIBLOKIR user — scheduled tidak akan terlihat');
    if (notifStatus.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  final exactStatus = await Permission.scheduleExactAlarm.request();
  print('📱 SCHEDULE_EXACT_ALARM granted: ${exactStatus.isGranted}');
  if (!exactStatus.isGranted) {
    print('⚠️ Exact alarm DENIED — fallback ke inexact akan dipakai');
  }

  final batteryStatus = await Permission.ignoreBatteryOptimizations.request();
  print('📱 Battery optimization exempt: ${batteryStatus.isGranted}');
  if (!batteryStatus.isGranted) {
    print('⚠️ Battery optimization aktif — beberapa HP bisa membunuh alarm');
  }


  await NotificationService.scheduleDailyReminder(
    id: 1,
    title: 'Waktunya Belajar! 📚',
    body: 'Avatarmu sudah siap menemanimu. Yuk selesaikan 1 misi hari ini!',
    hour: 19,
    minute: 00,
  );

  await NotificationService.scheduleGhostingReminder();

  await Future.delayed(const Duration(milliseconds: 500));
  final pending = await NotificationService.getPendingNotifications();
  print('⏰ PENDING NOTIFS: ${pending.length}');
  for (final p in pending) {
    print('   → id=${p.id} "${p.title}"');
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Gamatutor Kanban',
      debugShowCheckedModeBanner: false,

      // ─── TEMA TERANG ───
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          primary: const Color(0xFF2563EB),
        ),
        useMaterial3: true,
      ),

      // ─── TEMA GELAP ───
      darkTheme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          primary: const Color(0xFF2563EB),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),

      themeMode: themeProvider.themeMode,

      home: const AuthMiddleware(),
    );
  }
}
