/// Viewport anchor for prepend — row index + message id for stable restore after prepend.
class ChatAnchorSnapshot {
  const ChatAnchorSnapshot({
    required this.rowIndex,
    required this.messageId,
    required this.itemLeadingEdge,
  });

  final int rowIndex;
  final int messageId;
  final double itemLeadingEdge;
}
