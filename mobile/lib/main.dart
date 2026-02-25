import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'providers/goal_provider.dart';
import 'providers/policy_provider.dart';
import 'screens/today_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/journal_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notification service
  await NotificationService.initialize();
  await NotificationService.requestPermissions();

  // Can be injected at build time via --dart-define.
  const String baseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
  const String token = String.fromEnvironment(
    'MVP_TOKEN',
    defaultValue: 'change-me',
  );

  final apiService = ApiService(baseUrl: baseUrl, token: token);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GoalProvider(apiService: apiService)),
        ChangeNotifierProvider(create: (_) => PolicyProvider(apiService: apiService)),
      ],
      child: const FocusDayApp(),
    ),
  );
}

class FocusDayApp extends StatelessWidget {
  const FocusDayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FocusDay',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const TodayScreen(),
      routes: {
        '/calendar': (context) => const CalendarScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/journal': (context) => const JournalScreen(),
      },
    );
  }
}
