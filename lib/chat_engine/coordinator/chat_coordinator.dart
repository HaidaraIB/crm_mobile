import '../cubit/chat_thread_cubit.dart';
import '../highlight/message_highlight_controller.dart';
import '../models/chat_navigation_request.dart';
import '../navigation/chat_navigation_queue.dart';
import '../navigation/chat_navigation_source.dart';
import '../scroll/chat_scroll_service.dart';

class ChatCoordinator<T extends Object> {
  ChatCoordinator({
    required this.threadCubit,
    required this.scrollService,
    required this.highlightController,
  }) : navigationQueue = ChatNavigationQueue(
          ensureLoaded: threadCubit.ensureMessageLoaded,
          scrollToMessage: (messageId) async {
            final rowIndex = threadCubit.state.rowIndexForMessage(messageId);
            if (rowIndex == null) return;
            await scrollService.scrollToRowIndex(rowIndex);
          },
          highlight: highlightController.highlight,
        );

  final ChatThreadCubit threadCubit;
  final ChatScrollService scrollService;
  final MessageHighlightController highlightController;
  final ChatNavigationQueue navigationQueue;

  Future<void> navigateToMessage(
    int messageId, {
    NavigationSource source = NavigationSource.unknown,
  }) {
    scrollService.stickToTail = false;
    return navigationQueue.enqueue(
      ChatNavigationRequest(messageId: messageId, source: source),
    );
  }

  Future<void> scrollToBottom({bool animated = true}) {
    return scrollService.scrollToBottom(animated: animated);
  }
}
