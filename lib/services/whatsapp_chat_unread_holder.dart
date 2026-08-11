import 'package:flutter/foundation.dart';

/// Shared unread total for the WhatsApp Chats app bar badge (updated by the conversation list poller).
class WhatsAppChatUnreadHolder {
  WhatsAppChatUnreadHolder._();
  static final ValueNotifier<int> totalUnread = ValueNotifier<int>(0);

  static void setTotal(int n) {
    if (totalUnread.value != n) {
      totalUnread.value = n;
    }
  }
}
