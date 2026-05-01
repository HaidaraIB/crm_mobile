import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'core/constants/app_constants.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/bloc/theme/theme_bloc.dart';
import 'core/bloc/language/language_bloc.dart';
import 'core/theme/app_theme.dart';
import 'core/localization/app_localizations.dart';
import 'core/utils/app_locales.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/login/login_screen.dart';
import 'screens/two_factor_auth/two_factor_auth_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/leads/lead_profile_screen.dart';
import 'screens/leads/all_leads_screen.dart';
import 'screens/calendar/calendar_screen.dart';
import 'screens/deals/deals_screen.dart';
import 'screens/deals/view_deal_by_id_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'services/notification_service.dart';
import 'services/notification_router.dart';
import 'services/api_service.dart';
import 'core/utils/snackbar_helper.dart';

int? _routeIntArguments(Object? args) {
  if (args == null) return null;
  if (args is int) return args;
  if (args is num) return args.toInt();
  if (args is String) return int.tryParse(args.trim());
  return null;
}

void main() async {
  // No console noise in release/store builds; debug/profile keep debugPrint.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
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
    // Effective values: --dart-define=API_KEY_MOBILE / BASE_URL override .env
    final apiKey = AppConstants.mobileApiKey;
    final baseUrl = AppConstants.baseUrl;
    if (apiKey.isNotEmpty) {
      final n = apiKey.length < 10 ? apiKey.length : 10;
      debugPrint('✓ X-API-Key (mobile) loaded: ${apiKey.substring(0, n)}...');
    } else {
      debugPrint(
        '⚠ Warning: API_KEY_MOBILE / API_KEY empty — set .env or --dart-define=API_KEY_MOBILE=...',
      );
    }
    debugPrint('✓ Base URL: $baseUrl');
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

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  // GlobalKey للـ Navigator للوصول إليه من أي مكان
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  Timer? _presenceTimer;
  Timer? _reachabilityTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _reachabilityCheckInFlight = false;
  bool _reachabilitySeeded = false;
  bool _lastReachable = true;
  
  @override
  void initState() {
    super.initState();
    AppConstants.navigatorKey = navigatorKey;
    WidgetsBinding.instance.addObserver(this);
    _setupNotificationListener();
    _startPresenceHeartbeat();
    _setupConnectivityListener();
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    _reachabilityTimer?.cancel();
    _connectivitySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // عند استئناف التطبيق من الخلفية، إعادة إرسال FCM token إن وُجد (لمستخدمي iOS الذين تأخر توكنهم)
    if (state == AppLifecycleState.resumed) {
      NotificationService().sendTokenToServerIfLoggedIn();
      ApiService().sendPresenceHeartbeat(source: 'mobile');
      _startPresenceHeartbeat();
      unawaited(_runReachabilityCheck());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _presenceTimer?.cancel();
    }
  }

  void _startPresenceHeartbeat() {
    _presenceTimer?.cancel();
    ApiService().sendPresenceHeartbeat(source: 'mobile');
    _presenceTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      ApiService().sendPresenceHeartbeat(source: 'mobile');
    });
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((_) {
      unawaited(_runReachabilityCheck());
    });

    _reachabilityTimer?.cancel();
    _reachabilityTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(_runReachabilityCheck());
    });

    unawaited(_runReachabilityCheck());
  }

  /// Local interface can be "connected" while there is no real internet (same issue as `navigator.onLine` on web).
  Future<bool> _probeHasInternet() async {
    const timeout = Duration(seconds: 5);
    final uris = <Uri>[
      Uri.parse('https://www.gstatic.com/generate_204'),
      Uri.parse('https://cp.cloudflare.com/generate_204'),
    ];
    for (final uri in uris) {
      try {
        final r = await http.get(uri).timeout(timeout);
        if (r.statusCode == 204 || r.statusCode == 200) return true;
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  Future<void> _runReachabilityCheck() async {
    if (_reachabilityCheckInFlight) return;
    _reachabilityCheckInFlight = true;
    try {
      final results = await Connectivity().checkConnectivity();
      final hasInterface = results.any((c) => c != ConnectivityResult.none);
      final reachable = hasInterface && await _probeHasInternet();
      _applyReachability(reachable);
    } finally {
      _reachabilityCheckInFlight = false;
    }
  }

  void _applyReachability(bool reachable) {
    if (!_reachabilitySeeded) {
      _reachabilitySeeded = true;
      _lastReachable = reachable;
      return;
    }
    if (_lastReachable == reachable) return;
    _lastReachable = reachable;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      final loc = AppLocalizations.of(ctx);
      if (!reachable) {
        final title = loc?.translate('noInternetConnection') ?? 'No Internet Connection';
        final body = loc?.translate('noInternetMessage') ??
            'Please check your internet connection and try again.';
        SnackbarHelper.showError(ctx, '$title. $body');
      } else {
        SnackbarHelper.showSuccess(
          ctx,
          loc?.translate('connectivityBackOnline') ?? 'Internet connection is back online.',
        );
      }
    });
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
                  AppLocales.english,
                  AppLocales.arabic,
                ],
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                routes: {
                  '/login': (context) {
                    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
                    final reason = args?['reason'] as String?;
                    return LoginScreen(logoutReason: reason);
                  },
                  // Registration for businesses/organizations removed for App Store compliance (Guideline 3.1.1).
                  // Users must sign up via web; app is for existing account login only.
                  '/register': (context) => const LoginScreen(),
                  '/home': (context) => const HomeScreen(),
                  '/settings': (context) => const SettingsScreen(),
                  '/profile': (context) => const ProfileScreen(),
                  '/leads': (context) => const AllLeadsScreen(),
                  '/leads/details': (context) {
                    final id = _routeIntArguments(
                      ModalRoute.of(context)?.settings.arguments,
                    );
                    if (id == null) {
                      return const Scaffold(
                        body: Center(child: Text('Invalid lead')),
                      );
                    }
                    return LeadProfileScreen(leadId: id);
                  },
                  '/calendar': (context) => const CalendarScreen(),
                  '/deals': (context) => const DealsScreen(),
                  '/deals/view': (context) {
                    final id = _routeIntArguments(
                      ModalRoute.of(context)?.settings.arguments,
                    );
                    if (id == null) {
                      return const Scaffold(
                        body: Center(child: Text('Invalid deal')),
                      );
                    }
                    return ViewDealByIdScreen(dealId: id);
                  },
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
