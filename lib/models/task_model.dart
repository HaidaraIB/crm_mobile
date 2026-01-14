class TaskModel {
  final int id;
  final int deal;
  final int? stage;
  final String notes;
  final DateTime? reminderDate;
  final int createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Serializer fields (from TaskSerializer)
  final String? dealClientName;
  final String? dealEmployeeUsername;
  final String? stageName;
  final int? dealStage;
  
  TaskModel({
    required this.id,
    required this.deal,
    this.stage,
    required this.notes,
    this.reminderDate,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.dealClientName,
    this.dealEmployeeUsername,
    this.stageName,
    this.dealStage,
  });
  
  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as int,
      deal: json['deal'] is int 
          ? json['deal'] as int 
          : (json['deal'] as Map<String, dynamic>)['id'] as int,
      stage: json['stage'] != null
          ? (json['stage'] is int 
              ? json['stage'] as int 
              : (json['stage'] as Map<String, dynamic>)['id'] as int)
          : null,
      notes: json['notes'] as String? ?? '',
      reminderDate: json['reminder_date'] != null
          ? DateTime.parse(json['reminder_date'] as String)
          : null,
      createdBy: json['created_by'] as int? ?? json['createdBy'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String? ?? json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String? ?? json['updatedAt'] as String),
      dealClientName: json['deal_client_name'] as String?,
      dealEmployeeUsername: json['deal_employee_username'] as String?,
      stageName: json['stage_name'] as String?,
      dealStage: json['deal_stage'] as int?,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deal': deal,
      'stage': stage,
      'notes': notes,
      'reminder_date': reminderDate?.toIso8601String(),
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deal_client_name': dealClientName,
      'deal_employee_username': dealEmployeeUsername,
      'stage_name': stageName,
      'deal_stage': dealStage,
    };
  }
}
