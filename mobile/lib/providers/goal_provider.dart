import 'package:flutter/material.dart';
import '../models/goal.dart';
import '../models/reminder_policy.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'package:intl/intl.dart';

class GoalProvider with ChangeNotifier {
  final ApiService apiService;
  List<Goal> _goals = [];
  bool _isLoading = false;
  String _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  GoalProvider({required this.apiService});

  List<Goal> get goals => _goals;
  bool get isLoading => _isLoading;
  String get selectedDate => _selectedDate;

  void setSelectedDate(String date) {
    _selectedDate = date;
    fetchGoals();
  }

  Future<void> fetchGoals() async {
    _isLoading = true;
    notifyListeners();
    try {
      _goals = await apiService.getGoals(_selectedDate);
      await _rescheduleNotifications();
    } catch (e) {
      debugPrint('Error fetching goals: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _rescheduleNotifications() async {
    try {
      final policy = await apiService.getReminderPolicy();
      await NotificationService.scheduleNotifications(goals: _goals, policy: policy);
    } catch (e) {
      debugPrint('Error rescheduling notifications: $e');
    }
  }

  Future<void> completeGoal(int id) async {
    try {
      await apiService.completeGoal(id);
      await fetchGoals();
      await _rescheduleNotifications();
    } catch (e) {
      debugPrint('Error completing goal: $e');
    }
  }

  Future<void> snoozeGoal(int id, int minutes) async {
    try {
      await apiService.snoozeGoal(id, minutes);
      await fetchGoals();
      await _rescheduleNotifications();
    } catch (e) {
      debugPrint('Error snoozing goal: $e');
    }
  }

  Future<void> moveToTomorrow(int id) async {
    try {
      await apiService.moveToTomorrow(id);
      await fetchGoals();
      await _rescheduleNotifications();
    } catch (e) {
      debugPrint('Error moving goal: $e');
    }
  }

  Future<void> cancelGoal(int id) async {
    try {
      await apiService.cancelGoal(id);
      await fetchGoals();
      await _rescheduleNotifications();
    } catch (e) {
      debugPrint('Error canceling goal: $e');
    }
  }

  Future<void> rollover() async {
    try {
      await apiService.rollover();
      await fetchGoals();
      await _rescheduleNotifications();
    } catch (e) {
      debugPrint('Error during rollover: $e');
    }
  }
}
