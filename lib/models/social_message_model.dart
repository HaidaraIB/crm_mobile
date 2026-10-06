// One message in an Omni-Channel Inbox thread (Instagram DM / Messenger).
//
// Field set mirrors `SocialMessage` in the backend, which in turn mirrors
// LeadWhatsAppMessage so media rendering stays consistent across both inboxes.

import 'lead_whatsapp_message_model.dart';

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
  final int? attachmentWidth;
  final int? attachmentHeight;
  final String originalFilename;
  final bool hasAttachment;
  final bool isVoiceNote;
  final String locationName;
  final String? locationAddress;
  final double? locationLatitude;
  final double? locationLongitude;
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
    this.attachmentWidth,
    this.attachmentHeight,
    this.originalFilename = '',
    this.hasAttachment = false,
    this.isVoiceNote = false,
    this.locationName = '',
    this.locationAddress,
    this.locationLatitude,
    this.locationLongitude,
    this.createdByUsername,
    this.sentAt,
    this.createdAt,
    this.tempId,
  });

  static DateTime? _date(dynamic value) =>
      value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;

  static double? _coord(dynamic value) {
    if (value == null || value == '') return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

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
      attachmentWidth: (json['attachment_width'] as num?)?.toInt(),
      attachmentHeight: (json['attachment_height'] as num?)?.toInt(),
      originalFilename: json['original_filename'] as String? ?? '',
      hasAttachment: json['has_attachment'] as bool? ?? false,
      isVoiceNote: json['is_voice_note'] as bool? ?? false,
      locationName: json['location_name'] as String? ?? '',
      locationAddress: json['location_address'] as String?,
      locationLatitude: _coord(json['location_latitude']),
      locationLongitude: _coord(json['location_longitude']),
      createdByUsername: json['created_by_username'] as String?,
      sentAt: _date(json['sent_at']),
      createdAt: _date(json['created_at']),
    );
  }

  bool get isOutbound => direction == 'outbound';
  bool get isFailed => deliveryStatus == 'failed';
  bool get isPending => deliveryStatus == 'pending' || tempId != null;

  DateTime get timestamp => sentAt ?? createdAt ?? DateTime.now();

  /// Maps inbox payloads into the shared WhatsApp bubble renderer.
  LeadWhatsAppMessageModel toBubbleModel(String Function(int messageId) attachmentUrl) {
    final lat = locationLatitude;
    final lng = locationLongitude;
    final hasCoords = lat != null && lng != null;
    String? kind = attachmentKind;
    if (hasCoords) {
      kind = 'location';
    } else if (hasAttachment && kind != null && kind.isNotEmpty) {
      // keep blob kind
    } else if (!hasAttachment && kind != null && kind.isNotEmpty) {
      // story_mention / share / reel — placeholder only
    } else {
      kind = null;
    }

    String? url;
    if (hasAttachment &&
        id > 0 &&
        kind != null &&
        kind != 'location' &&
        !kind.startsWith('story') &&
        kind != 'share' &&
        kind != 'reel') {
      url = attachmentUrl(id);
    }

    return LeadWhatsAppMessageModel(
      id: id,
      client: 0,
      phoneNumber: '',
      body: body,
      direction: direction,
      deliveryStatus: deliveryStatus,
      deliveryError: deliveryError,
      createdByUsername: createdByUsername,
      createdAt: timestamp,
      attachmentKind: kind,
      attachmentMime: attachmentMime,
      attachmentSize: attachmentSize,
      attachmentWidth: attachmentWidth,
      attachmentHeight: attachmentHeight,
      originalFilename: originalFilename.isNotEmpty ? originalFilename : null,
      attachmentUrl: url,
      isVoiceNote: isVoiceNote,
      locationLatitude: lat,
      locationLongitude: lng,
      locationName: locationName.isNotEmpty ? locationName : null,
      locationAddress: locationAddress?.isNotEmpty == true ? locationAddress : null,
      localStatus: isPending ? 'sending' : null,
    );
  }

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
      attachmentWidth: attachmentWidth,
      attachmentHeight: attachmentHeight,
      originalFilename: originalFilename,
      hasAttachment: hasAttachment,
      isVoiceNote: isVoiceNote,
      locationName: locationName,
      locationAddress: locationAddress,
      locationLatitude: locationLatitude,
      locationLongitude: locationLongitude,
      createdByUsername: createdByUsername,
      sentAt: sentAt,
      createdAt: createdAt,
      tempId: tempId ?? this.tempId,
    );
  }
}
