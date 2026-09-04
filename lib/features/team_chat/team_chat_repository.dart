import '../../models/tenant_chat_models.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/realtime_channel.dart';

abstract class TeamChatRepository {
  Future<UserModel> getCurrentUser();
  Future<TenantChatConversationsPage> getConversations();
  Future<TenantChatPeersPage> getEligibleUsers();
  Future<TenantChatConversation> startConversation(int withUserId);
  Future<TenantChatPeerPresenceResponse> getPeerPresence(int conversationId);
  Future<void> postPeerPresence(int conversationId, String action);
  Future<TenantChatMessage> sendMessage(
    int conversationId,
    String body, {
    int? replyToMessageId,
    int? forwardFromMessageId,
  });
  Future<TenantChatMessage> sendMessageWithFile(
    int conversationId,
    String filePath, {
    String? body,
    int? replyToMessageId,
  });
  Future<void> pinMessage(int conversationId, int messageId);
  Future<void> unpinMessage(int conversationId, int messageId);
}

class ApiTeamChatRepository implements TeamChatRepository {
  ApiTeamChatRepository([ApiService? api]) : _api = api ?? ApiService();

  final ApiService _api;

  @override
  Future<UserModel> getCurrentUser() => _api.getCurrentUser();

  @override
  Future<TenantChatConversationsPage> getConversations() =>
      _api.getTenantChatConversations();

  @override
  Future<TenantChatPeersPage> getEligibleUsers() =>
      _api.getTenantChatEligibleUsers();

  @override
  Future<TenantChatConversation> startConversation(int withUserId) =>
      _api.startTenantChatConversation(withUserId);

  @override
  Future<TenantChatPeerPresenceResponse> getPeerPresence(int conversationId) =>
      _api.getTenantChatPeerPresence(conversationId);

  /// Report own typing/recording state — over the socket when there is one.
  ///
  /// This fires every few seconds for as long as somebody is typing, so it is
  /// the chattiest write in the app. A frame costs a fraction of an
  /// authenticated POST, and the server writes the same presence cache either
  /// way, so a colleague whose socket is down still sees this user as active.
  @override
  Future<void> postPeerPresence(int conversationId, String action) async {
    if (RealtimeChannel.instance.sendPresence(conversationId, action)) return;
    await _api.postTenantChatPeerPresence(conversationId, action);
  }

  @override
  Future<TenantChatMessage> sendMessage(
    int conversationId,
    String body, {
    int? replyToMessageId,
    int? forwardFromMessageId,
  }) =>
      _api.sendTenantChatMessage(
        conversationId,
        body,
        replyToMessageId: replyToMessageId,
        forwardFromMessageId: forwardFromMessageId,
      );

  @override
  Future<TenantChatMessage> sendMessageWithFile(
    int conversationId,
    String filePath, {
    String? body,
    int? replyToMessageId,
  }) =>
      _api.sendTenantChatMessageWithFile(
        conversationId,
        filePath,
        body: body,
        replyToMessageId: replyToMessageId,
      );

  @override
  Future<void> pinMessage(int conversationId, int messageId) =>
      _api.pinTenantChatMessage(conversationId, messageId);

  @override
  Future<void> unpinMessage(int conversationId, int messageId) =>
      _api.unpinTenantChatMessage(conversationId, messageId);
}
