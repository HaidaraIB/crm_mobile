import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // API Base URL - Loaded from environment variables
  // Make sure to create a .env file in the root directory with BASE_URL
  // For Android emulator: BASE_URL=http://10.0.2.2:8000/api
  // For iOS simulator: BASE_URL=http://127.0.0.1:8000/api
  // For physical devices: BASE_URL=http://192.168.1.x:8000/api
  // For production: BASE_URL=https://api.yourdomain.com/api
  static String get baseUrl => dotenv.env['BASE_URL'] ?? 'http://10.0.2.2:8000/api';
  
  // API Key for application authentication
  // This key identifies the mobile app to the backend
  // Make sure to add API_KEY to your .env file
  static String get apiKey => dotenv.env['API_KEY'] ?? '';
  
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


