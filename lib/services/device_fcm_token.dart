import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Must match [NotificationService] cache key (`fcm_token`).
const String kSharedPrefsFcmTokenKey = 'fcm_token';

/// Wired from [NotificationService.initialize] so in-memory `_fcmToken` is cleared too.
VoidCallback? onLocalFcmRegistrationCleared;

/// Drops this install's FCM registration locally so pushes stop reaching the device
/// after logout. Call after clearing the logged-in preference (``is_logged_in``).
Future<void> clearLocalPushRegistrationAfterLogout() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(kSharedPrefsFcmTokenKey);

  if (Firebase.apps.isNotEmpty) {
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('clearLocalPushRegistrationAfterLogout.deleteToken failed: $e');
    }
  }
  try {
    onLocalFcmRegistrationCleared?.call();
  } catch (e, st) {
    debugPrint('onLocalFcmRegistrationCleared: $e $st');
  }
}

/// Resolves the device's FCM token for server unregister flows without importing
/// [NotificationService] (avoids circular imports via [ApiService]).
Future<String?> resolveDeviceFcmTokenForUnregister() async {
  final prefs = await SharedPreferences.getInstance();
  final cached = prefs.getString(kSharedPrefsFcmTokenKey)?.trim() ?? '';
  if (cached.isNotEmpty) return cached;

  if (Firebase.apps.isEmpty) return null;
  try {
    final fresh = await FirebaseMessaging.instance.getToken();
    final t = fresh?.trim() ?? '';
    if (t.isEmpty) return null;
    await prefs.setString(kSharedPrefsFcmTokenKey, t);
    return t;
  } catch (e) {
    debugPrint('resolveDeviceFcmTokenForUnregister: $e');
    return null;
  }
}
