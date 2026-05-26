import 'dart:async';

import '../models/chat_message.dart';
import '../registry/message_registry.dart';
import '../scroll/chat_scroll_service.dart';

typedef MarkReadCallback = Future<void> Function(int messageId);

class ChatReadTracker<T extends ChatMessage> {
  ChatReadTracker({
    required this.registry,
    required this.scrollService,
    required this.currentUserId,
    required this.markRead,
  });

  final MessageRegistry<T> registry;
  final ChatScrollService scrollService;
  final int currentUserId;
  final MarkReadCallback markRead;

  Timer? _debounce;
  int readCursor = 0;
  int pendingMarkRead = 0;

  int peerBelowFab = 0;
  bool showFab = false;

  void updateServerCursor(int cursor) {
    if (cursor > readCursor) readCursor = cursor;
  }

  void onScrollUpdated(int itemCount) {
    final metrics = scrollService.metricsFor(itemCount);
    final all = registry.messages.toList();
    if (all.isEmpty) {
      showFab = false;
      peerBelowFab = 0;
      return;
    }
    showFab = !metrics.nearBottom;
    peerBelowFab = metrics.nearBottom
        ? 0
        : all.where((m) => m.senderId != currentUserId && m.id > readCursor).length;
    final target = metrics.nearBottom ? all.last.id : _maxVisiblePeerOrSelf(all);
    if (target <= readCursor) return;
    pendingMarkRead = pendingMarkRead > target ? pendingMarkRead : target;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 160), () async {
      final id = pendingMarkRead;
      pendingMarkRead = 0;
      if (id <= readCursor) return;
      await markRead(id);
      if (id > readCursor) readCursor = id;
    });
  }

  int _maxVisiblePeerOrSelf(List<T> all) {
    var maxId = readCursor;
    for (final m in all) {
      if (m.id > maxId) maxId = m.id;
    }
    return maxId;
  }

  void dispose() {
    _debounce?.cancel();
  }
}

