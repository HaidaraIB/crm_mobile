import 'package:crm_mobile/models/pbx_call_model.dart';
import 'package:crm_mobile/widgets/pbx_access_guard.dart';
import 'package:crm_mobile/widgets/permission_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _provisioned = PbxMe(
  provisioned: true,
  outboundSuspended: false,
  extensionNumber: '101',
  deviceType: 'desk_phone',
  registered: true,
  canClickToCall: true,
);

void main() {
  testWidgets('does not build the PBX screen when access is denied', (
    tester,
  ) async {
    var built = false;
    await tester.pumpWidget(
      MaterialApp(
        home: PbxAccessGuard(
          loadMe: () async => null,
          builder: (_) {
            built = true;
            return const Scaffold(body: Text('PBX calls'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(built, isFalse);
    expect(find.byType(AccessDeniedScreen), findsOneWidget);
    expect(find.text('PBX calls'), findsNothing);
  });

  testWidgets('builds the PBX screen for a provisioned pilot', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PbxAccessGuard(
          loadMe: () async => _provisioned,
          builder: (_) => const Scaffold(body: Text('PBX calls')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PBX calls'), findsOneWidget);
    expect(find.byType(AccessDeniedScreen), findsNothing);
  });
}
