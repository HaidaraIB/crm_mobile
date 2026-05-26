import '../models/chat_navigation_request.dart';

typedef EnsureLoadedCallback = Future<bool> Function(int messageId);
typedef ScrollToMessageCallback = Future<void> Function(int messageId);
typedef HighlightCallback = void Function(int messageId);

class ChatNavigationQueue {
  ChatNavigationQueue({
    required this.ensureLoaded,
    required this.scrollToMessage,
    required this.highlight,
  });

  final EnsureLoadedCallback ensureLoaded;
  final ScrollToMessageCallback scrollToMessage;
  final HighlightCallback highlight;

  int _token = 0;

  Future<void> enqueue(ChatNavigationRequest request) async {
    _token++;
    final token = _token;
    final loaded = await ensureLoaded(request.messageId);
    if (token != _token || !loaded) return;
    await scrollToMessage(request.messageId);
    if (token != _token || !request.highlight) return;
    highlight(request.messageId);
  }

  void cancel() {
    _token++;
  }
}

