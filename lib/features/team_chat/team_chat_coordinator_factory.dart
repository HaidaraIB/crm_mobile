import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../chat_engine/coordinator/chat_coordinator.dart';
import '../../chat_engine/cubit/chat_thread_cubit.dart';
import '../../chat_engine/highlight/message_highlight_controller.dart';
import '../../chat_engine/registry/message_registry.dart';
import '../../chat_engine/scroll/chat_scroll_service.dart';
import '../../services/api_service.dart';
import 'tenant_chat_message_adapter.dart';
import 'tenant_chat_repository.dart';

class TeamChatEngineBundle {
  const TeamChatEngineBundle({
    required this.registry,
    required this.threadCubit,
    required this.scrollService,
    required this.highlightController,
    required this.coordinator,
    required this.itemScrollController,
    required this.itemPositionsListener,
  });

  final MessageRegistry<TenantEngineMessage> registry;
  final ChatThreadCubit<TenantEngineMessage> threadCubit;
  final ChatScrollService scrollService;
  final MessageHighlightController highlightController;
  final ChatCoordinator<TenantEngineMessage> coordinator;
  final ItemScrollController itemScrollController;
  final ItemPositionsListener itemPositionsListener;

  void dispose() {
    threadCubit.close();
    highlightController.dispose();
  }
}

class TeamChatCoordinatorFactory {
  static TeamChatEngineBundle create({
    required ApiService api,
    required int conversationId,
    required int currentUserId,
    required int readCursor,
  }) {
    final itemScrollController = ItemScrollController();
    final itemPositionsListener = ItemPositionsListener.create();
    final registry = MessageRegistry<TenantEngineMessage>();
    final repository = TenantChatRepository(
      api: api,
      conversationId: conversationId,
    );
    final threadCubit = ChatThreadCubit<TenantEngineMessage>(
      repository: repository,
      registry: registry,
      sameSender: (current, previous) =>
          previous != null && previous.senderId == current.senderId,
      isFirstUnreadPeerMessage: (m) =>
          m.senderId != currentUserId && m.id > readCursor,
    );
    final scrollService = ChatScrollService(
      itemScrollController: itemScrollController,
      itemPositionsListener: itemPositionsListener,
    );
    final highlightController = MessageHighlightController();
    final coordinator = ChatCoordinator<TenantEngineMessage>(
      threadCubit: threadCubit,
      scrollService: scrollService,
      highlightController: highlightController,
    );
    return TeamChatEngineBundle(
      registry: registry,
      threadCubit: threadCubit,
      scrollService: scrollService,
      highlightController: highlightController,
      coordinator: coordinator,
      itemScrollController: itemScrollController,
      itemPositionsListener: itemPositionsListener,
    );
  }
}
