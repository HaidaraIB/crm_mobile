class ClientTaskModel {
  final int id;
  final int client;
  final int stage;
  final String? stageName;
  final String notes;
  final DateTime? reminderDate;
  final DateTime? reminderCompletedAt;
  final int createdBy;
  final String? createdByUsername;
  final DateTime createdAt;

  ClientTaskModel({
    required this.id,
    required this.client,
    required this.stage,
    this.stageName,
    required this.notes,
    this.reminderDate,
    this.reminderCompletedAt,
    required this.createdBy,
    this.createdByUsername,
    required this.createdAt,
  });

  bool get isReminderOpen =>
      reminderDate != null && reminderCompletedAt == null;

  factory ClientTaskModel.fromJson(Map<String, dynamic> json) {
    final stageRaw = json['stage'];
    final stageId = stageRaw is int
        ? stageRaw
        : stageRaw is Map<String, dynamic>
            ? stageRaw['id'] as int? ?? 0
            : int.tryParse('$stageRaw') ?? 0;

    return ClientTaskModel(
      id: json['id'] as int,
      client: json['client'] as int,
      stage: stageId,
      stageName: json['stage_name'] as String?,
      notes: json['notes'] as String? ?? '',
      reminderDate: json['reminder_date'] != null
          ? DateTime.parse(json['reminder_date'] as String)
          : null,
      reminderCompletedAt: json['reminder_completed_at'] != null
          ? DateTime.parse(json['reminder_completed_at'] as String)
          : null,
      createdBy: json['created_by'] as int? ?? json['createdBy'] as int? ?? 0,
      createdByUsername: json['created_by_username'] as String?,
      createdAt: DateTime.parse(
        (json['created_at'] as String?) ??
            (json['createdAt'] as String?) ??
            '1970-01-01T00:00:00.000Z',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client': client,
      'stage': stage,
      'stage_name': stageName,
      'notes': notes,
      'reminder_date': reminderDate?.toIso8601String(),
      'reminder_completed_at': reminderCompletedAt?.toIso8601String(),
      'created_by': createdBy,
      'created_by_username': createdByUsername,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
