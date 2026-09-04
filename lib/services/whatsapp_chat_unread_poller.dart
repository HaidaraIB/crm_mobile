import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'notifications_unread_holder.dart';
import 'realtime_channel.dart';
import 'sync_invalidation.dart';
import 'team_chat_unread_holder.dart';
import 'whatsapp_chat_unread_holder.dart';

/// Polls `GET /sync/digest/` so home badges work without opening chat lists.
///
/// Also the app's change feed. Alongside the badge counts the digest reports a
/// monotonic counter per slice of company data, so this one request can tell the
/// chat cubits that their data moved — they already listen on [SyncInvalidation]
/// for exactly that, because an FCM push says the same thing. Screens therefore
/// keep only a long safety-net timer instead of each polling every 30s.
class WhatsAppChatUnreadPoller {
  WhatsAppChatUnreadPoller._();
  static final WhatsAppChatUnreadPoller instance = WhatsAppChatUnreadPoller._();

  final ApiService _api = ApiService();
  Timer? _timer;
  bool _foreground = true;
  bool _started = false;

  /// Last slice counters seen, so a change can be told from a first sighting.
  ///
  /// The first digest after launch only establishes a baseline — emitting on it
  /// would make every cold start refresh everything the bus reaches, which is the
  /// work this exists to avoid.
  Map<String, int> _lastVersions = const {};

  /// Collapses concurrent refreshes into one request.
  ///
  /// Several things legitimately ask for a refresh at once — app resume, a push,
  /// a socket frame, a screen mounting — and without this each produced its own
  /// `/sync/digest/` call. A launch log showed two back to back for exactly that
  /// reason.
  Future<void>? _inFlight;

  /// Slice name -> the `invalidate` key its subscribers already listen for.
  static const Map<String, String> _sliceInvalidationKeys = {
    'chat': 'whatsapp:conversations',
    'tenant_chat': 'tenant_chat:messages',
  };

  void start() {
    if (_started) return;
    _started = true;
    unawaited(refresh());
    _restartTimer();
  }

  /// Poll cadence: the socket makes this a backstop rather than the mechanism.
  ///
  /// With a live connection every change arrives as a frame, so the timer only
  /// has to cover a socket that is open but silently not delivering — a failure
  /// the client cannot otherwise detect. Without one it stays at the original
  /// 30s, so turning realtime off restores the previous behaviour exactly.
  Duration get _interval => RealtimeChannel.instance.isConnected
      ? const Duration(seconds: 120)
      : const Duration(seconds: 30);

  Duration? _armedFor;

  void _restartTimer() {
    _timer?.cancel();
    _armedFor = _interval;
    _timer = Timer.periodic(_interval, (_) {
      if (_foreground) unawaited(refresh());
    });
  }

  /// Re-arm at the other cadence when the socket comes up or goes down.
  ///
  /// Called by [RealtimeChannel] rather than polled for, so the interval tracks
  /// the connection immediately instead of on the next tick — which at 120s
  /// would mean two minutes of silence after a drop.
  void onRealtimeConnectionChanged() {
    if (!_started) return;
    if (_armedFor == _interval) return;
    _restartTimer();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  void reset() {
    // Counters are scoped to a company and a user, so values carried across a
    // session change would compare against a different tenant's sequence and
    // emit a meaningless invalidation on the next poll.
    _lastVersions = const {};
    WhatsAppChatUnreadHolder.reset();
  }

  void setForeground(bool value) {
    _foreground = value;
    if (value && _started) unawaited(refresh());
  }

  /// Emit an invalidation for each slice whose counter moved since last poll.
  ///
  /// Deliberately called before any of the badge handling below: the WhatsApp
  /// branch returns early for users whose access is off, and team chat is not
  /// theirs to miss — routing versions through that path would leave those users
  /// on the safety-net timer alone.
  void _publishSliceChanges(Object? raw) {
    if (raw is! Map) return;
    final Map<String, int> current = {};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (entry.key is String && value is num) {
        current[entry.key as String] = value.toInt();
      }
    }
    if (current.isEmpty) return;

    final previous = _lastVersions;
    _lastVersions = current;
    if (previous.isEmpty) return; // First sighting: baseline only.

    _sliceInvalidationKeys.forEach((slice, invalidateKey) {
      final before = previous[slice];
      final after = current[slice];
      if (before != null && after != null && after != before) {
        SyncInvalidation.instance.emit({'invalidate': invalidateKey});
      }
    });
  }

  Future<void> refresh() {
    final existing = _inFlight;
    if (existing != null) return existing;
    final future = _refresh().whenComplete(() => _inFlight = null);
    _inFlight = future;
    return future;
  }

  Future<void> _refresh() async {
    try {
      final data = await _api.getSyncDigest();
      if (data.isEmpty) return;
      _publishSliceChanges(data['versions']);
      TeamChatUnreadHolder.setTotal((data['tenant_chat_unread'] as num?)?.toInt() ?? 0);
      // Before the WhatsApp branch below, which returns early for users whose
      // chat access is off — the bell is not theirs to miss.
      NotificationsUnreadHolder.setTotal(
        (data['notifications_unread'] as num?)?.toInt() ?? 0,
      );
      final wa = data['whatsapp_unread'];
      if (!data.containsKey('whatsapp_unread')) {
        return;
      }
      if (wa == null) {
        WhatsAppChatUnreadHolder.setAvailable(false);
        return;
      }
      WhatsAppChatUnreadHolder.setAvailable(true);
      WhatsAppChatUnreadHolder.setTotal((wa as num?)?.toInt() ?? 0);
    } catch (e) {
      debugPrint('Sync digest poll failed: $e');
    }
  }
}
