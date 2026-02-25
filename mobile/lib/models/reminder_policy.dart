import 'dart:convert';

class ReminderPolicy {
  final String activeWindowStart;
  final String activeWindowEnd;
  final bool quietPeriodEnabled;
  final String? quietPeriodStart;
  final String? quietPeriodEnd;
  final int intervalMinutes;
  final List<int> snoozeOptions;
  final bool soundEnabled;
  final String persistenceMode;
  final bool escalationEnabled;
  final int? escalationStepMinutes;
  final String? globalPauseUntil;
  final bool askAboutAutoMovedMorning;

  ReminderPolicy({
    required this.activeWindowStart,
    required this.activeWindowEnd,
    required this.quietPeriodEnabled,
    this.quietPeriodStart,
    this.quietPeriodEnd,
    required this.intervalMinutes,
    required this.snoozeOptions,
    required this.soundEnabled,
    required this.persistenceMode,
    required this.escalationEnabled,
    this.escalationStepMinutes,
    this.globalPauseUntil,
    required this.askAboutAutoMovedMorning,
  });

  factory ReminderPolicy.fromJson(Map<String, dynamic> json) {
    return ReminderPolicy(
      activeWindowStart: json['active_window_start'],
      activeWindowEnd: json['active_window_end'],
      quietPeriodEnabled: json['quiet_period_enabled'] == 1 || json['quiet_period_enabled'] == true,
      quietPeriodStart: json['quiet_period_start'],
      quietPeriodEnd: json['quiet_period_end'],
      intervalMinutes: json['interval_minutes'],
      snoozeOptions: List<int>.from(jsonDecode(json['default_snooze_options'])),
      soundEnabled: json['sound_enabled'] == 1 || json['sound_enabled'] == true,
      persistenceMode: json['persistence_mode'],
      escalationEnabled: json['escalation_enabled'] == 1 || json['escalation_enabled'] == true,
      escalationStepMinutes: json['escalation_step_minutes'],
      globalPauseUntil: json['global_pause_until'],
      askAboutAutoMovedMorning: json['ask_about_auto_moved_morning'] == 1 || json['ask_about_auto_moved_morning'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'active_window_start': activeWindowStart,
      'active_window_end': activeWindowEnd,
      'quiet_period_enabled': quietPeriodEnabled,
      'quiet_period_start': quietPeriodStart,
      'quiet_period_end': quietPeriodEnd,
      'interval_minutes': intervalMinutes,
      'default_snooze_options': jsonEncode(snoozeOptions),
      'sound_enabled': soundEnabled,
      'persistence_mode': persistenceMode,
      'escalation_enabled': escalationEnabled,
      'escalation_step_minutes': escalationStepMinutes,
      'global_pause_until': globalPauseUntil,
      'ask_about_auto_moved_morning': askAboutAutoMovedMorning,
    };
  }
}
