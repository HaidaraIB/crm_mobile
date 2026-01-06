class ClientTaskModel {
  final int id;
  final int client;
  final int stage;
  final String notes;
  final DateTime? reminderDate;
  final int createdBy;
  final DateTime createdAt;
  
  ClientTaskModel({
    required this.id,
    required this.client,
    required this.stage,
    required this.notes,
    this.reminderDate,
    required this.createdBy,
    required this.createdAt,
  });
  
  factory ClientTaskModel.fromJson(Map<String, dynamic> json) {
    return ClientTaskModel(
      id: json['id'] as int,
      client: json['client'] as int,
      stage: json['stage'] as int,
      notes: json['notes'] as String? ?? '',
      reminderDate: json['reminder_date'] != null
          ? DateTime.parse(json['reminder_date'] as String)
          : null,
      createdBy: json['created_by'] as int? ?? json['createdBy'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String? ?? json['createdAt'] as String),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client': client,
      'stage': stage,
      'notes': notes,
      'reminder_date': reminderDate?.toIso8601String(),
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

