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

  bool shouldSuppressForegroundTenantChatNotification(int? conversationId) {
    if (!appForeground || !teamChatRouteVisible) return false;
    final open = activeConversationId;
    if (open == null || conversationId == null) return false;
    return open == conversationId;
  }

  void setAppForeground(bool v) {
    appForeground = v;
  }

  void setTeamChatVisible(bool v) {
    teamChatRouteVisible = v;
    if (!v) {
      activeConversationId = null;
    } else {
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
