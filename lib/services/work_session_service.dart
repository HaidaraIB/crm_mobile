import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/storage/auth_token_storage.dart';
import 'api_service.dart';

enum WorkSessionState { off, active, paused }

@immutable
class WorkSessionSnapshot {
  const WorkSessionSnapshot({
    this.state = WorkSessionState.off,
    this.todaySeconds = 0,
    this.idleTimeoutMinutes = 10,
  });

  final WorkSessionState state;
  final int todaySeconds;
  final int idleTimeoutMinutes;

  WorkSessionSnapshot copyWith({
    WorkSessionState? state,
    int? todaySeconds,
    int? idleTimeoutMinutes,
  }) =>
      WorkSessionSnapshot(
        state: state ?? this.state,
        todaySeconds: todaySeconds ?? this.todaySeconds,
        idleTimeoutMinutes: idleTimeoutMinutes ?? this.idleTimeoutMinutes,
      );
}

/// Measured CRM usage time on mobile — the counterpart of the web tracker.
///
/// Mobile has no mouse, so "activity" is any pointer event while the app is in the
/// foreground (a root [Listener] in main.dart feeds [markActivity]). Backgrounding
/// stops the loop entirely, which is correct: the app is not being used. Nothing has
/// to be flushed on the way out, because the server credits retroactively — the most
/// that is ever lost is one ping interval.
///
/// Accrual itself lives on the server; this only decides *when* to ping.
class WorkSessionService {
  WorkSessionService._();

  static final WorkSessionService instance = WorkSessionService._();

  /// Shorter than the ping interval so the idle transition is prompt.
  static const Duration _tickInterval = Duration(seconds: 15);
  static const Duration _defaultPingInterval = Duration(seconds: 60);
  static const Duration _activityThrottle = Duration(seconds: 1);

  final ValueNotifier<WorkSessionSnapshot> snapshot =
      ValueNotifier<WorkSessionSnapshot>(const WorkSessionSnapshot());

  Timer? _timer;
  DateTime _lastActivity = DateTime.now();
  DateTime? _lastPing;
  Duration _pingInterval = _defaultPingInterval;
  Duration _idleTimeout = const Duration(minutes: 10);
  bool _pingInFlight = false;
  bool _tracked = false;

  WorkSessionState get state => snapshot.value.state;

  /// Called from the root pointer listener. Cheap by design: it is hit on every
  /// touch and drag frame, so it must not allocate or notify.
  void markActivity() {
    final now = DateTime.now();
    if (now.difference(_lastActivity) < _activityThrottle) return;
    _lastActivity = now;
  }

  /// Start (or restart) tracking. Safe to call on every app resume.
  Future<void> start() async {
    stop();
    _tracked = await _isTrackedUser();
    if (!_tracked) {
      _setState(WorkSessionState.off);
      return;
    }

    _lastActivity = DateTime.now();
    _lastPing = null; // ping on the first tick
    _setState(WorkSessionState.active);
    _tick();
    _timer = Timer.periodic(_tickInterval, (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// User acknowledged the idle dialog.
  void resume() {
    if (!_tracked) return;
    final now = DateTime.now();
    _lastActivity = now;
    _lastPing = now;
    _setState(WorkSessionState.active);
  }

  /// Local pre-check only — cheap enough to skip the loop for roles that can never
  /// accrue. It is deliberately permissive when the company flag is *unknown*: the
  /// login payload carries `company` as a bare id, so the flag isn't available until
  /// `/users/me` has been stored. Pinging once and letting the server answer
  /// `tracking_enabled: false` (which stops the loop in [_applyStatus]) is more
  /// robust than silently never starting.
  Future<bool> _isTrackedUser() async {
    final storedUserJson = await AuthTokenStorage.instance.readUserJson();
    if (storedUserJson == null || storedUserJson.trim().isEmpty) return false;
    try {
      final decoded = jsonDecode(storedUserJson);
      if (decoded is! Map<String, dynamic>) return false;
      if (!ApiService.roleTracksWorkHours(decoded['role']?.toString())) return false;
      final company = decoded['company'];
      if (company is Map && company['work_hours_tracking_enabled'] == false) {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  void _tick() {
    if (snapshot.value.state == WorkSessionState.paused) return;
    final now = DateTime.now();

    if (now.difference(_lastActivity) >= _idleTimeout) {
      _setState(WorkSessionState.paused);
      return;
    }
    final lastPing = _lastPing;
    if (lastPing == null || now.difference(lastPing) >= _pingInterval) {
      unawaited(_ping());
    }
  }

  Future<void> _ping() async {
    if (_pingInFlight) return;
    _pingInFlight = true;
    try {
      final data = await ApiService().sendWorkSessionPing();
      if (data == null) {
        // Network hiccup: leave _lastPing alone and retry on the next tick rather
        // than pausing or retry-storming.
        return;
      }
      _lastPing = DateTime.now();
      _applyStatus(data);
    } finally {
      _pingInFlight = false;
    }
  }

  void _applyStatus(Map<String, dynamic> data) {
    if (data['tracking_enabled'] == false) {
      _tracked = false;
      stop();
      _setState(WorkSessionState.off);
      return;
    }

    final interval = (data['ping_interval_seconds'] as num?)?.toInt();
    if (interval != null && interval > 0) {
      _pingInterval = Duration(seconds: interval);
    }
    final idleMinutes = (data['idle_timeout_minutes'] as num?)?.toInt();
    if (idleMinutes != null && idleMinutes > 0) {
      _idleTimeout = Duration(minutes: idleMinutes);
    }

    snapshot.value = snapshot.value.copyWith(
      todaySeconds: (data['today_seconds'] as num?)?.toInt() ?? snapshot.value.todaySeconds,
      idleTimeoutMinutes: idleMinutes ?? snapshot.value.idleTimeoutMinutes,
    );
  }

  void _setState(WorkSessionState next) {
    if (snapshot.value.state == next) return;
    snapshot.value = snapshot.value.copyWith(state: next);
  }
}
