import 'package:flutter/foundation.dart';
import 'package:crm_mobile/main.dart';
import 'package:crm_mobile/screens/onboarding/onboarding_screen.dart';
import 'package:crm_mobile/screens/splash/splash_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorage = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  const connectivity = MethodChannel('dev.fluttercommunity.plus/connectivity');
  const connectivityEvents = MethodChannel(
    'dev.fluttercommunity.plus/connectivity_status',
  );

  setUp(() {
    // Fresh install: no language, no login, onboarding not yet seen.
    SharedPreferences.setMockInitialValues({});

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    // Empty keystore, and a connected network, so startup never touches a
    // real platform plugin.
    messenger.setMockMethodCallHandler(secureStorage, (call) async {
      switch (call.method) {
        case 'readAll':
          return <String, String>{};
        case 'containsKey':
          return false;
        default:
          return null;
      }
    });
    messenger.setMockMethodCallHandler(connectivity, (call) async {
      return <String>['wifi'];
    });
    messenger.setMockMethodCallHandler(connectivityEvents, (call) async {
      return null;
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(secureStorage, null);
    messenger.setMockMethodCallHandler(connectivity, null);
    messenger.setMockMethodCallHandler(connectivityEvents, null);
  });

  testWidgets('App starts on the splash screen and moves on to onboarding',
      (WidgetTester tester) async {
    // The forced-update gate only runs on Android/iOS and fails closed when
    // it cannot reach the API, which no test has. Any other platform skips it.
    // Reset inside the test: the framework checks foundation vars before
    // tearDown runs.
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    await tester.runAsync(() async {
      await tester.pumpWidget(const MyApp());
      // Let LanguageBloc load prefs and the localization delegate resolve.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('LOOP CRM'), findsOneWidget);

    // Splash holds for 2s after the maintenance/version gates, then routes a
    // first-time user to onboarding. The delay lives in the fake-async zone,
    // so it is advanced with pump(); the plugin and prefs futures need real
    // time, so runAsync() gives them a turn in between.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    }
    await tester.pump(const Duration(seconds: 1));

    debugDefaultTargetPlatformOverride = null;

    expect(find.byType(OnboardingScreen), findsOneWidget);
  });
}
