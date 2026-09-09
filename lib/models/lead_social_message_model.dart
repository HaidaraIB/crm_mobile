/// One Instagram DM / Messenger message on a converted lead, for the timeline.
///
/// Deliberately narrower than [SocialMessageModel], which backs the Inbox
/// thread: the timeline renders a text line per message and has no use for
/// delivery state, reactions or attachment geometry. Mirrors the web
/// `LeadSocialMessageResponse`.
class LeadSocialMessageModel {
  final int id;

  /// A lead can hold several conversations (an Instagram DM and a Messenger
  /// thread), so the timeline groups on this rather than on adjacency alone.
  final int conversation;

  /// `instagram` | `messenger`.
  final String channel;
  final String contactName;
  final String direction;
  final String body;

  /// image/video/audio/document/location/share/story_mention/reel, or null for
  /// plain text. A media message has an empty body, so this is what stops the
  /// timeline row rendering blank.
  final String? attachmentKind;
  final bool isVoiceNote;
  final int? createdBy;
  final String? createdByUsername;

  /// Meta's own timestamp. Preferred over [createdAt], which is when the
  /// webhook reached us and drifts on a redelivery.
  final DateTime? sentAt;
  final DateTime createdAt;

  const LeadSocialMessageModel({
    required this.id,
    required this.conversation,
    required this.channel,
    required this.contactName,
    required this.direction,
    required this.body,
    this.attachmentKind,
    this.isVoiceNote = false,
    this.createdBy,
    this.createdByUsername,
    this.sentAt,
    required this.createdAt,
  });

  bool get isInbound => direction == 'inbound';

  DateTime get occurredAt => sentAt ?? createdAt;

  factory LeadSocialMessageModel.fromJson(Map<String, dynamic> json) {
    return LeadSocialMessageModel(
      id: (json['id'] as num).toInt(),
      conversation: (json['conversation'] as num?)?.toInt() ?? 0,
      channel: json['channel'] as String? ?? 'instagram',
      contactName: json['contact_name'] as String? ?? '',
      direction: json['direction'] as String? ?? 'outbound',
      body: json['body'] as String? ?? '',
      attachmentKind: json['attachment_kind'] as String?,
      isVoiceNote: json['is_voice_note'] as bool? ?? false,
      createdBy: (json['created_by'] as num?)?.toInt(),
      createdByUsername: json['created_by_username'] as String?,
      sentAt: json['sent_at'] != null
          ? DateTime.tryParse(json['sent_at'] as String)
          : null,
      createdAt: DateTime.parse(
        (json['created_at'] as String?) ?? '1970-01-01T00:00:00.000Z',
      ),
    );
  }
}
