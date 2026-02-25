import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/policy_provider.dart';
import '../models/reminder_policy.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<PolicyProvider>().fetchPolicy();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PolicyProvider>();
    final policy = provider.policy;

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки напоминаний')),
      body: provider.isLoading || policy == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildSection('Рабочее окно', [
                  _buildTimeTile('Начало', policy.activeWindowStart, (v) => _update(policy, activeWindowStart: v)),
                  _buildTimeTile('Конец', policy.activeWindowEnd, (v) => _update(policy, activeWindowEnd: v)),
                ]),
                _buildSection('Тихий час', [
                  SwitchListTile(
                    title: const Text('Включить тихий час'),
                    value: policy.quietPeriodEnabled,
                    onChanged: (v) => _update(policy, quietPeriodEnabled: v),
                  ),
                  if (policy.quietPeriodEnabled) ...[
                    _buildTimeTile('Начало', policy.quietPeriodStart ?? '14:00', (v) => _update(policy, quietPeriodStart: v)),
                    _buildTimeTile('Конец', policy.quietPeriodEnd ?? '17:00', (v) => _update(policy, quietPeriodEnd: v)),
                  ],
                ]),
                _buildSection('Поведение', [
                  ListTile(
                    title: const Text('Интервал (мин)'),
                    subtitle: Text('${policy.intervalMinutes} мин'),
                    onTap: () => _showIntPicker(context, 'Интервал', policy.intervalMinutes, (v) => _update(policy, intervalMinutes: v)),
                  ),
                  ListTile(
                    title: const Text('Режим настойчивости'),
                    subtitle: Text(policy.persistenceMode),
                    trailing: DropdownButton<String>(
                      value: policy.persistenceMode,
                      items: ['soft', 'normal', 'hard'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (v) => _update(policy, persistenceMode: v),
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Звук'),
                    value: policy.soundEnabled,
                    onChanged: (v) => _update(policy, soundEnabled: v),
                  ),
                ]),
                _buildSection('Эскалация', [
                  SwitchListTile(
                    title: const Text('Включить эскалацию'),
                    value: policy.escalationEnabled,
                    onChanged: (v) => _update(policy, escalationEnabled: v),
                  ),
                  if (policy.escalationEnabled)
                    ListTile(
                      title: const Text('Шаг эскалации (мин)'),
                      subtitle: Text('${policy.escalationStepMinutes} мин'),
                      onTap: () => _showIntPicker(context, 'Шаг', policy.escalationStepMinutes ?? 5, (v) => _update(policy, escalationStepMinutes: v)),
                    ),
                ]),
              ],
            ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        ),
        ...children,
        const Divider(),
      ],
    );
  }

  Widget _buildTimeTile(String title, String time, Function(String) onPicked) {
    return ListTile(
      title: Text(title),
      trailing: Text(time, style: const TextStyle(fontWeight: FontWeight.bold)),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: int.parse(time.split(':')[0]), minute: int.parse(time.split(':')[1])),
        );
        if (picked != null) {
          onPicked('${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
        }
      },
    );
  }

  void _showIntPicker(BuildContext context, String title, int current, Function(int) onPicked) {
    final controller = TextEditingController(text: current.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, keyboardType: TextInputType.number),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          TextButton(onPressed: () {
            Navigator.pop(context);
            onPicked(int.parse(controller.text));
          }, child: const Text('OK')),
        ],
      ),
    );
  }

  void _update(ReminderPolicy p, {
    String? activeWindowStart,
    String? activeWindowEnd,
    bool? quietPeriodEnabled,
    String? quietPeriodStart,
    String? quietPeriodEnd,
    int? intervalMinutes,
    String? persistenceMode,
    bool? soundEnabled,
    bool? escalationEnabled,
    int? escalationStepMinutes,
  }) {
    final newPolicy = ReminderPolicy(
      activeWindowStart: activeWindowStart ?? p.activeWindowStart,
      activeWindowEnd: activeWindowEnd ?? p.activeWindowEnd,
      quietPeriodEnabled: quietPeriodEnabled ?? p.quietPeriodEnabled,
      quietPeriodStart: quietPeriodStart ?? p.quietPeriodStart,
      quietPeriodEnd: quietPeriodEnd ?? p.quietPeriodEnd,
      intervalMinutes: intervalMinutes ?? p.intervalMinutes,
      snoozeOptions: p.snoozeOptions,
      soundEnabled: soundEnabled ?? p.soundEnabled,
      persistenceMode: persistenceMode ?? p.persistenceMode,
      escalationEnabled: escalationEnabled ?? p.escalationEnabled,
      escalationStepMinutes: escalationStepMinutes ?? p.escalationStepMinutes,
      globalPauseUntil: p.globalPauseUntil,
      askAboutAutoMovedMorning: p.askAboutAutoMovedMorning,
    );
    context.read<PolicyProvider>().updatePolicy(newPolicy);
  }
}
