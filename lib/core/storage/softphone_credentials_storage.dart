import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure on-device cache for softphone SIP credentials (never SharedPreferences).
class SoftphoneCredentialsStorage {
  SoftphoneCredentialsStorage._();
  static final SoftphoneCredentialsStorage instance = SoftphoneCredentialsStorage._();

  static const String _sipPasswordKey = 'crm_softphone_sip_password';

  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Future<void> writeSipPassword(String password) async {
    if (password.isEmpty) return;
    await _secure.write(key: _sipPasswordKey, value: password);
  }

  Future<String?> readSipPassword() => _secure.read(key: _sipPasswordKey);

  Future<void> clear() async {
    await _secure.delete(key: _sipPasswordKey);
  }
}
