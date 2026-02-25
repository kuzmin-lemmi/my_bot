class GoalEvent {
  final int id;
  final int goalId;
  final String actionType;
  final Map<String, dynamic> actionPayload;
  final String source;
  final String createdAt;

  GoalEvent({
    required this.id,
    required this.goalId,
    required this.actionType,
    required this.actionPayload,
    required this.source,
    required this.createdAt,
  });

  factory GoalEvent.fromJson(Map<String, dynamic> json) {
    return GoalEvent(
      id: json['id'],
      goalId: json['goal_id'],
      actionType: json['action_type'],
      actionPayload: Map<String, dynamic>.from(json['action_payload'] ?? {}),
      source: json['source'],
      createdAt: json['created_at'],
    );
  }
}
