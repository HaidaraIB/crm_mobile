import '../../models/social_conversation_model.dart';
import '../../models/social_message_model.dart';
import '../../services/api_service.dart';

/// Data access for the Omni-Channel Inbox (Instagram DM + Messenger).
abstract class SocialInboxRepository {
  Future<SocialConversationsPage> getConversations({
    String? channel,
    String? status,
    String? assignment,
    String? converted,
    bool? starred,
    bool? unreplied,
    String? search,
    int? limit,
    int? offset,
  });

  Future<List<SocialMessageModel>> getMessages(int conversationId);

  Future<SocialSendWindow> getSendWindow(int conversationId);

  Future<SocialMessageModel?> sendMessage({
    required int conversationId,
    required String text,
  });

  Future<void> sendMedia({
    required int conversationId,
    required String filePath,
    String? text,
  });

  Future<void> markRead(int conversationId);

  Future<void> updateState({
    required int conversationId,
    String? status,
    String? snoozedUntil,
    bool? isStarred,
    bool? isUnsubscribed,
  });

  Future<Map<String, dynamic>> convertToLead({
    required int conversationId,
    String? name,
    String? phone,
    int? assignedTo,
    bool autoAssign,
    String? notes,
  });

  Future<int> getUnreadCount();

  String attachmentUrl(int messageId);
}

class ApiSocialInboxRepository implements SocialInboxRepository {
  ApiSocialInboxRepository([ApiService? api]) : _api = api ?? ApiService();

  final ApiService _api;

  @override
  Future<SocialConversationsPage> getConversations({
    String? channel,
    String? status,
    String? assignment,
    String? converted,
    bool? starred,
    bool? unreplied,
    String? search,
    int? limit,
    int? offset,
  }) =>
      _api.getSocialConversations(
        channel: channel,
        status: status,
        assignment: assignment,
        converted: converted,
        starred: starred,
        unreplied: unreplied,
        search: search,
        limit: limit,
        offset: offset,
      );

  @override
  Future<List<SocialMessageModel>> getMessages(int conversationId) =>
      _api.getSocialMessages(conversationId);

  @override
  Future<SocialSendWindow> getSendWindow(int conversationId) =>
      _api.getSocialSendWindow(conversationId);

  @override
  Future<SocialMessageModel?> sendMessage({
    required int conversationId,
    required String text,
  }) =>
      _api.sendSocialMessage(conversationId: conversationId, text: text);

  @override
  Future<void> sendMedia({
    required int conversationId,
    required String filePath,
    String? text,
  }) =>
      _api.sendSocialMedia(
        conversationId: conversationId,
        filePath: filePath,
        text: text,
      );

  @override
  Future<void> markRead(int conversationId) =>
      _api.markSocialConversationRead(conversationId);

  @override
  Future<void> updateState({
    required int conversationId,
    String? status,
    String? snoozedUntil,
    bool? isStarred,
    bool? isUnsubscribed,
  }) =>
      _api.updateSocialConversationState(
        conversationId: conversationId,
        status: status,
        snoozedUntil: snoozedUntil,
        isStarred: isStarred,
        isUnsubscribed: isUnsubscribed,
      );

  @override
  Future<Map<String, dynamic>> convertToLead({
    required int conversationId,
    String? name,
    String? phone,
    int? assignedTo,
    bool autoAssign = true,
    String? notes,
  }) =>
      _api.convertSocialConversation(
        conversationId: conversationId,
        name: name,
        phone: phone,
        assignedTo: assignedTo,
        autoAssign: autoAssign,
        notes: notes,
      );

  @override
  Future<int> getUnreadCount() => _api.getSocialInboxUnreadCount();

  @override
  String attachmentUrl(int messageId) => _api.socialMessageAttachmentUrl(messageId);
}
