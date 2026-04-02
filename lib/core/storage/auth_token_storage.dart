import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// تخزين آمن لـ JWT (access/refresh) ولقطة المستخدم JSON بعد فك مظروف الـ API
/// (الحمولة الفعلية غالباً تحت `data` — يُخزَّن ما يُعرَض للتطبيق فقط).
/// يهاجر تلقائياً من [SharedPreferences] إن وُجدت قيم قديمة.
class AuthTokenStorage {
  AuthTokenStorage._();
  static final AuthTokenStorage instance = AuthTokenStorage._();

  /// مفتاح منفصل عن مفاتيح الرموز لتجنب التعارض مع أسماء قديمة في prefs.
  static const String _userJsonSecureKey = 'crm_secure_user_json';

  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Future<String?> readAccessToken() async {
    final v = await _secure.read(key: AppConstants.accessTokenKey);
    if (v != null && v.trim().isNotEmpty) {
      return v;
    }
    return _migrateLegacyToken(AppConstants.accessTokenKey);
  }

  Future<String?> readRefreshToken() async {
    final v = await _secure.read(key: AppConstants.refreshTokenKey);
    if (v != null && v.trim().isNotEmpty) {
      return v;
    }
    return _migrateLegacyToken(AppConstants.refreshTokenKey);
  }

  Future<String?> _migrateLegacyToken(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(key);
    if (legacy != null && legacy.trim().isNotEmpty) {
      await _secure.write(key: key, value: legacy);
      await prefs.remove(key);
      return legacy;
    }
    return null;
  }

  Future<void> writeAccessToken(String token) async {
    await _secure.write(key: AppConstants.accessTokenKey, value: token);
  }

  Future<void> writeRefreshToken(String token) async {
    await _secure.write(key: AppConstants.refreshTokenKey, value: token);
  }

  Future<void> writeTokens({
    required String access,
    required String refresh,
  }) async {
    await _secure.write(key: AppConstants.accessTokenKey, value: access);
    await _secure.write(key: AppConstants.refreshTokenKey, value: refresh);
  }

  /// JSON للمستخدم كما يُعاد من `UserModel.toJson()` بعد جلب/تحديث من الـ API.
  Future<String?> readUserJson() async {
    final v = await _secure.read(key: _userJsonSecureKey);
    if (v != null && v.trim().isNotEmpty) {
      return v;
    }
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(AppConstants.currentUserKey);
    if (legacy != null && legacy.trim().isNotEmpty) {
      await writeUserJson(legacy);
      await prefs.remove(AppConstants.currentUserKey);
    }
    return legacy;
  }

  Future<void> writeUserJson(String json) async {
    await _secure.write(key: _userJsonSecureKey, value: json);
  }

  /// يمسح الرموز والمستخدم من التخزين الآمن ومن SharedPreferences (إن بقيت نسخة قديمة).
  Future<void> clear() async {
    await _secure.delete(key: AppConstants.accessTokenKey);
    await _secure.delete(key: AppConstants.refreshTokenKey);
    await _secure.delete(key: _userJsonSecureKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.accessTokenKey);
    await prefs.remove(AppConstants.refreshTokenKey);
    await prefs.remove(AppConstants.currentUserKey);
  }
}
