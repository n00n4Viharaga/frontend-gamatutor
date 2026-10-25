import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gamatutor_kanban/service/middleware.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart'; // ★ Tambahan
import 'package:gamatutor_kanban/utils/theme_provider.dart'; // ★ Tambahan

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  tz.initializeTimeZones();

  // init notification settings
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);

  await flutterLocalNotificationsPlugin.initialize(settings: initSettings);
  var status = await Permission.notification.request();
  print("Notification permission: $status");

  runApp(
    // ★ BUNGKUS DENGAN PROVIDER AGAR TEMA BISA BERUBAH
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
    // ★ Ambil state tema saat ini
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Gamatutor Kanban',
      debugShowCheckedModeBanner: false,
      
      // ─── TEMA TERANG (LIGHT) ───
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          primary: const Color(0xFF2563EB),
        ),
        useMaterial3: true,
      ),

      // ─── TEMA GELAP (DARK) ★ TAMBAHAN BARU ───
      darkTheme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Background gelap
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          primary: const Color(0xFF2563EB),
          brightness: Brightness.dark, // ★ Kunci Mode Gelap
        ),
        useMaterial3: true,
      ),

      // ★ Ini yang membuat aplikasi merespons switch di halaman Akun
      themeMode: themeProvider.themeMode,

      home: const AuthMiddleware(),
    );
  }
}