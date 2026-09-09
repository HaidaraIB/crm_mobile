import '../../chat_engine/coordinator/chat_engine_bundle.dart';
import '../social_inbox/social_inbox_repository.dart';
import 'social_inbox_thread_repository.dart';
import 'social_message_adapter.dart';

typedef SocialInboxEngineBundle = ChatEngineBundle<SocialEngineMessage>;

class SocialInboxCoordinatorFactory {
  static SocialInboxEngineBundle create({
    required SocialInboxRepository repository,
    required int conversationId,
    bool Function()? isForeground,
  }) {
    return createChatEngineBundle<SocialEngineMessage>(
      repository: SocialInboxThreadRepository(
        repository: repository,
        conversationId: conversationId,
      ),
      sameSender: (current, previous) =>
          previous != null && previous.senderId == current.senderId,
      isFirstUnreadPeerMessage: (m) => !m.raw.isOutbound && !m.raw.isRead,
      invalidationKey: 'social:conversations',
      isForeground: isForeground,
    );
  }
}
