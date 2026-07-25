class ClientEventModel {
  final int id;
  final int client;
  final String eventType;
  final String? oldValue;
  final String? newValue;
  final String? notes;
  final int? createdBy;
  final String? createdByUsername;
  final DateTime createdAt;

  ClientEventModel({
    required this.id,
    required this.client,
    required this.eventType,
    this.oldValue,
    this.newValue,
    this.notes,
    this.createdBy,
    this.createdByUsername,
    required this.createdAt,
  });

  factory ClientEventModel.fromJson(Map<String, dynamic> json) {
    return ClientEventModel(
      id: json['id'] as int,
      client: json['client'] as int,
      eventType: json['event_type'] as String? ?? '',
      oldValue: json['old_value'] as String?,
      newValue: json['new_value'] as String?,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as int?,
      createdByUsername: json['created_by_username'] as String?,
      createdAt: DateTime.parse(
        (json['created_at'] as String?) ?? '1970-01-01T00:00:00.000Z',
      ),
    );
  }
}
