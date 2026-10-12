import 'dart:async';

import 'realtime_channel.dart';

/// Baseline refresh interval for screens that also refresh from [SyncInvalidation].
///
/// **30s with no socket, 120s with one.** Three signals now emit on this bus —
/// an FCM push, the digest's slice counters, and a realtime frame — so a screen
/// normally learns about new data long before this fires.
///
/// The floor is stretched rather than removed, and only while a connection is
/// actually live. A socket that is open but silently not delivering is a failure
/// the client cannot detect on its own, and this timer is the only thing that
/// would notice. With no socket it returns to exactly the original cadence, so
/// realtime being off or unreachable costs latency and nothing else.
///
/// A getter rather than a const so each screen picks the right value when it
/// arms its timer. [SyncFallbackTimer] re-arms when the socket connects or
/// drops; a raw `Timer.periodic` would keep the duration it captured.
Duration get kSyncFallbackPollInterval => RealtimeChannel.instance.isConnected
    ? const Duration(seconds: 120)
    : const Duration(seconds: 30);

/// Fallback poll that follows the socket.
///
/// `Timer.periodic` captures its duration once. Without this, a screen that
/// mounted before the socket connected would keep polling every 30s for the
/// rest of its life.
class SyncFallbackTimer {
  SyncFallbackTimer(this._tick);

  final void Function() _tick;
  Timer? _timer;
  Duration? _armedFor;
  StreamSubscription<bool>? _sub;

  void start() {
    _timer?.cancel();
    _armedFor = kSyncFallbackPollInterval;
    _timer = Timer.periodic(_armedFor!, (_) => _tick());
    _sub ??= RealtimeChannel.instance.connectionChanges.listen((_) {
      if (_timer == null) return;
      if (_armedFor == kSyncFallbackPollInterval) return;
      start();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _armedFor = null;
    _sub?.cancel();
    _sub = null;
  }
}

/// Thin FCM `invalidate` keys (e.g. `whatsapp:conversations`).
class SyncInvalidation {
  SyncInvalidation._();
  static final SyncInvalidation instance = SyncInvalidation._();

  final StreamController<Map<String, String>> _controller =
      StreamController<Map<String, String>>.broadcast();

  Stream<Map<String, String>> get stream => _controller.stream;

  void emit(Map<String, String> event) {
    if (event.isEmpty) return;
    _controller.add(event);
  }

  void emitResumeRefresh() {
    emit({'invalidate': 'whatsapp:conversations'});
    emit({'invalidate': 'tenant_chat:messages'});
    emit({'invalidate': 'social:conversations'});
  }
}
