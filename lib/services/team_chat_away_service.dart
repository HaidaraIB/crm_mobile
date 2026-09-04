import 'dart:async';

import 'api_service.dart';
import 'team_chat_unread_holder.dart';

/// Tracks Team Chat route visibility for foreground notification suppression.
/// Badge totals come from the sync digest poller.
class TeamChatAwayService {
  TeamChatAwayService._();
  static final TeamChatAwayService instance = TeamChatAwayService._();

  final ApiService _api = ApiService();
  bool teamChatRouteVisible = false;
  bool appForeground = true;

  int? activeConversationId;

  void setActiveConversationId(int? id) {
    activeConversationId = id;
  }

  /// Whether a push about [conversationId] is about a thread already on screen.
  ///
  /// Deliberately does *not* consult [teamChatRouteVisible]. That flag is driven
  /// by the route observer, so pushing anything over the thread — the media
  /// viewer, a profile — flipped it false and re-enabled alerts for the
  /// conversation the user was still very much inside. [activeConversationId] is
  /// the precise signal: it is set when a thread is selected and cleared when the
  /// selection is dropped or the list cubit closes, which is exactly the window
  /// during which an alert would be noise.
  bool shouldSuppressForegroundTenantChatNotification(int? conversationId) {
    if (!appForeground) return false;
    final open = activeConversationId;
    if (open == null || conversationId == null) return false;
    return open == conversationId;
  }

  void setAppForeground(bool v) {
    appForeground = v;
  }

  void setTeamChatVisible(bool v) {
    teamChatRouteVisible = v;
    if (v) {
      unawaited(_syncUnreadBaseline());
    }
  }

  Future<void> _syncUnreadBaseline() async {
    try {
      final page = await _api.getTenantChatConversations();
      final total = page.results.fold<int>(
        0,
        (s, c) => s + c.unreadCount,
      );
      TeamChatUnreadHolder.setTotal(total);
    } catch (_) {}
  }

  void start() {}

  void stop() {}

  void dispose() {
    stop();
  }
}
