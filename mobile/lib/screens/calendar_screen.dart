import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/goal_provider.dart';
import 'package:intl/intl.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<String, dynamic> _calendarData = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchCalendarData();
  }

  void _fetchCalendarData() async {
    final provider = context.read<GoalProvider>();
    final monthStr = DateFormat('yyyy-MM').format(_focusedDay);
    try {
      final data = await provider.apiService.getCalendar(monthStr);
      setState(() => _calendarData = data);
    } catch (e) {
      debugPrint('Error fetching calendar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Календарь')),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              context.read<GoalProvider>().setSelectedDate(DateFormat('yyyy-MM-dd').format(selectedDay));
              Navigator.pop(context); // Return to Today/Main screen with selected date
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
              _fetchCalendarData();
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                final dateStr = DateFormat('yyyy-MM-dd').format(date);
                final dayData = (_calendarData['days'] as List?)?.firstWhere(
                  (d) => d['date'] == dateStr,
                  orElse: () => null,
                );
                if (dayData != null && dayData['total'] > 0) {
                  return _buildMarker(dayData);
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarker(Map<String, dynamic> data) {
    return Positioned(
      bottom: 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${data['active']}/${data['total']}',
          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
