enum TimelineEntryType {
  action,
  event,
  call,
  visit,
  fieldVisit,
  locationUpdate,
  sms,
  whatsapp,
  /// Collapsed consecutive WhatsApp messages (parity with web `whatsapp_thread`).
  whatsappThread,
}

/// One line inside a collapsed WhatsApp conversation card.
class TimelineWhatsAppThreadMessage {
  final String id;
  final String direction; // inbound | outbound
  final String body;
  final String date;
  final int timestamp;
  final String user;

  const TimelineWhatsAppThreadMessage({
    required this.id,
    required this.direction,
    required this.body,
    required this.date,
    required this.timestamp,
    required this.user,
  });
}

/// Unified lead timeline row (mirrors web TimelineEntry).
class TimelineEntry {
  final String id;
  final String user;
  final String action;
  final String details;
  final String date;
  final int timestamp;
  final TimelineEntryType type;
  final String? stage;
  final String? color;
  final String? oldValue;
  final String? newValue;
  final String? fieldLabel;
  final String? callDatetime;
  final String? followUpDate;
  final String? locationPhotoUrl;
  /// Optional: PBX / WhatsApp call recording playback URL.
  final String? recordingUrl;
  final String? recordingStatus;
  /// Direction for individual WhatsApp rows (before thread collapse).
  final String? direction;
  /// Messages inside a collapsed WhatsApp conversation block.
  final List<TimelineWhatsAppThreadMessage>? messages;

  const TimelineEntry({
    required this.id,
    required this.user,
    required this.action,
    required this.details,
    required this.date,
    required this.timestamp,
    required this.type,
    this.stage,
    this.color,
    this.oldValue,
    this.newValue,
    this.fieldLabel,
    this.callDatetime,
    this.followUpDate,
    this.locationPhotoUrl,
    this.recordingUrl,
    this.recordingStatus,
    this.direction,
    this.messages,
  });
}
