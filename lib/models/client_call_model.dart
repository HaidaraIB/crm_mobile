class ClientCallModel {
  final int id;
  final int client;
  final int? callMethod;
  final String? callMethodName;
  final String notes;
  final DateTime? callDatetime;
  final DateTime? followUpDate;
  final DateTime? followUpCompletedAt;
  final String? source;
  final String? pbxDirection;
  final String? pbxDisposition;
  final int? pbxDurationSec;
  final int createdBy;
  final String? createdByUsername;
  final DateTime createdAt;

  ClientCallModel({
    required this.id,
    required this.client,
    this.callMethod,
    this.callMethodName,
    required this.notes,
    this.callDatetime,
    this.followUpDate,
    this.followUpCompletedAt,
    this.source,
    this.pbxDirection,
    this.pbxDisposition,
    this.pbxDurationSec,
    required this.createdBy,
    this.createdByUsername,
    required this.createdAt,
  });

  bool get isFollowUpOpen =>
      followUpDate != null && followUpCompletedAt == null;

  bool get isPbx => source == 'pbx';

  factory ClientCallModel.fromJson(Map<String, dynamic> json) {
    return ClientCallModel(
      id: json['id'] as int,
      client: json['client'] as int,
      callMethod: json['call_method'] != null
          ? (json['call_method'] is int
                ? json['call_method'] as int
                : (json['call_method'] as Map<String, dynamic>)['id'] as int)
          : null,
      callMethodName: json['call_method_name'] as String?,
      notes: json['notes'] as String? ?? '',
      callDatetime: json['call_datetime'] != null
          ? DateTime.parse(json['call_datetime'] as String)
          : null,
      followUpDate: json['follow_up_date'] != null
          ? DateTime.parse(json['follow_up_date'] as String)
          : null,
      followUpCompletedAt: json['follow_up_completed_at'] != null
          ? DateTime.parse(json['follow_up_completed_at'] as String)
          : null,
      source: json['source'] as String?,
      pbxDirection: json['pbx_direction'] as String?,
      pbxDisposition: json['pbx_disposition'] as String?,
      pbxDurationSec: json['pbx_duration_sec'] as int?,
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
      'call_method': callMethod,
      'call_method_name': callMethodName,
      'notes': notes,
      'call_datetime': callDatetime?.toIso8601String(),
      'follow_up_date': followUpDate?.toIso8601String(),
      'follow_up_completed_at': followUpCompletedAt?.toIso8601String(),
      'source': source,
      'pbx_direction': pbxDirection,
      'pbx_disposition': pbxDisposition,
      'pbx_duration_sec': pbxDurationSec,
      'created_by': createdBy,
      'created_by_username': createdByUsername,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
