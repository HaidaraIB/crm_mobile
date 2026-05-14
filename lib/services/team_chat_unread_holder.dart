import 'package:flutter/foundation.dart';

/// Shared unread total for drawer badge and away sound (updated by chat + away poller).
class TeamChatUnreadHolder {
  TeamChatUnreadHolder._();
  static final ValueNotifier<int> totalUnread = ValueNotifier<int>(0);

  static void setTotal(int n) {
    if (totalUnread.value != n) {
      totalUnread.value = n;
    }
  }
}
