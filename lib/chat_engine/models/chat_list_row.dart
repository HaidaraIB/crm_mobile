import 'chat_message.dart';

sealed class ChatListRow {
  const ChatListRow();
}

class ChatMessageRow extends ChatListRow {
  const ChatMessageRow(this.message, {required this.sameSenderAsPrevious});

  final ChatMessage message;
  final bool sameSenderAsPrevious;
}

class ChatDaySeparatorRow extends ChatListRow {
  const ChatDaySeparatorRow(this.dayStart);

  final DateTime dayStart;
}

class ChatUnreadSeparatorRow extends ChatListRow {
  const ChatUnreadSeparatorRow();
}

