import '../../chat_engine/coordinator/chat_engine_bundle.dart';
import '../whatsapp_chat/whatsapp_chat_repository.dart';
import 'whatsapp_message_adapter.dart';
import 'whatsapp_thread_repository.dart';

typedef WhatsAppEngineBundle = ChatEngineBundle<WhatsAppEngineMessage>;

class WhatsAppCoordinatorFactory {
  static WhatsAppEngineBundle create({
    required WhatsAppChatRepository repository,
    int? clientId,
    required String phoneNumber,
    int? readCursor,
    bool Function()? isForeground,
  }) {
    final cursor = readCursor ?? 0;
    return createChatEngineBundle<WhatsAppEngineMessage>(
      repository: WhatsAppThreadRepository(
        repository: repository,
        clientId: clientId,
        phoneNumber: phoneNumber,
      ),
      sameSender: (current, previous) =>
          previous != null && previous.senderId == current.senderId,
      isFirstUnreadPeerMessage: (m) =>
          m.raw.isInbound && !m.raw.isRead && m.id > cursor,
      invalidationKey: 'whatsapp:conversations',
      isForeground: isForeground,
    );
  }
}
