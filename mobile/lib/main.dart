import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'providers/goal_provider.dart';
import 'providers/policy_provider.dart';
import 'screens/today_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/journal_screen.dart';

void main() {
  // Replace with your actual backend URL and Token
  const String baseUrl = 'http://localhost:8000';
  const String token = 'change-me';

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
        cardTheme: CardTheme(
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
