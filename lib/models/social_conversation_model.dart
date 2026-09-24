// Omni-Channel Inbox models — Instagram Direct + Facebook Messenger.
//
// Unlike WhatsApp, a conversation here is its own row rather than a lead:
// `clientId` stays null until an agent converts it. Mirrors the backend
// serializers in `integrations/views/social_inbox.py`.

class SocialContactModel {
  final int id;
  final String externalId;
  final String name;
  final String username;
  final String displayName;
  final String profilePicUrl;

  const SocialContactModel({
    required this.id,
    this.externalId = '',
    this.name = '',
    this.username = '',
    this.displayName = '',
    this.profilePicUrl = '',
  });

  factory SocialContactModel.fromJson(Map<String, dynamic> json) {
    return SocialContactModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      externalId: json['external_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      profilePicUrl: json['profile_pic_url'] as String? ?? '',
    );
  }

  String get label =>
      displayName.isNotEmpty ? displayName : (name.isNotEmpty ? name : username);
}

class SocialConversationModel {
  final int id;
  final String channel;
  final String status;
  final bool isStarred;
  final bool isUnsubscribed;
  final DateTime? snoozedUntil;
  final int unreadCount;
  final DateTime? lastMessageAt;
  final String lastMessageDirection;
  final String lastMessagePreview;
  final DateTime? lastInboundAt;
  final SocialContactModel contact;
  final String pageName;
  final String igUsername;
  final int? assignedToId;
  final String assignedToName;

  /// Non-null once converted — drives the "lead" chip and disables convert.
  final int? clientId;
  final String clientName;
  final DateTime? convertedAt;

  const SocialConversationModel({
    required this.id,
    required this.contact,
    this.channel = 'instagram',
    this.status = 'open',
    this.isStarred = false,
    this.isUnsubscribed = false,
    this.snoozedUntil,
    this.unreadCount = 0,
    this.lastMessageAt,
    this.lastMessageDirection = '',
    this.lastMessagePreview = '',
    this.lastInboundAt,
    this.pageName = '',
    this.igUsername = '',
    this.assignedToId,
    this.assignedToName = '',
    this.clientId,
    this.clientName = '',
    this.convertedAt,
  });

  static DateTime? _date(dynamic value) =>
      value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;

  factory SocialConversationModel.fromJson(Map<String, dynamic> json) {
    final connection = json['connection'] as Map<String, dynamic>? ?? const {};
    final assigned = json['assigned_to'] as Map<String, dynamic>?;
    final client = json['client'] as Map<String, dynamic>?;
    return SocialConversationModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      channel: json['channel'] as String? ?? 'instagram',
      status: json['status'] as String? ?? 'open',
      isStarred: json['is_starred'] as bool? ?? false,
      isUnsubscribed: json['is_unsubscribed'] as bool? ?? false,
      snoozedUntil: _date(json['snoozed_until']),
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      lastMessageAt: _date(json['last_message_at']),
      lastMessageDirection: json['last_message_direction'] as String? ?? '',
      lastMessagePreview: json['last_message_preview'] as String? ?? '',
      lastInboundAt: _date(json['last_inbound_at']),
      contact: SocialContactModel.fromJson(
        json['contact'] as Map<String, dynamic>? ?? const {},
      ),
      pageName: connection['page_name'] as String? ?? '',
      igUsername: connection['ig_username'] as String? ?? '',
      assignedToId: (assigned?['id'] as num?)?.toInt(),
      assignedToName: assigned?['full_name'] as String? ?? '',
      clientId: (client?['id'] as num?)?.toInt(),
      clientName: client?['name'] as String? ?? '',
      convertedAt: _date(json['converted_at']),
    );
  }

  bool get isConverted => clientId != null;
  bool get isInstagram => channel == 'instagram';
  bool get isWhatsapp => channel == 'whatsapp';

  SocialConversationModel copyWith({
    String? status,
    bool? isStarred,
    bool? isUnsubscribed,
    DateTime? snoozedUntil,
    bool clearSnoozedUntil = false,
    int? unreadCount,
    DateTime? lastMessageAt,
    String? lastMessageDirection,
    String? lastMessagePreview,
    DateTime? lastInboundAt,
    int? clientId,
    String? clientName,
  }) {
    return SocialConversationModel(
      id: id,
      contact: contact,
      channel: channel,
      status: status ?? this.status,
      isStarred: isStarred ?? this.isStarred,
      isUnsubscribed: isUnsubscribed ?? this.isUnsubscribed,
      snoozedUntil: clearSnoozedUntil
          ? null
          : (snoozedUntil ?? this.snoozedUntil),
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageDirection: lastMessageDirection ?? this.lastMessageDirection,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastInboundAt: lastInboundAt ?? this.lastInboundAt,
      pageName: pageName,
      igUsername: igUsername,
      assignedToId: assignedToId,
      assignedToName: assignedToName,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      convertedAt: convertedAt,
    );
  }
}

class SocialConversationsPage {
  final List<SocialConversationModel> results;
  final int count;
  final Map<String, int> statusCounts;
  final Map<String, int> assignmentCounts;

  const SocialConversationsPage({
    this.results = const [],
    this.count = 0,
    this.statusCounts = const {},
    this.assignmentCounts = const {},
  });

  static Map<String, int> _counts(dynamic raw) {
    if (raw is! Map) return const {};
    return raw.map(
      (key, value) => MapEntry('$key', (value as num?)?.toInt() ?? 0),
    );
  }

  factory SocialConversationsPage.fromJson(Map<String, dynamic> json) {
    final rows = json['results'] as List<dynamic>? ?? const [];
    return SocialConversationsPage(
      results: rows
          .whereType<Map<String, dynamic>>()
          .map(SocialConversationModel.fromJson)
          .toList(),
      count: (json['count'] as num?)?.toInt() ?? 0,
      statusCounts: _counts(json['status_counts']),
      assignmentCounts: _counts(json['assignment_counts']),
    );
  }
}

/// Reply-window state. Instagram/Messenger have no template escape hatch, so a
/// closed window means the composer must be disabled outright.
class SocialSendWindow {
  final bool open;

  /// `response` (within 24h), `human_agent` (24h-7d, feature-gated), `closed`.
  final String mode;
  final DateTime? lastInboundAt;
  final DateTime? expiresAt;
  final bool humanAgentAvailable;
  final bool requiresTemplate;

  const SocialSendWindow({
    this.open = false,
    this.mode = 'closed',
    this.lastInboundAt,
    this.expiresAt,
    this.humanAgentAvailable = false,
    this.requiresTemplate = false,
  });

  factory SocialSendWindow.fromJson(Map<String, dynamic> json) {
    return SocialSendWindow(
      open: json['open'] as bool? ?? false,
      mode: json['mode'] as String? ?? 'closed',
      lastInboundAt: SocialConversationModel._date(json['last_inbound_at']),
      expiresAt: SocialConversationModel._date(json['expires_at']),
      humanAgentAvailable: json['human_agent_available'] as bool? ?? false,
      requiresTemplate: json['requires_template'] as bool? ?? false,
    );
  }

  Duration? get remaining {
    final expiry = expiresAt;
    if (expiry == null) return null;
    final left = expiry.difference(DateTime.now());
    return left.isNegative ? null : left;
  }
}
