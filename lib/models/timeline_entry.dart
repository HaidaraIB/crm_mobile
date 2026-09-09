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
  /// One Instagram DM / Messenger message (parity with web `social`).
  social,
  /// Collapsed consecutive social messages (parity with web `social_thread`).
  socialThread,
}

/// Instagram Direct / Facebook Messenger.
enum TimelineSocialChannel { instagram, messenger }

/// One line inside a collapsed WhatsApp or social conversation card.
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
  /// User-supplied justification, e.g. why a lead was moved into this status.
  final String? reason;
  final String? fieldLabel;
  /// Resolved tags added/removed by a tags_change event, for colored chips.
  final TimelineTagChanges? tagChanges;
  final String? callDatetime;
  final String? followUpDate;
  final String? locationPhotoUrl;
  /// Optional: PBX / WhatsApp call recording playback URL.
  final String? recordingUrl;
  final String? recordingStatus;
  /// Direction for individual WhatsApp / social rows (before thread collapse).
  final String? direction;
  /// Messages inside a collapsed WhatsApp or social conversation block.
  final List<TimelineWhatsAppThreadMessage>? messages;
  /// Which network a [TimelineEntryType.social] row came from.
  final TimelineSocialChannel? socialChannel;
  /// Conversation this social row belongs to. A lead can hold an Instagram DM
  /// and a Messenger thread at once, so this — not adjacency alone — decides
  /// which rows collapse together.
  final int? socialConversationId;

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
    this.reason,
    this.fieldLabel,
    this.tagChanges,
    this.callDatetime,
    this.followUpDate,
    this.locationPhotoUrl,
    this.recordingUrl,
    this.recordingStatus,
    this.direction,
    this.messages,
    this.socialChannel,
    this.socialConversationId,
  });
}
