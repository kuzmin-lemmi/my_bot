import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/goal_provider.dart';
import 'package:intl/intl.dart';

class GoalEditScreen extends StatefulWidget {
  final Map<String, dynamic>? initialGoal;

  const GoalEditScreen({super.key, this.initialGoal});

  @override
  State<GoalEditScreen> createState() => _GoalEditScreenState();
}

class _GoalEditScreenState extends State<GoalEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _noteController;
  late String _date;
  String? _time;
  String? _priority;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialGoal?['title'] ?? '');
    _noteController = TextEditingController(text: widget.initialGoal?['note'] ?? '');
    _date = widget.initialGoal?['target_date'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    _time = widget.initialGoal?['target_time'];
    _priority = widget.initialGoal?['priority'];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.initialGoal == null ? 'Новая цель' : 'Редактирование')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Что нужно сделать?', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.isEmpty) ? 'Введите название' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Заметка (опционально)', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Дата'),
              subtitle: Text(_date),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            ListTile(
              title: const Text('Время'),
              subtitle: Text(_time ?? 'Не задано'),
              trailing: const Icon(Icons.access_time),
              onTap: _pickTime,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _priority,
              decoration: const InputDecoration(labelText: 'Приоритет', border: OutlineInputBorder()),
              items: ['low', 'medium', 'high']
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => _priority = v),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_date),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _date = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time != null ? TimeOfDay(hour: int.parse(_time!.split(':')[0]), minute: int.parse(_time!.split(':')[1])) : TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _time = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
    }
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'title': _titleController.text,
      'note': _noteController.text,
      'target_date': _date,
      'target_time': _time,
      'priority': _priority,
      'source': 'mobile',
    };

    final provider = context.read<GoalProvider>();
    try {
      await provider.apiService.createGoal(data);
      provider.fetchGoals();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }
}
