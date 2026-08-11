/// One row of `GET whatsapp/conversations/` (integrations app) — a client with a WhatsApp thread.
class WhatsAppConversationModel {
  final int id;
  final String name;
  final String phoneNumber;
  final String leadCompanyName;
  final DateTime? lastMessageAt;
  final String lastMessagePreview;
  final int? assignedToId;
  final int unreadCount;

  WhatsAppConversationModel({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.leadCompanyName = '',
    this.lastMessageAt,
    this.lastMessagePreview = '',
    this.assignedToId,
    this.unreadCount = 0,
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
      assignedToId: (json['assigned_to_id'] as num?)?.toInt(),
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    );
  }
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
