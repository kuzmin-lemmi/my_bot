import 'package:flutter/material.dart';
import '../models/reminder_policy.dart';
import '../services/api_service.dart';

class PolicyProvider with ChangeNotifier {
  final ApiService apiService;
  ReminderPolicy? _policy;
  bool _isLoading = false;

  PolicyProvider({required this.apiService});

  ReminderPolicy? get policy => _policy;
  bool get isLoading => _isLoading;

  Future<void> fetchPolicy() async {
    _isLoading = true;
    notifyListeners();
    try {
      _policy = await apiService.getReminderPolicy();
    } catch (e) {
      debugPrint('Error fetching policy: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updatePolicy(ReminderPolicy newPolicy) async {
    try {
      await apiService.updateReminderPolicy(newPolicy);
      _policy = newPolicy;
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating policy: $e');
    }
  }

  Future<void> setGlobalPause(int minutes) async {
    try {
      await apiService.globalPause(minutes);
      await fetchPolicy();
    } catch (e) {
      debugPrint('Error setting global pause: $e');
    }
  }

  Future<void> clearGlobalPause() async {
    try {
      await apiService.clearGlobalPause();
      await fetchPolicy();
    } catch (e) {
      debugPrint('Error clearing global pause: $e');
    }
  }
}
