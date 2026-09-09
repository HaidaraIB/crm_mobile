// One message in an Omni-Channel Inbox thread (Instagram DM / Messenger).
//
// Field set mirrors `SocialMessage` in the backend, which in turn mirrors
// LeadWhatsAppMessage so media rendering stays consistent across both inboxes.

class SocialMessageModel {
  final int id;
  final String direction;
  final String body;
  final String externalMessageId;

  /// True when the business replied from the native Instagram/Messenger app.
  /// Rendered as outbound but without an agent name.
  final bool isEcho;
  final bool isRead;
  final String reaction;
  final String? deliveryStatus;
  final String? deliveryError;
  final String errorKey;
  final String? attachmentKind;
  final String attachmentMime;
  final int? attachmentSize;
  final String originalFilename;
  final bool hasAttachment;
  final bool isVoiceNote;
  final String locationName;
  final String? createdByUsername;
  final DateTime? sentAt;
  final DateTime? createdAt;

  /// Client-side only: set on an optimistic bubble before the server replies.
  final String? tempId;

  const SocialMessageModel({
    required this.id,
    this.direction = 'inbound',
    this.body = '',
    this.externalMessageId = '',
    this.isEcho = false,
    this.isRead = true,
    this.reaction = '',
    this.deliveryStatus,
    this.deliveryError,
    this.errorKey = '',
    this.attachmentKind,
    this.attachmentMime = '',
    this.attachmentSize,
    this.originalFilename = '',
    this.hasAttachment = false,
    this.isVoiceNote = false,
    this.locationName = '',
    this.createdByUsername,
    this.sentAt,
    this.createdAt,
    this.tempId,
  });

  static DateTime? _date(dynamic value) =>
      value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;

  factory SocialMessageModel.fromJson(Map<String, dynamic> json) {
    return SocialMessageModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      direction: json['direction'] as String? ?? 'inbound',
      body: json['body'] as String? ?? '',
      externalMessageId: json['external_message_id'] as String? ?? '',
      isEcho: json['is_echo'] as bool? ?? false,
      isRead: json['is_read'] as bool? ?? true,
      reaction: json['reaction'] as String? ?? '',
      deliveryStatus: json['delivery_status'] as String?,
      deliveryError: json['delivery_error'] as String?,
      errorKey: json['error_key'] as String? ?? '',
      attachmentKind: json['attachment_kind'] as String?,
      attachmentMime: json['attachment_mime'] as String? ?? '',
      attachmentSize: (json['attachment_size'] as num?)?.toInt(),
      originalFilename: json['original_filename'] as String? ?? '',
      hasAttachment: json['has_attachment'] as bool? ?? false,
      isVoiceNote: json['is_voice_note'] as bool? ?? false,
      locationName: json['location_name'] as String? ?? '',
      createdByUsername: json['created_by_username'] as String?,
      sentAt: _date(json['sent_at']),
      createdAt: _date(json['created_at']),
    );
  }

  bool get isOutbound => direction == 'outbound';
  bool get isFailed => deliveryStatus == 'failed';
  bool get isPending => deliveryStatus == 'pending' || tempId != null;

  DateTime get timestamp => sentAt ?? createdAt ?? DateTime.now();

  SocialMessageModel copyWith({
    int? id,
    String? deliveryStatus,
    String? deliveryError,
    String? errorKey,
    String? externalMessageId,
    String? reaction,
    bool? isRead,
    String? tempId,
  }) {
    return SocialMessageModel(
      id: id ?? this.id,
      direction: direction,
      body: body,
      externalMessageId: externalMessageId ?? this.externalMessageId,
      isEcho: isEcho,
      isRead: isRead ?? this.isRead,
      reaction: reaction ?? this.reaction,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      deliveryError: deliveryError ?? this.deliveryError,
      errorKey: errorKey ?? this.errorKey,
      attachmentKind: attachmentKind,
      attachmentMime: attachmentMime,
      attachmentSize: attachmentSize,
      originalFilename: originalFilename,
      hasAttachment: hasAttachment,
      isVoiceNote: isVoiceNote,
      locationName: locationName,
      createdByUsername: createdByUsername,
      sentAt: sentAt,
      createdAt: createdAt,
      tempId: tempId ?? this.tempId,
    );
  }
}
