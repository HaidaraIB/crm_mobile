import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// إعدادات التطبيق وعنوان الـ API ومفتاح العميل.
///
/// **Base URL:** يُفضَّل `--dart-define=BASE_URL=https://host/api/v1` أو `BASE_URL` في `.env`.
///
/// **مفتاح الموبايل:** يُرسل كـ `X-API-Key` — من `--dart-define=API_KEY_MOBILE=...`
/// أو `API_KEY_MOBILE` / `API_KEY` في `.env`.
class AppConstants {
  /// Global navigator key for app-wide navigation (e.g. auto-logout to login).
  /// Set from [MyApp] in main.dart.
  static GlobalKey<NavigatorState>? navigatorKey;

  static String _trimTrailingSlash(String url) {
    var u = url.trim();
    if (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  /// Canonical API prefix: `/api/v1/` (see CRM-api-1 `urls.py`).
  static String get baseUrl {
    const fromDefine = String.fromEnvironment('BASE_URL');
    if (fromDefine.isNotEmpty) {
      return _trimTrailingSlash(fromDefine);
    }
    final fromEnv = dotenv.env['BASE_URL'];
    if (fromEnv != null && fromEnv.trim().isNotEmpty) {
      return _trimTrailingSlash(fromEnv);
    }
    return 'http://10.0.2.2:8000/api/v1';
  }

  /// مفتاح التطبيق للرأس `X-API-Key` (قيمة `API_KEY_MOBILE` على الخادم).
  static String get apiKey => mobileApiKey;

  static String get mobileApiKey {
    const fromDefine = String.fromEnvironment('API_KEY_MOBILE');
    if (fromDefine.isNotEmpty) {
      return fromDefine;
    }
    return dotenv.env['API_KEY_MOBILE'] ??
        dotenv.env['API_KEY'] ??
        '';
  }

  // Storage Keys
  static const String themeKey = 'theme';
  static const String languageKey = 'language';
  static const String accessTokenKey = 'accessToken';
  static const String refreshTokenKey = 'refreshToken';
  static const String currentUserKey = 'currentUser';
  static const String isLoggedInKey = 'isLoggedIn';
  static const String hasSeenOnboardingKey = 'hasSeenOnboarding';
  static const String pendingSubscriptionIdKey = 'pendingSubscriptionId';
  static const String notificationFilterKey = 'notificationFilter';

  // Primary Color (Purple)
  static const int primaryColorValue = 0xFF9333EA;

  /// Legacy display string; prefer [PackageInfo] from `package_info_plus`.
  static const String appVersion = '1.0.0';

  /// Optional fallback store links if the API omits them (`--dart-define` or `.env`).
  static String get storeUrlAndroidFallback {
    const fromDefine = String.fromEnvironment('STORE_URL_ANDROID');
    if (fromDefine.isNotEmpty) return fromDefine.trim();
    return (dotenv.env['STORE_URL_ANDROID'] ?? '').trim();
  }

  static String get storeUrlIosFallback {
    const fromDefine = String.fromEnvironment('STORE_URL_IOS');
    if (fromDefine.isNotEmpty) return fromDefine.trim();
    return (dotenv.env['STORE_URL_IOS'] ?? '').trim();
  }
}
