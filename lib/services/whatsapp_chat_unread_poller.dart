import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'whatsapp_chat_unread_holder.dart';

/// Polls `GET /whatsapp/unread-count/` so the home app-bar badge works without opening the list.
class WhatsAppChatUnreadPoller {
  WhatsAppChatUnreadPoller._();
  static final WhatsAppChatUnreadPoller instance = WhatsAppChatUnreadPoller._();

  final ApiService _api = ApiService();
  Timer? _timer;
  bool _foreground = true;
  bool _started = false;
  /// Set after a 403: this account cannot use WhatsApp chats, so stay off until
  /// the next sign-in (`reset()`), instead of re-asking on every resume.
  bool _accessDenied = false;

  void start() {
    if (_started || _accessDenied) return;
    _started = true;
    unawaited(refresh());
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_foreground) unawaited(refresh());
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  /// Clear the access-denied latch (call on sign-in / user switch).
  void reset() {
    _accessDenied = false;
  }

  void setForeground(bool value) {
    _foreground = value;
    if (value && _started && !_accessDenied) unawaited(refresh());
  }

  Future<void> refresh() async {
    try {
      final n = await _api.getWhatsAppUnreadCount();
      WhatsAppChatUnreadHolder.setTotal(n);
    } on WhatsAppAccessDeniedException {
      // Access was switched off for this account — retrying every 15s only
      // spams the server log. Next sign-in re-evaluates and may start again.
      _accessDenied = true;
      WhatsAppChatUnreadHolder.setTotal(0);
      stop();
    } catch (e) {
      debugPrint('WhatsApp unread poll failed: $e');
    }
  }
}
