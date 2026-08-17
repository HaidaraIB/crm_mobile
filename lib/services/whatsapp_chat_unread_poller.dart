import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'team_chat_unread_holder.dart';
import 'whatsapp_chat_unread_holder.dart';

/// Polls `GET /sync/digest/` so home badges work without opening chat lists.
class WhatsAppChatUnreadPoller {
  WhatsAppChatUnreadPoller._();
  static final WhatsAppChatUnreadPoller instance = WhatsAppChatUnreadPoller._();

  final ApiService _api = ApiService();
  Timer? _timer;
  bool _foreground = true;
  bool _started = false;
  bool _accessDenied = false;

  void start() {
    if (_started) return;
    _started = true;
    unawaited(refresh());
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_foreground) unawaited(refresh());
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  void reset() {
    _accessDenied = false;
  }

  void setForeground(bool value) {
    _foreground = value;
    if (value && _started) unawaited(refresh());
  }

  Future<void> refresh() async {
    try {
      final data = await _api.getSyncDigest();
      if (data.isEmpty) return;
      TeamChatUnreadHolder.setTotal((data['tenant_chat_unread'] as num?)?.toInt() ?? 0);
      final wa = data['whatsapp_unread'];
      if (wa == null) {
        if (!_accessDenied) {
          _accessDenied = true;
          WhatsAppChatUnreadHolder.setTotal(0);
        }
        return;
      }
      _accessDenied = false;
      WhatsAppChatUnreadHolder.setTotal((wa as num?)?.toInt() ?? 0);
    } catch (e) {
      debugPrint('Sync digest poll failed: $e');
    }
  }
}
