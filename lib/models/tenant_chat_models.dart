// Tenant internal chat (same-company DMs + company group) — mirrors CRM-project services/api.ts types.

const String kTenantChatKindDirect = 'direct';
const String kTenantChatKindCompanyGroup = 'company_group';

class TenantChatPeer {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final String? profilePhoto;
  final String? lastSeenAt;
  final String? lastSeenSource;
  final bool? isOnline;

  TenantChatPeer({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.profilePhoto,
    this.lastSeenAt,
    this.lastSeenSource,
    this.isOnline,
  });

  factory TenantChatPeer.fromJson(Map<String, dynamic> json) {
    return TenantChatPeer(
      id: (json['id'] as num?)?.toInt() ?? 0,
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      profilePhoto: json['profile_photo']?.toString(),
      lastSeenAt: json['last_seen_at']?.toString(),
      lastSeenSource: json['last_seen_source']?.toString(),
      isOnline: json['is_online'] as bool?,
    );
  }
}

class TenantChatMessageQuote {
  final int id;
  final TenantChatPeer sender;
  final String body;
  final String createdAt;
  final String? attachmentKind;
  final String? attachmentUrl;

  TenantChatMessageQuote({
    required this.id,
    required this.sender,
    required this.body,
    required this.createdAt,
    this.attachmentKind,
    this.attachmentUrl,
  });

  factory TenantChatMessageQuote.fromJson(Map<String, dynamic> json) {
    return TenantChatMessageQuote(
      id: (json['id'] as num?)?.toInt() ?? 0,
      sender: TenantChatPeer.fromJson(
        Map<String, dynamic>.from(json['sender'] as Map? ?? {}),
      ),
      body: json['body']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      attachmentKind: json['attachment_kind']?.toString(),
      attachmentUrl: json['attachment_url']?.toString(),
    );
  }
}

class TenantChatPinnedMessageSummary {
  final int pinId;
  final int messageId;
  final String body;
  final TenantChatPeer sender;
  final String pinnedAt;
  final int pinnedById;
  final String? attachmentKind;

  TenantChatPinnedMessageSummary({
    required this.pinId,
    required this.messageId,
    required this.body,
    required this.sender,
    required this.pinnedAt,
    required this.pinnedById,
    this.attachmentKind,
  });

  factory TenantChatPinnedMessageSummary.fromJson(Map<String, dynamic> json) {
    return TenantChatPinnedMessageSummary(
      pinId: (json['pin_id'] as num?)?.toInt() ?? 0,
      messageId: (json['message_id'] as num?)?.toInt() ?? 0,
      body: json['body']?.toString() ?? '',
      sender: TenantChatPeer.fromJson(
        Map<String, dynamic>.from(json['sender'] as Map? ?? {}),
      ),
      pinnedAt: json['pinned_at']?.toString() ?? '',
      pinnedById: (json['pinned_by_id'] as num?)?.toInt() ?? 0,
      attachmentKind: json['attachment_kind']?.toString(),
    );
  }
}

class TenantChatLastMessage {
  final int id;
  final String body;
  final String createdAt;
  final int senderId;
  final String? attachmentKind;

  TenantChatLastMessage({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.senderId,
    this.attachmentKind,
  });

  factory TenantChatLastMessage.fromJson(Map<String, dynamic> json) {
    return TenantChatLastMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      body: json['body']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      senderId: (json['sender_id'] as num?)?.toInt() ?? 0,
      attachmentKind: json['attachment_kind']?.toString(),
    );
  }
}

class TenantChatConversation {
  final int id;
  final String kind;
  final TenantChatPeer? otherUser;
  final String? groupTitle;
  final int? memberCount;
  final int? onlineCount;
  final TenantChatLastMessage? lastMessage;
  final String updatedAt;
  final int unreadCount;
  final int? lastReadMessageId;
  final List<TenantChatPinnedMessageSummary> pinnedMessages;

  TenantChatConversation({
    required this.id,
    this.kind = kTenantChatKindDirect,
    this.otherUser,
    this.groupTitle,
    this.memberCount,
    this.onlineCount,
    this.lastMessage,
    required this.updatedAt,
    this.unreadCount = 0,
    this.lastReadMessageId,
    this.pinnedMessages = const [],
  });

  bool get isCompanyGroup => kind == kTenantChatKindCompanyGroup;

  factory TenantChatConversation.fromJson(Map<String, dynamic> json) {
    final pins = json['pinned_messages'];
    final kind = json['kind']?.toString() ?? kTenantChatKindDirect;
    final ou = json['other_user'];
    TenantChatPeer? otherUser;
    if (ou is Map<String, dynamic>) {
      otherUser = TenantChatPeer.fromJson(Map<String, dynamic>.from(ou));
    } else if (ou is Map) {
      otherUser = TenantChatPeer.fromJson(Map<String, dynamic>.from(ou));
    }
    return TenantChatConversation(
      id: (json['id'] as num?)?.toInt() ?? 0,
      kind: kind,
      otherUser: otherUser,
      groupTitle: json['group_title']?.toString(),
      memberCount: (json['member_count'] as num?)?.toInt(),
      onlineCount: (json['online_count'] as num?)?.toInt(),
      lastMessage: json['last_message'] != null
          ? TenantChatLastMessage.fromJson(
              Map<String, dynamic>.from(json['last_message'] as Map),
            )
          : null,
      updatedAt: json['updated_at']?.toString() ?? '',
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      lastReadMessageId: (json['last_read_message_id'] as num?)?.toInt(),
      pinnedMessages: pins is List
          ? pins
              .map((e) => TenantChatPinnedMessageSummary.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList()
          : const [],
    );
  }
}

class TenantChatMessage {
  final int id;
  final TenantChatPeer sender;
  final String body;
  final String createdAt;
  final bool readByPeer;
  final TenantChatMessageQuote? replyTo;
  final TenantChatMessageQuote? forwardedFrom;
  final String? attachmentKind;
  final String? attachmentMime;
  final int? attachmentSize;
  final int? attachmentWidth;
  final int? attachmentHeight;
  final String? originalFilename;
  final String? attachmentUrl;

  TenantChatMessage({
    required this.id,
    required this.sender,
    required this.body,
    required this.createdAt,
    this.readByPeer = false,
    this.replyTo,
    this.forwardedFrom,
    this.attachmentKind,
    this.attachmentMime,
    this.attachmentSize,
    this.attachmentWidth,
    this.attachmentHeight,
    this.originalFilename,
    this.attachmentUrl,
  });

  factory TenantChatMessage.fromJson(Map<String, dynamic> json) {
    return TenantChatMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      sender: TenantChatPeer.fromJson(
        Map<String, dynamic>.from(json['sender'] as Map? ?? {}),
      ),
      body: json['body']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      readByPeer: json['read_by_peer'] as bool? ?? false,
      replyTo: json['reply_to'] != null
          ? TenantChatMessageQuote.fromJson(
              Map<String, dynamic>.from(json['reply_to'] as Map),
            )
          : null,
      forwardedFrom: json['forwarded_from'] != null
          ? TenantChatMessageQuote.fromJson(
              Map<String, dynamic>.from(json['forwarded_from'] as Map),
            )
          : null,
      attachmentKind: json['attachment_kind']?.toString(),
      attachmentMime: json['attachment_mime']?.toString(),
      attachmentSize: (json['attachment_size'] as num?)?.toInt(),
      attachmentWidth: (json['attachment_width'] as num?)?.toInt(),
      attachmentHeight: (json['attachment_height'] as num?)?.toInt(),
      originalFilename: json['original_filename']?.toString(),
      attachmentUrl: json['attachment_url']?.toString(),
    );
  }
}

typedef TenantChatPeerPresenceAction = String;

const String kTenantChatPresenceIdle = 'idle';
const String kTenantChatPresenceTyping = 'typing';
const String kTenantChatPresenceUploading = 'uploading_media';
const String kTenantChatPresenceRecording = 'recording_voice';
const String kTenantChatPresenceSending = 'sending_message';

class TenantChatGroupPresencePeer {
  final int userId;
  final String activity;
  final TenantChatPeer peer;

  const TenantChatGroupPresencePeer({
    required this.userId,
    required this.activity,
    required this.peer,
  });

  factory TenantChatGroupPresencePeer.fromJson(Map<String, dynamic> json) {
    return TenantChatGroupPresencePeer(
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      activity: json['activity']?.toString() ?? kTenantChatPresenceIdle,
      peer: TenantChatPeer.fromJson(
        Map<String, dynamic>.from(json['peer'] as Map? ?? {}),
      ),
    );
  }
}

class TenantChatPeerPresenceResponse {
  final bool isGroupMode;
  final int peerUserId;
  final String? activity;
  final List<TenantChatGroupPresencePeer> groupPeers;

  const TenantChatPeerPresenceResponse({
    this.isGroupMode = false,
    this.peerUserId = 0,
    this.activity,
    this.groupPeers = const [],
  });

  factory TenantChatPeerPresenceResponse.fromJson(Map<String, dynamic> json) {
    if (json['mode']?.toString() == 'group') {
      final raw = json['peers'];
      final list = <TenantChatGroupPresencePeer>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map) {
            list.add(TenantChatGroupPresencePeer.fromJson(
              Map<String, dynamic>.from(e),
            ));
          }
        }
      }
      return TenantChatPeerPresenceResponse(
        isGroupMode: true,
        groupPeers: list,
      );
    }
    return TenantChatPeerPresenceResponse(
      isGroupMode: false,
      peerUserId: (json['peer_user_id'] as num?)?.toInt() ?? 0,
      activity: json['activity']?.toString(),
    );
  }
}

class TenantChatConversationsPage {
  final int count;
  final String? next;
  final String? previous;
  final List<TenantChatConversation> results;

  const TenantChatConversationsPage({
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });
}

class TenantChatPeersPage {
  final int count;
  final List<TenantChatPeer> results;

  const TenantChatPeersPage({
    required this.count,
    required this.results,
  });
}

class TenantChatMessagesPage {
  final int count;
  final List<TenantChatMessage> results;

  const TenantChatMessagesPage({
    required this.count,
    required this.results,
  });
}
