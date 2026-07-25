class LeadSmsMessageModel {
  final int id;
  final int client;
  final String phoneNumber;
  final String body;
  final String direction;
  final int? createdBy;
  final String? createdByUsername;
  final DateTime createdAt;

  LeadSmsMessageModel({
    required this.id,
    required this.client,
    required this.phoneNumber,
    required this.body,
    required this.direction,
    this.createdBy,
    this.createdByUsername,
    required this.createdAt,
  });

  factory LeadSmsMessageModel.fromJson(Map<String, dynamic> json) {
    return LeadSmsMessageModel(
      id: json['id'] as int,
      client: json['client'] as int,
      phoneNumber: json['phone_number'] as String? ?? '',
      body: json['body'] as String? ?? '',
      direction: json['direction'] as String? ?? 'outbound',
      createdBy: json['created_by'] as int?,
      createdByUsername: json['created_by_username'] as String?,
      createdAt: DateTime.parse(
        (json['created_at'] as String?) ?? '1970-01-01T00:00:00.000Z',
      ),
    );
  }
}
