import 'package:flutter/foundation.dart';

/// Shared unread total for the notification-bell badge on the home screens.
///
/// Written from two places, both of which already know the number:
///
/// * [WhatsAppChatUnreadPoller], from the digest's `notifications_unread` — the
///   same poll that already feeds the team-chat and WhatsApp badges. The bell
///   used to cost a separate `GET /notifications/unread_count/` per home screen
///   per launch for a count the digest was returning anyway.
/// * [NotificationsScreen], as the user reads or deletes notifications, so the
///   badge behind it is already correct when they navigate back instead of
///   waiting for the next poll.
class NotificationsUnreadHolder {
  NotificationsUnreadHolder._();
  static final ValueNotifier<int> totalUnread = ValueNotifier<int>(0);

  static void setTotal(int n) {
    final value = n < 0 ? 0 : n;
    if (totalUnread.value != value) {
      totalUnread.value = value;
    }
  }
}
