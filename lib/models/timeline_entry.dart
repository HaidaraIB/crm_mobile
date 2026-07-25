enum TimelineEntryType {
  action,
  event,
  call,
  visit,
  fieldVisit,
  locationUpdate,
  sms,
  whatsapp,
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
  final String? recordingUrl;
  final String? recordingStatus;

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
  });
}
