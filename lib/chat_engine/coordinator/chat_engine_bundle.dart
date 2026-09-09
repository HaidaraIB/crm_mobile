import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../cubit/chat_thread_cubit.dart';
import '../highlight/message_highlight_controller.dart';
import '../models/chat_message.dart';
import '../registry/message_registry.dart';
import '../scroll/chat_scroll_service.dart';
import 'chat_coordinator.dart';

/// Wired thread engine for one conversation (list + scroll + jump-to-message).
class ChatEngineBundle<T extends ChatMessage> {
  const ChatEngineBundle({
    required this.registry,
    required this.threadCubit,
    required this.scrollService,
    required this.highlightController,
    required this.coordinator,
    required this.itemScrollController,
    required this.itemPositionsListener,
  });

  final MessageRegistry<T> registry;
  final ChatThreadCubit<T> threadCubit;
  final ChatScrollService scrollService;
  final MessageHighlightController highlightController;
  final ChatCoordinator<T> coordinator;
  final ItemScrollController itemScrollController;
  final ItemPositionsListener itemPositionsListener;

  void dispose() {
    threadCubit.close();
    highlightController.dispose();
  }
}

/// Shared wiring for [ChatEngineBundle] from a channel repository + callbacks.
ChatEngineBundle<T> createChatEngineBundle<T extends ChatMessage>({
  required ChatThreadRepository<T> repository,
  required bool Function(T current, T? previous) sameSender,
  required bool Function(T message) isFirstUnreadPeerMessage,
  required String invalidationKey,
  bool Function()? isForeground,
}) {
  final itemScrollController = ItemScrollController();
  final itemPositionsListener = ItemPositionsListener.create();
  final registry = MessageRegistry<T>();
  final threadCubit = ChatThreadCubit<T>(
    repository: repository,
    registry: registry,
    sameSender: sameSender,
    isFirstUnreadPeerMessage: isFirstUnreadPeerMessage,
    invalidationKey: invalidationKey,
    isForeground: isForeground,
  );
  final scrollService = ChatScrollService(
    itemScrollController: itemScrollController,
    itemPositionsListener: itemPositionsListener,
  );
  final highlightController = MessageHighlightController();
  final coordinator = ChatCoordinator<T>(
    threadCubit: threadCubit,
    scrollService: scrollService,
    highlightController: highlightController,
  );
  return ChatEngineBundle<T>(
    registry: registry,
    threadCubit: threadCubit,
    scrollService: scrollService,
    highlightController: highlightController,
    coordinator: coordinator,
    itemScrollController: itemScrollController,
    itemPositionsListener: itemPositionsListener,
  );
}
