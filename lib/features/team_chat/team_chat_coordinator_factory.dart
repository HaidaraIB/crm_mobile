import '../../chat_engine/coordinator/chat_engine_bundle.dart';
import '../../services/api_service.dart';
import 'tenant_chat_message_adapter.dart';
import 'tenant_chat_repository.dart';

typedef TeamChatEngineBundle = ChatEngineBundle<TenantEngineMessage>;

class TeamChatCoordinatorFactory {
  static TeamChatEngineBundle create({
    required ApiService api,
    required int conversationId,
    required int currentUserId,
    required int readCursor,
    bool Function()? isForeground,
  }) {
    return createChatEngineBundle<TenantEngineMessage>(
      repository: TenantChatRepository(
        api: api,
        conversationId: conversationId,
      ),
      sameSender: (current, previous) =>
          previous != null && previous.senderId == current.senderId,
      isFirstUnreadPeerMessage: (m) =>
          m.senderId != currentUserId && m.id > readCursor,
      invalidationKey: 'tenant_chat:messages',
      isForeground: isForeground,
    );
  }
}
