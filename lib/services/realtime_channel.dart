import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/constants/app_constants.dart';
import '../core/storage/auth_token_storage.dart';
import 'sync_invalidation.dart';
import 'whatsapp_chat_unread_poller.dart';

/// WebSocket delivery for the sync digest, matching the web client.
///
/// The app already reacts to change notifications — an FCM push emits on
/// [SyncInvalidation] and the cubits refresh. This adds a second, faster source
/// of the same signal for while the app is actually open: the server pushes
/// `{"scope": "company:tenant_chat", "version": 12}` and the bus fires
/// immediately, instead of waiting up to 30 seconds for the next digest poll.
///
/// Frames carry no data, only a version. The app re-reads through the ordinary
/// authenticated endpoints, so every per-user permission rule stays where it
/// already is and none of it is duplicated on the socket.
///
/// **Nothing is removed.** The digest poller and the per-screen timers keep
/// running at their existing cadence. Push remains the only thing that reaches a
/// backgrounded app — the OS suspends this socket within seconds of the app
/// leaving the foreground, which is exactly why it cannot replace FCM.
class RealtimeChannel {
  RealtimeChannel._();
  static final RealtimeChannel instance = RealtimeChannel._();

  static const Duration _minBackoff = Duration(seconds: 1);
  static const Duration _maxBackoff = Duration(seconds: 30);

  /// Inside the server's 90s presence TTL, so one missed beat does not blink
  /// this user offline for colleagues watching.
  static const Duration _heartbeatInterval = Duration(seconds: 45);

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  int _attempt = 0;
  bool _started = false;
  bool _connected = false;
  /// True once a connection has been established at least this session.
  ///
  /// The catch-up read below only makes sense on a *re*connect, where events may
  /// have been missed while the socket was down. Doing it on the first connect
  /// duplicates work the screen is already doing as it loads — which showed up
  /// as four identical conversation fetches in a launch log.
  bool _hasConnected = false;
  final Random _random = Random();

  bool get isConnected => _connected;

  /// Presence frames for chat threads this connection has subscribed to.
  ///
  /// Broadcast so the presence cubit and anything else interested can listen
  /// without competing for a single-subscription stream.
  final StreamController<RealtimePresence> _presenceController =
      StreamController<RealtimePresence>.broadcast();
  Stream<RealtimePresence> get presence => _presenceController.stream;

  /// Emitted when the connection comes up or goes down, so callers can tighten
  /// their fallback polling the moment delivery stops.
  final StreamController<bool> _statusController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectionChanges => _statusController.stream;

  /// Conversations this connection is subscribed to, re-sent after a reconnect.
  ///
  /// The server forgets subscriptions when a socket drops — they live on the
  /// connection, not the user — so without replaying them a reconnect would
  /// leave every open thread silently receiving nothing.
  final Set<int> _subscribedConversations = <int>{};

  /// Ask the server to send presence for this thread. Safe to call when
  /// disconnected: it is remembered and sent on the next connect.
  void subscribeConversation(int conversationId) {
    _subscribedConversations.add(conversationId);
    _send({'action': 'subscribe', 'conversation': conversationId});
  }

  void unsubscribeConversation(int conversationId) {
    _subscribedConversations.remove(conversationId);
    _send({'action': 'unsubscribe', 'conversation': conversationId});
  }

  /// Report this user's own typing/recording state. Returns false when there is
  /// no socket, which is the caller's signal to POST over HTTP instead.
  bool sendPresence(int conversationId, String state) {
    if (!_connected) return false;
    _send({
      'action': 'presence',
      'conversation': conversationId,
      'state': state,
    });
    return true;
  }

  /// ws(s)://host/ws/sync/ derived from the configured API base URL.
  String? _socketUrl() {
    try {
      final uri = Uri.parse(AppConstants.baseUrl);
      if (uri.host.isEmpty) return null;
      return uri
          .replace(
            scheme: uri.scheme == 'https' ? 'wss' : 'ws',
            path: '/ws/sync/',
            query: null,
          )
          .toString();
    } catch (_) {
      return null;
    }
  }

  /// Connect, or do nothing if already running. Safe to call repeatedly.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _connect();
  }

  /// Disconnect and stop reconnecting. Called when the app leaves the
  /// foreground: the OS would suspend the socket anyway, and holding a dead
  /// connection open just delays noticing.
  Future<void> stop() async {
    _started = false;
    _attempt = 0;
    _hasConnected = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _connected = false;
    _subscribedConversations.clear();
    WhatsAppChatUnreadPoller.instance.onRealtimeConnectionChanged();
    _statusController.add(false);
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {
      /* already gone */
    }
    _channel = null;
  }

  Future<void> _connect() async {
    if (!_started) return;

    final url = _socketUrl();
    if (url == null) {
      debugPrint('Realtime: no socket URL could be derived from baseUrl');
      _started = false;
      return;
    }

    final token = await AuthTokenStorage.instance.readAccessToken();
    if (token == null || token.isEmpty) {
      // Signed out, or mid token refresh. Retry rather than give up — stop() is
      // what ends this loop on a real logout.
      _scheduleReconnect();
      return;
    }

    try {
      final channel = WebSocketChannel.connect(
        Uri.parse('$url?token=${Uri.encodeQueryComponent(token)}'),
      );
      _channel = channel;
      _subscription = channel.stream.listen(
        _onFrame,
        onError: (Object error) {
          debugPrint('Realtime: socket error ($error)');
          _onDisconnected();
        },
        onDone: () {
          // 4401 is the server's "token rejected" code; anything else is an
          // ordinary drop. Both reconnect, but only one is worth reading in a log.
          final code = channel.closeCode;
          debugPrint(
            code == 4401
                ? 'Realtime: token rejected (4401)'
                : 'Realtime: socket closed (code $code)',
          );
          _onDisconnected();
        },
        cancelOnError: true,
      );

      _connected = true;
      _attempt = 0;
      debugPrint('Realtime: connected');

      if (_hasConnected) {
        // A reconnect: events during the gap were missed and the socket has no
        // replay, so re-read once to re-establish the truth. Skipped on the
        // first connect, when the screen is already loading everything.
        unawaited(WhatsAppChatUnreadPoller.instance.refresh());
        SyncInvalidation.instance.emitResumeRefresh();
      }
      _hasConnected = true;
      // Subscriptions live on the connection, so a reconnect starts with none.
      for (final id in _subscribedConversations) {
        _send({'action': 'subscribe', 'conversation': id});
      }
      WhatsAppChatUnreadPoller.instance.onRealtimeConnectionChanged();
      _statusController.add(true);

      _startHeartbeat();
    } catch (e) {
      debugPrint('Realtime: connect failed ($e)');
      _onDisconnected();
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _send({'action': 'heartbeat'});
    });
  }

  void _send(Map<String, dynamic> payload) {
    if (!_connected) return;
    try {
      _channel?.sink.add(jsonEncode(payload));
    } catch (e) {
      debugPrint('Realtime: send failed ($e)');
    }
  }

  void _onFrame(dynamic raw) {
    Map<String, dynamic>? frame;
    try {
      final decoded = jsonDecode(raw is String ? raw : utf8.decode(raw as List<int>));
      if (decoded is Map<String, dynamic>) frame = decoded;
    } catch (_) {
      frame = null;
    }
    if (frame == null) return;

    final scope = frame['scope']?.toString();
    if (scope == null || scope.isEmpty) return;

    if (scope == 'presence') {
      final conversation = (frame['conversation'] as num?)?.toInt();
      final userId = (frame['user_id'] as num?)?.toInt();
      final state = frame['state']?.toString();
      if (conversation != null && userId != null && state != null) {
        _presenceController.add(
          RealtimePresence(
            conversationId: conversation,
            userId: userId,
            state: state,
          ),
        );
      }
      // Ephemeral, and never a reason to refetch anything.
      return;
    }

    if (scope == 'conversation') {
      // One chat thread moved — a message, or one participant's read cursor.
      //
      // Routed straight to the bus rather than through the digest, because the
      // digest cannot see this event: its `tenant_chat` slice counts messages,
      // and a read cursor moving produces none. Going the long way round would
      // therefore cost a request and still report nothing, leaving the "seen"
      // tick to wait for the thread's own 120s backstop poll.
      SyncInvalidation.instance.emit({'invalidate': 'tenant_chat:messages'});
      return;
    }

    // A version bump. Its value is not read: it means "something changed", and
    // the digest is what says what — refreshing it updates every badge holder
    // and emits the slice invalidations the cubits already listen for.
    unawaited(WhatsAppChatUnreadPoller.instance.refresh());
  }

  void _onDisconnected() {
    _connected = false;
    WhatsAppChatUnreadPoller.instance.onRealtimeConnectionChanged();
    _statusController.add(false);
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_started) return;
    _reconnectTimer?.cancel();
    // Exponential with jitter: without it, every device in a company reconnects
    // in lockstep after a server restart and stampedes it.
    final base = _minBackoff * pow(2, _attempt).toInt();
    final capped = base > _maxBackoff ? _maxBackoff : base;
    final jittered = Duration(
      milliseconds: (capped.inMilliseconds * (0.5 + _random.nextDouble())).round(),
    );
    _attempt = min(_attempt + 1, 10);
    _reconnectTimer = Timer(jittered, () => unawaited(_connect()));
  }
}


/// One peer's ephemeral activity in a chat thread, delivered over the socket.
class RealtimePresence {
  const RealtimePresence({
    required this.conversationId,
    required this.userId,
    required this.state,
  });

  final int conversationId;
  final int userId;
  final String state;
}
