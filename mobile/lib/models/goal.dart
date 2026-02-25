class Goal {
  final int id;
  final String title;
  final String? note;
  final String targetDate;
  final String? targetTime;
  final String? priority;
  final String status;
  final String? snoozeUntil;
  final String createdFrom;
  final String? lastRemindedAt;
  final int reminderIgnoreCount;
  final String? completedAt;
  final String? canceledAt;
  final String createdAt;
  final String updatedAt;

  Goal({
    required this.id,
    required this.title,
    this.note,
    required this.targetDate,
    this.targetTime,
    this.priority,
    required this.status,
    this.snoozeUntil,
    required this.createdFrom,
    this.lastRemindedAt,
    required this.reminderIgnoreCount,
    this.completedAt,
    this.canceledAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'],
      title: json['title'],
      note: json['note'],
      targetDate: json['target_date'],
      targetTime: json['target_time'],
      priority: json['priority'],
      status: json['status'],
      snoozeUntil: json['snooze_until'],
      createdFrom: json['created_from'],
      lastRemindedAt: json['last_reminded_at'],
      reminderIgnoreCount: json['reminder_ignore_count'],
      completedAt: json['completed_at'],
      canceledAt: json['canceled_at'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'note': note,
      'target_date': targetDate,
      'target_time': targetTime,
      'priority': priority,
      'status': status,
      'snooze_until': snoozeUntil,
      'created_from': createdFrom,
      'last_reminded_at': lastRemindedAt,
      'reminder_ignore_count': reminderIgnoreCount,
      'completed_at': completedAt,
      'canceled_at': canceledAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
