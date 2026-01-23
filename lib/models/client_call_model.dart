class ClientCallModel {
  final int id;
  final int client;
  final int? callMethod;
  final String notes;
  final DateTime? callDatetime;
  final DateTime? followUpDate;
  final int createdBy;
  final DateTime createdAt;
  
  ClientCallModel({
    required this.id,
    required this.client,
    this.callMethod,
    required this.notes,
    this.callDatetime,
    this.followUpDate,
    required this.createdBy,
    required this.createdAt,
  });
  
  factory ClientCallModel.fromJson(Map<String, dynamic> json) {
    return ClientCallModel(
      id: json['id'] as int,
      client: json['client'] as int,
      callMethod: json['call_method'] != null 
          ? (json['call_method'] is int 
              ? json['call_method'] as int 
              : (json['call_method'] as Map<String, dynamic>)['id'] as int)
          : null,
      notes: json['notes'] as String? ?? '',
      callDatetime: json['call_datetime'] != null
          ? DateTime.parse(json['call_datetime'] as String)
          : null,
      followUpDate: json['follow_up_date'] != null
          ? DateTime.parse(json['follow_up_date'] as String)
          : null,
      createdBy: json['created_by'] as int? ?? json['createdBy'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String? ?? json['createdAt'] as String),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client': client,
      'call_method': callMethod,
      'notes': notes,
      'call_datetime': callDatetime?.toIso8601String(),
      'follow_up_date': followUpDate?.toIso8601String(),
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
