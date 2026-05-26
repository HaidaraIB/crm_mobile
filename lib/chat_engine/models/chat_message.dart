abstract class ChatMessage {
  int get id;
  int get senderId;
  DateTime get createdAt;
  String get body;
  int? get replyToMessageId;
}

