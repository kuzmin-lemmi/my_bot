import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/goal_provider.dart';
import '../providers/policy_provider.dart';
import '../widgets/goal_card.dart';
import 'goal_edit_screen.dart';
import 'package:intl/intl.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GoalProvider>().fetchGoals();
      context.read<PolicyProvider>().fetchPolicy();
    });
  }

  @override
  Widget build(BuildContext context) {
    final goalProvider = context.watch<GoalProvider>();
    final policyProvider = context.watch<PolicyProvider>();
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMMM').format(now);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FocusDay'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => Navigator.pushNamed(context, '/calendar'),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.pushNamed(context, '/journal'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await goalProvider.fetchGoals();
          await policyProvider.fetchPolicy();
        },
        child: Column(
          children: [
            _buildHeader(dateStr, goalProvider),
            if (policyProvider.policy?.globalPauseUntil != null) _buildGlobalPauseBanner(policyProvider),
            Expanded(
              child: goalProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : goalProvider.goals.isEmpty
                      ? const Center(child: Text('Нет целей на сегодня. Время отдыхать!'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: goalProvider.goals.length,
                          itemBuilder: (context, index) {
                            return GoalCard(goal: goalProvider.goals[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const GoalEditScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHeader(String dateStr, GoalProvider provider) {
    final active = provider.goals.where((g) => g.status == 'active' || g.status == 'snoozed').length;
    final completed = provider.goals.where((g) => g.status == 'completed').length;

    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateStr, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatChip('Активно: $active', Colors.blue),
              const SizedBox(width: 8),
              _buildStatChip('Выполнено: $completed', Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildGlobalPauseBanner(PolicyProvider provider) {
    return Container(
      color: Colors.orange.withOpacity(0.2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.pause_circle_filled, color: Colors.orange),
          const SizedBox(width: 8),
          const Expanded(child: Text('Напоминания на паузе', style: TextStyle(fontWeight: FontWeight.bold))),
          TextButton(
            onPressed: () => provider.clearGlobalPause(),
            child: const Text('Снять'),
          ),
        ],
      ),
    );
  }
}
