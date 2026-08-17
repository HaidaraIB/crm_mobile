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

/// A tag referenced from a timeline entry; [color] is null when the tag was
/// deleted after the event was logged.
class TimelineTagRef {
  final String name;
  final String? color;

  const TimelineTagRef({required this.name, this.color});
}

/// Tags added / removed by a `tags_change` event.
class TimelineTagChanges {
  final List<TimelineTagRef> added;
  final List<TimelineTagRef> removed;

  const TimelineTagChanges({required this.added, required this.removed});

  bool get isEmpty => added.isEmpty && removed.isEmpty;
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
  /// Resolved tags added/removed by a tags_change event, for colored chips.
  final TimelineTagChanges? tagChanges;
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
    this.tagChanges,
    this.callDatetime,
    this.followUpDate,
    this.locationPhotoUrl,
    this.recordingUrl,
    this.recordingStatus,
    this.direction,
    this.messages,
  });
}
