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

  void start() {
    if (_started) return;
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

  void setForeground(bool value) {
    _foreground = value;
    if (value) unawaited(refresh());
  }

  Future<void> refresh() async {
    try {
      final n = await _api.getWhatsAppUnreadCount();
      WhatsAppChatUnreadHolder.setTotal(n);
    } catch (e) {
      debugPrint('WhatsApp unread poll failed: $e');
    }
  }
}
