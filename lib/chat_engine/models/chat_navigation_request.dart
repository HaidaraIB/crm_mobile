import '../navigation/chat_navigation_source.dart';

class ChatNavigationRequest {
  const ChatNavigationRequest({
    required this.messageId,
    required this.source,
    this.highlight = true,
  });

  final int messageId;
  final NavigationSource source;
  final bool highlight;
}

