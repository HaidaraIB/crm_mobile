class LeadWhatsAppMessageModel {
  final int id;
  final int client;
  final String phoneNumber;
  final String body;
  final String direction;
  final String? whatsappMessageId;
  final String? phoneNumberId;
  final String? deliveryStatus;
  final String? deliveryError;
  final bool isRead;
  final int? createdBy;
  final String? createdByUsername;
  final DateTime createdAt;
  final String? sendSource;
  /// image/video/audio/document/location, or null for plain text.
  final String? attachmentKind;
  final String? attachmentMime;
  final int? attachmentSize;
  final int? attachmentWidth;
  final int? attachmentHeight;
  final String? originalFilename;
  final String? attachmentUrl;
  final bool isVoiceNote;
  final double? locationLatitude;
  final double? locationLongitude;
  final String? locationName;
  final String? locationAddress;

  /// Local-only optimistic send: `sending` | `failed` | null (from server).
  final String? localStatus;
  /// Pending file path for resend of failed media.
  final String? localFilePath;
  final String? localCaption;

  LeadWhatsAppMessageModel({
    required this.id,
    required this.client,
    required this.phoneNumber,
    required this.body,
    required this.direction,
    this.whatsappMessageId,
    this.phoneNumberId,
    this.deliveryStatus,
    this.deliveryError,
    this.isRead = false,
    this.createdBy,
    this.createdByUsername,
    required this.createdAt,
    this.sendSource,
    this.attachmentKind,
    this.attachmentMime,
    this.attachmentSize,
    this.attachmentWidth,
    this.attachmentHeight,
    this.originalFilename,
    this.attachmentUrl,
    this.isVoiceNote = false,
    this.locationLatitude,
    this.locationLongitude,
    this.locationName,
    this.locationAddress,
    this.localStatus,
    this.localFilePath,
    this.localCaption,
  });

  bool get isInbound => direction == 'inbound';

  bool get isOptimistic => id < 0 || localStatus != null;

  bool get hasAttachment =>
      attachmentKind != null && attachmentKind!.isNotEmpty && attachmentKind != 'location';

  bool get isLocation => attachmentKind == 'location' || locationLatitude != null;

  bool get isFailed =>
      localStatus == 'failed' || (deliveryStatus ?? '').toLowerCase() == 'failed';

  bool get isSending => localStatus == 'sending';

  LeadWhatsAppMessageModel copyWith({
    int? id,
    int? client,
    String? phoneNumber,
    String? body,
    String? direction,
    String? whatsappMessageId,
    String? phoneNumberId,
    String? deliveryStatus,
    String? deliveryError,
    bool? isRead,
    int? createdBy,
    String? createdByUsername,
    DateTime? createdAt,
    String? sendSource,
    String? attachmentKind,
    String? attachmentMime,
    int? attachmentSize,
    int? attachmentWidth,
    int? attachmentHeight,
    String? originalFilename,
    String? attachmentUrl,
    bool? isVoiceNote,
    double? locationLatitude,
    double? locationLongitude,
    String? locationName,
    String? locationAddress,
    String? localStatus,
    bool clearLocalStatus = false,
    String? localFilePath,
    String? localCaption,
  }) {
    return LeadWhatsAppMessageModel(
      id: id ?? this.id,
      client: client ?? this.client,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      body: body ?? this.body,
      direction: direction ?? this.direction,
      whatsappMessageId: whatsappMessageId ?? this.whatsappMessageId,
      phoneNumberId: phoneNumberId ?? this.phoneNumberId,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      deliveryError: deliveryError ?? this.deliveryError,
      isRead: isRead ?? this.isRead,
      createdBy: createdBy ?? this.createdBy,
      createdByUsername: createdByUsername ?? this.createdByUsername,
      createdAt: createdAt ?? this.createdAt,
      sendSource: sendSource ?? this.sendSource,
      attachmentKind: attachmentKind ?? this.attachmentKind,
      attachmentMime: attachmentMime ?? this.attachmentMime,
      attachmentSize: attachmentSize ?? this.attachmentSize,
      attachmentWidth: attachmentWidth ?? this.attachmentWidth,
      attachmentHeight: attachmentHeight ?? this.attachmentHeight,
      originalFilename: originalFilename ?? this.originalFilename,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      isVoiceNote: isVoiceNote ?? this.isVoiceNote,
      locationLatitude: locationLatitude ?? this.locationLatitude,
      locationLongitude: locationLongitude ?? this.locationLongitude,
      locationName: locationName ?? this.locationName,
      locationAddress: locationAddress ?? this.locationAddress,
      localStatus: clearLocalStatus ? null : (localStatus ?? this.localStatus),
      localFilePath: localFilePath ?? this.localFilePath,
      localCaption: localCaption ?? this.localCaption,
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory LeadWhatsAppMessageModel.fromJson(Map<String, dynamic> json) {
    return LeadWhatsAppMessageModel(
      id: json['id'] as int,
      client: (json['client'] as num?)?.toInt() ?? 0,
      phoneNumber: json['phone_number'] as String? ?? '',
      body: json['body'] as String? ?? '',
      direction: json['direction'] as String? ?? 'outbound',
      whatsappMessageId: json['whatsapp_message_id'] as String?,
      phoneNumberId: json['phone_number_id'] as String?,
      deliveryStatus: json['delivery_status'] as String?,
      deliveryError: json['delivery_error'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdBy: (json['created_by'] as num?)?.toInt(),
      createdByUsername: json['created_by_username'] as String?,
      createdAt: DateTime.parse(
        (json['created_at'] as String?) ?? '1970-01-01T00:00:00.000Z',
      ),
      sendSource: json['send_source'] as String?,
      attachmentKind: json['attachment_kind'] as String?,
      attachmentMime: json['attachment_mime'] as String?,
      attachmentSize: (json['attachment_size'] as num?)?.toInt(),
      attachmentWidth: (json['attachment_width'] as num?)?.toInt(),
      attachmentHeight: (json['attachment_height'] as num?)?.toInt(),
      originalFilename: json['original_filename'] as String?,
      attachmentUrl: json['attachment_url'] as String?,
      isVoiceNote: json['is_voice_note'] as bool? ?? false,
      locationLatitude: _toDouble(json['location_latitude']),
      locationLongitude: _toDouble(json['location_longitude']),
      locationName: json['location_name'] as String?,
      locationAddress: json['location_address'] as String?,
    );
  }

  factory LeadWhatsAppMessageModel.optimisticText({
    required int localId,
    required int clientId,
    required String phone,
    required String body,
    String? username,
  }) {
    return LeadWhatsAppMessageModel(
      id: localId,
      client: clientId,
      phoneNumber: phone,
      body: body,
      direction: 'outbound',
      createdAt: DateTime.now(),
      createdByUsername: username,
      localStatus: 'sending',
      deliveryStatus: 'sending',
    );
  }

  factory LeadWhatsAppMessageModel.optimisticMedia({
    required int localId,
    required int clientId,
    required String phone,
    required String filePath,
    String? caption,
    String? kind,
    bool isVoiceNote = false,
    String? username,
  }) {
    return LeadWhatsAppMessageModel(
      id: localId,
      client: clientId,
      phoneNumber: phone,
      body: caption ?? '',
      direction: 'outbound',
      createdAt: DateTime.now(),
      createdByUsername: username,
      attachmentKind: kind ?? 'image',
      originalFilename: filePath.split('/').last.split('\\').last,
      isVoiceNote: isVoiceNote,
      localStatus: 'sending',
      localFilePath: filePath,
      localCaption: caption,
      deliveryStatus: 'sending',
    );
  }

  factory LeadWhatsAppMessageModel.optimisticLocation({
    required int localId,
    required int clientId,
    required String phone,
    required double latitude,
    required double longitude,
    String? name,
    String? address,
    String? username,
  }) {
    return LeadWhatsAppMessageModel(
      id: localId,
      client: clientId,
      phoneNumber: phone,
      body: name ?? '',
      direction: 'outbound',
      createdAt: DateTime.now(),
      createdByUsername: username,
      attachmentKind: 'location',
      locationLatitude: latitude,
      locationLongitude: longitude,
      locationName: name,
      locationAddress: address,
      localStatus: 'sending',
      deliveryStatus: 'sending',
    );
  }
}
