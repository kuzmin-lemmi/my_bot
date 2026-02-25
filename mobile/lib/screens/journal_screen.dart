import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/goal_provider.dart';
import '../models/event.dart';
import 'package:intl/intl.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  List<GoalEvent> _events = [];
  bool _isLoading = false;
  String _date = DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() => _isLoading = true);
    try {
      final events = await context.read<GoalProvider>().apiService.getEvents(_date);
      setState(() => _events = events);
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Журнал')),
      body: Column(
        children: [
          ListTile(
            title: const Text('Дата'),
            trailing: Text(_date),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.parse(_date),
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _date = DateFormat('yyyy-MM-dd').format(picked));
                _fetchEvents();
              }
            },
          ),
          const Divider(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _events.isEmpty
                    ? const Center(child: Text('Нет событий за этот день'))
                    : ListView.builder(
                        itemCount: _events.length,
                        itemBuilder: (context, index) {
                          final event = _events[index];
                          return ListTile(
                            leading: Icon(_getIcon(event.actionType)),
                            title: Text(_translateAction(event.actionType)),
                            subtitle: Text('ID цели: ${event.goalId} | ${event.source}'),
                            trailing: Text(DateFormat('HH:mm').format(DateTime.parse(event.createdAt).toLocal())),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String action) {
    switch (action) {
      case 'created': return Icons.add_circle_outline;
      case 'updated': return Icons.edit;
      case 'completed': return Icons.check_circle;
      case 'snoozed': return Icons.snooze;
      case 'moved_to_tomorrow': return Icons.redo;
      case 'auto_moved_to_tomorrow': return Icons.auto_mode;
      case 'canceled': return Icons.cancel;
      default: return Icons.info_outline;
    }
  }

  String _translateAction(String action) {
    switch (action) {
      case 'created': return 'Создано';
      case 'updated': return 'Обновлено';
      case 'completed': return 'Выполнено';
      case 'snoozed': return 'Отложено';
      case 'moved_to_tomorrow': return 'Перенесено вручную';
      case 'auto_moved_to_tomorrow': return 'Авто-перенос';
      case 'canceled': return 'Отменено';
      default: return action;
    }
  }
}
