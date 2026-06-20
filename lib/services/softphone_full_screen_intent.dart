import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android 14+ full-screen intent permission helper.
class SoftphoneFullScreenIntent {
  SoftphoneFullScreenIntent._();
  static const _channel = MethodChannel('com.loopcrm.mobile/android_call');

  static Future<bool> canUseFullScreenIntent() async {
    if (!Platform.isAndroid) return true;
    try {
      final ok = await _channel.invokeMethod<bool>('canUseFullScreenIntent');
      return ok ?? true;
    } catch (e) {
      debugPrint('FSI check failed: $e');
      return true;
    }
  }

  static Future<void> openFullScreenIntentSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openFullScreenIntentSettings');
    } catch (e) {
      debugPrint('FSI settings open failed: $e');
    }
  }
}
