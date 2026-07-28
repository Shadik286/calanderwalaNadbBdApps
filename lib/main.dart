import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/auth_gate.dart';
import 'screens/home_shell.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Force portrait on phones — better UX for the calendar grid.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // Kick off notifications init in parallel with the auth gate.
  // ignore: discarded_futures
  NotificationService.instance.init();
  runApp(const CalendarWalaApp());
}

class CalendarWalaApp extends StatelessWidget {
  const CalendarWalaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettings>(
      valueListenable: SettingsService.instance,
      builder: (context, settings, _) {
        return MaterialApp(
          title: 'Calendar Wala',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          home: const AuthGate(),
          routes: {
            '/home': (_) => const HomeShell(),
          },
        );
      },
    );
  }
}
