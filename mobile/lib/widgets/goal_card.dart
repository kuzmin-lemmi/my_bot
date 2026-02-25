import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/goal.dart';
import '../providers/goal_provider.dart';
import '../providers/policy_provider.dart';
import 'package:intl/intl.dart';

class GoalCard extends StatelessWidget {
  final Goal goal;

  const GoalCard({super.key, required this.goal});

  @override
  Widget build(BuildContext context) {
    final isDone = goal.status == 'completed';
    final isCanceled = goal.status == 'canceled';
    final isSnoozed = goal.status == 'snoozed';
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          decoration: (isDone || isCanceled) ? TextDecoration.lineThrough : null,
                          color: (isDone || isCanceled) ? theme.disabledColor : null,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (goal.note != null && goal.note!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            goal.note!,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                _buildStatusBadge(context),
              ],
            ),
            if (goal.targetTime != null || isSnoozed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    if (goal.targetTime != null)
                      _buildInfoIcon(context, Icons.access_time, goal.targetTime!),
                    if (isSnoozed && goal.snoozeUntil != null) ...[
                      const SizedBox(width: 12),
                      _buildInfoIcon(context, Icons.snooze, _formatSnoozeUntil(goal.snoozeUntil!)),
                    ],
                  ],
                ),
              ),
            if (!isDone && !isCanceled) ...[
              const Divider(height: 24),
              _buildActions(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    Color color;
    String label;
    switch (goal.status) {
      case 'active':
        color = Colors.blue;
        label = 'Активно';
        break;
      case 'snoozed':
        color = Colors.orange;
        label = 'Отложено';
        break;
      case 'completed':
        color = Colors.green;
        label = 'Готово';
        break;
      case 'canceled':
        color = Colors.grey;
        label = 'Отменено';
        break;
      default:
        color = Colors.blue;
        label = goal.status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildInfoIcon(BuildContext context, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).hintColor),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  String _formatSnoozeUntil(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return 'до ${DateFormat('HH:mm').format(dt)}';
    } catch (e) {
      return '';
    }
  }

  Widget _buildActions(BuildContext context) {
    final provider = context.read<GoalProvider>();
    final policy = context.read<PolicyProvider>().policy;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ActionButton(
          icon: Icons.check_circle_outline,
          label: 'Готово',
          color: Colors.green,
          onPressed: () => _confirmAction(context, 'Завершить цель?', () => provider.completeGoal(goal.id)),
        ),
        _ActionButton(
          icon: Icons.snooze,
          label: 'Позже',
          color: Colors.orange,
          onPressed: () => _showSnoozeDialog(context, policy?.snoozeOptions ?? [10, 30, 60]),
        ),
        _ActionButton(
          icon: Icons.redo,
          label: 'Завтра',
          color: Colors.blue,
          onPressed: () => provider.moveToTomorrow(goal.id),
        ),
        _ActionButton(
          icon: Icons.cancel_outlined,
          label: 'Отмена',
          color: Colors.red,
          onPressed: () => _confirmAction(context, 'Отменить цель?', () => provider.cancelGoal(goal.id)),
        ),
      ],
    );
  }

  void _confirmAction(BuildContext context, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Подтверждение'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Нет')),
          TextButton(onPressed: () {
            Navigator.pop(context);
            onConfirm();
          }, child: const Text('Да')),
        ],
      ),
    );
  }

  void _showSnoozeDialog(BuildContext context, List<int> options) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Отложить на:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: options.map((mins) => ActionChip(
                label: Text('$mins мин'),
                onPressed: () {
                  Navigator.pop(context);
                  context.read<GoalProvider>().snoozeGoal(goal.id, mins);
                },
              )).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
