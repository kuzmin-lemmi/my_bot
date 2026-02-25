import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/goal.dart';
import '../models/reminder_policy.dart';
import 'package:intl/intl.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
      },
    );

    tzdata.initializeTimeZones();

    _initialized = true;
  }

  static Future<void> scheduleNotifications({
    required List<Goal> goals,
    required ReminderPolicy policy,
  }) async {
    await _notifications.cancelAll();

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final activeGoals = goals.where((g) => 
      g.status == 'active' && 
      g.targetDate == todayStr
    ).toList();

    if (activeGoals.isEmpty) return;

    if (policy.globalPauseUntil != null) {
      final pauseUntil = DateTime.parse(policy.globalPauseUntil!).toLocal();
      if (now.isBefore(pauseUntil)) {
        return; // Skip scheduling during global pause
      }
    }

    final nextTime = _calculateNextNotification(now, policy);
    if (nextTime == null) return;

    final goal = activeGoals.first; // Rotation logic can be enhanced
    await _showNotification(goal, nextTime);
  }

  static DateTime? _calculateNextNotification(DateTime now, ReminderPolicy policy) {
    final activeStart = _parseTime(policy.activeWindowStart);
    final activeEnd = _parseTime(policy.activeWindowEnd);
    
    var candidate = now.add(Duration(minutes: policy.intervalMinutes));
    
    // Check if within active window
    final candidateTime = TimeOfDay.fromDateTime(candidate);
    if (!_isInWindow(candidateTime, activeStart, activeEnd)) {
      // Schedule for start of next active window
      candidate = DateTime(
        now.year, now.month, now.day,
        activeStart.hour, activeStart.minute,
      );
      if (candidate.isBefore(now)) {
        candidate = candidate.add(const Duration(days: 1));
      }
      return candidate;
    }

    // Check quiet period
    if (policy.quietPeriodEnabled && 
        policy.quietPeriodStart != null && 
        policy.quietPeriodEnd != null) {
      final quietStart = _parseTime(policy.quietPeriodStart!);
      final quietEnd = _parseTime(policy.quietPeriodEnd!);
      
      if (_isInWindow(candidateTime, quietStart, quietEnd)) {
        candidate = DateTime(
          candidate.year, candidate.month, candidate.day,
          quietEnd.hour, quietEnd.minute,
        );
      }
    }

    return candidate;
  }

  static TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static bool _isInWindow(TimeOfDay time, TimeOfDay start, TimeOfDay end) {
    final timeMinutes = time.hour * 60 + time.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    
    if (startMinutes <= endMinutes) {
      return timeMinutes >= startMinutes && timeMinutes <= endMinutes;
    } else {
      // Window crosses midnight
      return timeMinutes >= startMinutes || timeMinutes <= endMinutes;
    }
  }

  static Future<void> _showNotification(Goal goal, DateTime scheduledTime) async {
    const androidDetails = AndroidNotificationDetails(
      'focus_day_reminders',
      'Goal Reminders',
      channelDescription: 'Persistent reminders for your daily goals',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
      autoCancel: false,
      enableVibration: true,
      playSound: true,
      fullScreenIntent: true,
    );

    const details = NotificationDetails(android: androidDetails);

    final tzScheduled = tz.TZDateTime.from(scheduledTime, tz.local);

    await _notifications.zonedSchedule(
      goal.id,
      'Напоминание: ${goal.title}',
      goal.note ?? 'Пора выполнить эту цель!',
      tzScheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> requestPermissions() async {
    final androidImplementation = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();
    await androidImplementation?.requestExactAlarmsPermission();
  }
}
