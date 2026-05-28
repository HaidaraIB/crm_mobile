import '../../models/tenant_chat_models.dart';

bool tenantPinnedSummariesEqual(
  List<TenantChatPinnedMessageSummary> a,
  List<TenantChatPinnedMessageSummary> b,
) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final x = a[i], y = b[i];
    if (x.pinId != y.pinId ||
        x.messageId != y.messageId ||
        x.body != y.body ||
        x.attachmentKind != y.attachmentKind) {
      return false;
    }
  }
  return true;
}

bool tenantConversationTilePayloadEqual(
  TenantChatConversation a,
  TenantChatConversation b,
) {
  if (a.id != b.id) return false;
  if (a.kind != b.kind) return false;
  if (a.unreadCount != b.unreadCount) return false;
  if (a.updatedAt != b.updatedAt) return false;
  if (a.lastReadMessageId != b.lastReadMessageId) return false;
  if (a.groupTitle != b.groupTitle) return false;
  if (a.memberCount != b.memberCount) return false;
  if (a.onlineCount != b.onlineCount) return false;
  final ou = a.otherUser, ob = b.otherUser;
  if ((ou == null) != (ob == null)) return false;
  if (ou != null && ob != null) {
    if (ou.id != ob.id) return false;
    if (ou.firstName != ob.firstName || ou.lastName != ob.lastName) {
      return false;
    }
    if (ou.profilePhoto != ob.profilePhoto) return false;
    if (ou.isOnline != ob.isOnline) return false;
  }
  final lm = a.lastMessage, rm = b.lastMessage;
  if ((lm == null) != (rm == null)) return false;
  if (lm != null) {
    if (lm.id != rm!.id ||
        lm.body != rm.body ||
        lm.createdAt != rm.createdAt ||
        lm.senderId != rm.senderId ||
        lm.attachmentKind != rm.attachmentKind) {
      return false;
    }
  }
  return tenantPinnedSummariesEqual(a.pinnedMessages, b.pinnedMessages);
}

bool tenantConversationsPayloadEqual(
  List<TenantChatConversation> a,
  List<TenantChatConversation> b,
) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!tenantConversationTilePayloadEqual(a[i], b[i])) return false;
  }
  return true;
}

List<TenantChatConversation> sortTenantConversations(
  List<TenantChatConversation> input,
) {
  final sorted = [...input]..sort((a, b) {
      final ag = a.isCompanyGroup ? 1 : 0;
      final bg = b.isCompanyGroup ? 1 : 0;
      if (ag != bg) return bg.compareTo(ag);
      return b.updatedAt.compareTo(a.updatedAt);
    });
  return sorted;
}
