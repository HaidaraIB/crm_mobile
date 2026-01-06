class AppConstants {
  // API Base URL
  // Use 10.0.2.2 for Android emulator (maps to host machine's localhost)
  // Use 127.0.0.1 for iOS simulator or web
  // For physical devices, use your computer's local IP address (e.g., http://192.168.1.x:8000/api)
  static const String baseUrl = 'http://10.0.2.2:8000/api';
  
  // Storage Keys
  static const String themeKey = 'theme';
  static const String languageKey = 'language';
  static const String accessTokenKey = 'accessToken';
  static const String refreshTokenKey = 'refreshToken';
  static const String currentUserKey = 'currentUser';
  static const String isLoggedInKey = 'isLoggedIn';
  
  // Primary Color (Purple)
  static const int primaryColorValue = 0xFF9333EA;
  
  // App Version
  static const String appVersion = '1.0.0';
}


