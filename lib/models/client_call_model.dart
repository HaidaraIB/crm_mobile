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
  final String? whatsappDirection;
  final String? whatsappCallStatus;
  final int? whatsappDurationSec;
  final String? whatsappRecordingUrl;
  final String? whatsappRecordingStatus;
  /// Loop Cloud PBX (source == 'pbx'): typed fields, localized in the timeline.
  final String? pbxCallId;
  final String? pbxDirection;
  final String? pbxCallStatus;
  final int? pbxDurationSec;
  final String? pbxRecordingId;
  final String? pbxRecordingStatus;
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
    this.whatsappDirection,
    this.whatsappCallStatus,
    this.whatsappDurationSec,
    this.whatsappRecordingUrl,
    this.whatsappRecordingStatus,
    this.pbxCallId,
    this.pbxDirection,
    this.pbxCallStatus,
    this.pbxDurationSec,
    this.pbxRecordingId,
    this.pbxRecordingStatus,
    required this.createdBy,
    this.createdByUsername,
    required this.createdAt,
  });

  bool get isFollowUpOpen =>
      followUpDate != null && followUpCompletedAt == null;

  bool get isWhatsApp => source == 'whatsapp';

  bool get isPbx => source == 'pbx';

  String? get timelineRecordingUrl {
    if (isWhatsApp) return whatsappRecordingUrl;
    return null;
  }

  String? get timelineRecordingStatus {
    if (isWhatsApp) return whatsappRecordingStatus;
    if (isPbx) return pbxRecordingStatus;
    return null;
  }

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
      whatsappDirection: json['whatsapp_direction'] as String?,
      whatsappCallStatus: json['whatsapp_call_status'] as String?,
      whatsappDurationSec: json['whatsapp_duration_sec'] as int?,
      whatsappRecordingUrl: json['whatsapp_recording_url'] as String?,
      whatsappRecordingStatus: json['whatsapp_recording_status'] as String?,
      pbxCallId: json['pbx_call_id'] as String?,
      pbxDirection: json['pbx_direction'] as String?,
      pbxCallStatus: json['pbx_call_status'] as String?,
      pbxDurationSec: json['pbx_duration_sec'] as int?,
      pbxRecordingId: json['pbx_recording_id'] as String?,
      pbxRecordingStatus: json['pbx_recording_status'] as String?,
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
      'whatsapp_direction': whatsappDirection,
      'whatsapp_call_status': whatsappCallStatus,
      'whatsapp_duration_sec': whatsappDurationSec,
      'whatsapp_recording_url': whatsappRecordingUrl,
      'whatsapp_recording_status': whatsappRecordingStatus,
      'pbx_call_id': pbxCallId,
      'pbx_direction': pbxDirection,
      'pbx_call_status': pbxCallStatus,
      'pbx_duration_sec': pbxDurationSec,
      'pbx_recording_id': pbxRecordingId,
      'pbx_recording_status': pbxRecordingStatus,
      'created_by': createdBy,
      'created_by_username': createdByUsername,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
