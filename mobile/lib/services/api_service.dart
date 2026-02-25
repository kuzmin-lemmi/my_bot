import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/goal.dart';
import '../models/reminder_policy.dart';
import '../models/event.dart';

class ApiService {
  final String baseUrl;
  final String token;

  ApiService({required this.baseUrl, required this.token});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<List<Goal>> getGoals(String date) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/goals?date=$date'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['data']['items'] as List)
          .map((item) => Goal.fromJson(item))
          .toList();
    }
    throw Exception('Failed to load goals: ${response.body}');
  }

  Future<Goal> createGoal(Map<String, dynamic> goalData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/goals'),
      headers: _headers,
      body: jsonEncode(goalData),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Goal.fromJson(data['data']['goal']);
    }
    throw Exception('Failed to create goal: ${response.body}');
  }

  Future<void> completeGoal(int id) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/goals/$id/complete'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to complete goal: ${response.body}');
    }
  }

  Future<void> snoozeGoal(int id, int minutes) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/goals/$id/snooze'),
      headers: _headers,
      body: jsonEncode({'minutes': minutes}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to snooze goal: ${response.body}');
    }
  }

  Future<void> moveToTomorrow(int id) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/goals/$id/move-to-tomorrow'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to move goal to tomorrow: ${response.body}');
    }
  }

  Future<void> cancelGoal(int id) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/goals/$id/cancel'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to cancel goal: ${response.body}');
    }
  }

  Future<ReminderPolicy> getReminderPolicy() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/reminder-policy'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return ReminderPolicy.fromJson(data['data']);
    }
    throw Exception('Failed to load policy: ${response.body}');
  }

  Future<void> updateReminderPolicy(ReminderPolicy policy) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/reminder-policy'),
      headers: _headers,
      body: jsonEncode(policy.toJson()),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update policy: ${response.body}');
    }
  }

  Future<List<GoalEvent>> getEvents(String date) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/events?date=$date'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['data']['items'] as List)
          .map((item) => GoalEvent.fromJson(item))
          .toList();
    }
    throw Exception('Failed to load events: ${response.body}');
  }

  Future<Map<String, dynamic>> getCalendar(String month) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/goals/calendar?month=$month'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    }
    throw Exception('Failed to load calendar: ${response.body}');
  }

  Future<void> globalPause(int minutes) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/reminder-policy/global-pause'),
      headers: _headers,
      body: jsonEncode({'minutes': minutes}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to set global pause: ${response.body}');
    }
  }

  Future<void> clearGlobalPause() async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/reminder-policy/global-pause/clear'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to clear global pause: ${response.body}');
    }
  }

  Future<void> rollover() async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/goals/rollover'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to rollover goals: ${response.body}');
    }
  }
}
