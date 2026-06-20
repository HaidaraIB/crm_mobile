import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'api_service.dart';

/// Receives iOS VoIP push token updates from native PushKit via method channel.
class SoftphoneVoipBridge {
  SoftphoneVoipBridge._();
  static final SoftphoneVoipBridge instance = SoftphoneVoipBridge._();

  static const _channel = MethodChannel('com.loopcrm.mobile/voip');
  bool _listening = false;

  void ensureListening() {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'voipTokenUpdated':
          final token = call.arguments as String? ?? '';
          if (token.isEmpty) {
            try {
              await ApiService().unregisterSoftphoneDevice(platform: 'ios');
            } catch (e) {
              debugPrint('VoIP token invalidate unregister failed: $e');
            }
          } else {
            try {
              await ApiService().registerSoftphoneDevice(
                platform: 'ios',
                voipToken: token,
              );
            } catch (e) {
              debugPrint('VoIP token register failed: $e');
            }
          }
          break;
        case 'incomingVoipPush':
          final data = Map<String, dynamic>.from(call.arguments as Map? ?? {});
          unawaited(SoftphonePushHandlerBridge.handleNativePush(data));
          break;
        default:
          break;
      }
    });
  }
}

/// Thin wrapper to avoid circular imports between voip bridge and push handler.
class SoftphonePushHandlerBridge {
  static Future<void> Function(Map<String, dynamic> data, {bool fromNativeIos})?
      _handler;

  static void register(
    Future<void> Function(Map<String, dynamic> data, {bool fromNativeIos}) handler,
  ) {
    _handler = handler;
  }

  static Future<void> handleNativePush(Map<String, dynamic> data) async {
    await _handler?.call(data, fromNativeIos: true);
  }
}
