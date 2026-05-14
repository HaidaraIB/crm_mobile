import 'dart:async';

import 'api_service.dart';
import 'team_chat_unread_holder.dart';

/// Polls conversations when user is away from Team Chat (foreground) to refresh drawer unread badge.
/// In-app sounds are not used here; tenant chat alerts use FCM / local notification handling instead.
class TeamChatAwayService {
  TeamChatAwayService._();
  static final TeamChatAwayService instance = TeamChatAwayService._();

  final ApiService _api = ApiService();
  Timer? _timer;
  bool _hydrated = false;
  bool teamChatRouteVisible = false;
  bool appForeground = true;

  /// Conversation thread currently open in Team Chat (null = list / none). Used to suppress duplicate alerts.
  int? activeConversationId;

  void setActiveConversationId(int? id) {
    activeConversationId = id;
  }

  /// Skip heads-up local notification when this exact DM is already open in the foreground.
  bool shouldSuppressForegroundTenantChatNotification(int? conversationId) {
    if (!appForeground || !teamChatRouteVisible) return false;
    final open = activeConversationId;
    if (open == null || conversationId == null) return false;
    return open == conversationId;
  }

  void setAppForeground(bool v) {
    appForeground = v;
    if (!v) {
      _timer?.cancel();
      _timer = null;
    } else {
      start();
    }
  }

  void setTeamChatVisible(bool v) {
    teamChatRouteVisible = v;
    if (!v) {
      activeConversationId = null;
    } else {
      _hydrated = true;
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
      _hydrated = true;
    } catch (_) {}
  }

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    if (!appForeground) return;
    if (teamChatRouteVisible) return;
    final has = await _api.hasStoredAccessToken();
    if (!has) return;
    try {
      final page = await _api.getTenantChatConversations();
      final total = page.results.fold<int>(
        0,
        (s, c) => s + c.unreadCount,
      );
      TeamChatUnreadHolder.setTotal(total);
      if (!_hydrated) {
        _hydrated = true;
        return;
      }
    } catch (_) {}
  }

  void dispose() {
    stop();
  }
}
