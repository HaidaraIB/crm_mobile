import 'package:flutter/foundation.dart';

/// Shared unread total for the WhatsApp Chats app bar badge (updated by the conversation list poller).
class WhatsAppChatUnreadHolder {
  WhatsAppChatUnreadHolder._();
  static final ValueNotifier<int> totalUnread = ValueNotifier<int>(0);

  /// Whether the tenant/user may use WhatsApp Chats.
  ///
  /// `null` until the first digest (unknown — still show the icon if the user
  /// role allows it). `false` when the digest omits `whatsapp_unread` because
  /// of plan, company policy, or per-user access — hide the entry rather than
  /// letting them open a dead "Could not load" screen.
  static final ValueNotifier<bool?> chatsAvailable = ValueNotifier<bool?>(null);

  static void setTotal(int n) {
    if (totalUnread.value != n) {
      totalUnread.value = n;
    }
  }

  static void setAvailable(bool available) {
    if (chatsAvailable.value != available) {
      chatsAvailable.value = available;
    }
    if (!available) setTotal(0);
  }

  /// Session change: forget the previous tenant's gate until the next digest.
  static void reset() {
    totalUnread.value = 0;
    chatsAvailable.value = null;
  }
}
