/// One row of `GET whatsapp/conversations/` (integrations app) — a client with a WhatsApp thread.
class WhatsAppConversationModel {
  final int id;
  final String name;
  final String phoneNumber;
  final String leadCompanyName;
  final DateTime? lastMessageAt;
  final String lastMessagePreview;
  final String lastMessageDirection;
  final int? assignedToId;
  final int unreadCount;
  final String status;
  final DateTime? snoozedUntil;
  final bool isStarred;
  final bool isUnsubscribed;

  WhatsAppConversationModel({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.leadCompanyName = '',
    this.lastMessageAt,
    this.lastMessagePreview = '',
    this.lastMessageDirection = '',
    this.assignedToId,
    this.unreadCount = 0,
    this.status = 'open',
    this.snoozedUntil,
    this.isStarred = false,
    this.isUnsubscribed = false,
  });

  factory WhatsAppConversationModel.fromJson(Map<String, dynamic> json) {
    return WhatsAppConversationModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      leadCompanyName: json['lead_company_name'] as String? ?? '',
      lastMessageAt: (json['last_message_at'] as String?) != null
          ? DateTime.tryParse(json['last_message_at'] as String)
          : null,
      lastMessagePreview: json['last_message_preview'] as String? ?? '',
      lastMessageDirection: json['last_message_direction'] as String? ?? '',
      assignedToId: (json['assigned_to_id'] as num?)?.toInt(),
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'open',
      snoozedUntil: (json['snoozed_until'] as String?) != null
          ? DateTime.tryParse(json['snoozed_until'] as String)
          : null,
      isStarred: json['is_starred'] as bool? ?? false,
      isUnsubscribed: json['is_unsubscribed'] as bool? ?? false,
    );
  }

  WhatsAppConversationModel copyWith({
    int? id,
    String? name,
    String? phoneNumber,
    String? leadCompanyName,
    DateTime? lastMessageAt,
    String? lastMessagePreview,
    String? lastMessageDirection,
    int? assignedToId,
    int? unreadCount,
    String? status,
    DateTime? snoozedUntil,
    bool? isStarred,
    bool? isUnsubscribed,
    bool clearSnoozedUntil = false,
  }) {
    return WhatsAppConversationModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      leadCompanyName: leadCompanyName ?? this.leadCompanyName,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastMessageDirection: lastMessageDirection ?? this.lastMessageDirection,
      assignedToId: assignedToId ?? this.assignedToId,
      unreadCount: unreadCount ?? this.unreadCount,
      status: status ?? this.status,
      snoozedUntil:
          clearSnoozedUntil ? null : (snoozedUntil ?? this.snoozedUntil),
      isStarred: isStarred ?? this.isStarred,
      isUnsubscribed: isUnsubscribed ?? this.isUnsubscribed,
    );
  }
}

/// Envelope from the filterable conversations list.
class WhatsAppConversationsPage {
  final int count;
  final List<WhatsAppConversationModel> results;
  final Map<String, int> statusCounts;
  final Map<String, int> assignmentCounts;

  const WhatsAppConversationsPage({
    required this.count,
    required this.results,
    this.statusCounts = const {},
    this.assignmentCounts = const {},
  });
}

/// `GET whatsapp/session-window/` — WhatsApp 24h customer-service window status.
class WhatsAppSessionWindow {
  final bool inSession;
  final DateTime? lastInboundAt;
  final DateTime? sessionExpiresAt;
  final double? hoursRemaining;

  const WhatsAppSessionWindow({
    required this.inSession,
    this.lastInboundAt,
    this.sessionExpiresAt,
    this.hoursRemaining,
  });

  factory WhatsAppSessionWindow.fromJson(Map<String, dynamic> json) {
    return WhatsAppSessionWindow(
      inSession: json['in_session'] as bool? ?? false,
      lastInboundAt: (json['last_inbound_at'] as String?) != null
          ? DateTime.tryParse(json['last_inbound_at'] as String)
          : null,
      sessionExpiresAt: (json['session_expires_at'] as String?) != null
          ? DateTime.tryParse(json['session_expires_at'] as String)
          : null,
      hoursRemaining: (json['hours_remaining'] as num?)?.toDouble(),
    );
  }

  static const closed = WhatsAppSessionWindow(inSession: false);
}
