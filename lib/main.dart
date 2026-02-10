import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/bloc/theme/theme_bloc.dart';
import 'core/bloc/language/language_bloc.dart';
import 'core/theme/app_theme.dart';
import 'core/localization/app_localizations.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/login/login_screen.dart';
import 'screens/register/register_screen.dart';
import 'screens/two_factor_auth/two_factor_auth_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/notification_service.dart';
import 'services/notification_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (optional - only if google-services.json exists)
  bool firebaseInitialized = false;
  try {
    await Firebase.initializeApp();
    firebaseInitialized = true;
    debugPrint('✓ Firebase initialized successfully');
  } catch (e) {
    debugPrint('⚠ Warning: Firebase initialization failed: $e');
    debugPrint('⚠ This is normal if google-services.json is not configured yet');
    debugPrint('⚠ Local notifications will still work');
    firebaseInitialized = false;
  }
  
  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
    // Debug: Print loaded API key (first 10 chars only for security)
    final apiKey = dotenv.env['API_KEY'] ?? '';
    final baseUrl = dotenv.env['BASE_URL'] ?? '';
    if (apiKey.isNotEmpty) {
      debugPrint('✓ API Key loaded: ${apiKey.substring(0, 10)}...');
    } else {
      debugPrint('⚠ Warning: API_KEY is empty in .env file');
    }
    if(baseUrl.isNotEmpty) {
      debugPrint('✓ Base URL loaded: $baseUrl');
    } else {
      debugPrint('⚠ Warning: BASE_URL is empty in .env file');
    }
  } catch (e) {
    // If .env file doesn't exist, continue with default values
    debugPrint('⚠ Warning: .env file not found. Using default values.');
    debugPrint('Error: $e');
  }
  
  // Initialize Notification Service (works even without Firebase)
  try {
    await NotificationService().initialize();
    if (firebaseInitialized) {
      debugPrint('✓ Notification Service initialized with FCM support');
    } else {
      debugPrint('✓ Notification Service initialized (local notifications only)');
    }
  } catch (e, stackTrace) {
    debugPrint('⚠ Warning: Notification Service initialization failed: $e');
    debugPrint('Stack trace: $stackTrace');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // GlobalKey للـ Navigator للوصول إليه من أي مكان
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  @override
  void initState() {
    super.initState();
    _setupNotificationListener();
  }

  /// إعداد مستمع الإشعارات
  void _setupNotificationListener() {
    NotificationService().notificationStream.listen((payload) {
      // التنقل بناءً على نوع الإشعار
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigatorKey.currentState != null) {
          NotificationRouter.navigateFromNotification(navigatorKey.currentState!.context, payload);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => ThemeBloc()..add(const LoadTheme()),
        ),
        BlocProvider(
          create: (context) => LanguageBloc()..add(const LoadLanguage()),
        ),
      ],
      child: BlocBuilder<LanguageBloc, LanguageState>(
        builder: (context, languageState) {
          return BlocBuilder<ThemeBloc, ThemeState>(
            builder: (context, themeState) {
              return MaterialApp(
                navigatorKey: navigatorKey,
                title: 'LOOP CRM',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightThemeFor(languageState.locale),
                darkTheme: AppTheme.darkThemeFor(languageState.locale),
                themeMode: themeState.themeMode,
                locale: languageState.locale,
                supportedLocales: const [
                  Locale('en'),
                  Locale('ar'),
                ],
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                routes: {
                  '/login': (context) => const LoginScreen(),
                  '/register': (context) => const RegisterScreen(),
                  '/home': (context) => const HomeScreen(),
                  '/settings': (context) => const SettingsScreen(),
                  '/profile': (context) => const ProfileScreen(),
                  '/2fa': (context) {
                    // Get username, password, and token from arguments
                    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
                    if (args != null) {
                      return TwoFactorAuthScreen(
                        username: args['username'] as String,
                        password: args['password'] as String,
                        token: args['token'] as String?,
                      );
                    }
                    // Fallback to login if no arguments
                    return const LoginScreen();
                  },
                },
                home: const SplashScreen(),
              );
            },
          );
        },
      ),
    );
  }
}
