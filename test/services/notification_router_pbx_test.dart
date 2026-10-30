import 'package:crm_mobile/models/notification_model.dart';
import 'package:crm_mobile/services/notification_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

NotificationPayload _payload(
  NotificationType type, {
  Map<String, dynamic>? data,
}) => NotificationPayload(
  type: type,
  title: 'PBX',
  body: 'PBX event',
  data: data,
);

void main() {
  final navigatorKey = GlobalKey<NavigatorState>();

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('home')),
        routes: {
          '/phone-calls': (_) => const Scaffold(body: Text('phone calls')),
          '/leads/details': (_) => const Scaffold(body: Text('lead details')),
        },
      ),
    );
  }

  testWidgets('denied pilot policy blocks missed-call notification routes', (
    tester,
  ) async {
    await pumpApp(tester);
    await NotificationRouter.navigateFromNotification(
      navigatorKey.currentContext,
      _payload(NotificationType.pbxCallMissed, data: {'client_id': 7}),
      canOpenPbxCallHistory: () async => false,
    );
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(find.text('lead details'), findsNothing);
    expect(find.text('phone calls'), findsNothing);
  });

  testWidgets('approved pilot can open emergency call history', (tester) async {
    await pumpApp(tester);
    await NotificationRouter.navigateFromNotification(
      navigatorKey.currentContext,
      _payload(NotificationType.pbxEmergencyCall),
      canOpenPbxCallHistory: () async => true,
    );
    await tester.pumpAndSettle();

    expect(find.text('phone calls'), findsOneWidget);
  });
}
