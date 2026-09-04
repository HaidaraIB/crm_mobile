import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:crm_mobile/models/tenant_chat_models.dart';
import 'package:crm_mobile/screens/team_chat/team_chat_message_bubble.dart';
import 'package:crm_mobile/screens/team_chat/team_chat_text_direction.dart';

TenantChatPeer _peer() => TenantChatPeer(
      id: 1,
      username: 'memo',
      email: 'memo@test.com',
      firstName: 'Me',
      lastName: 'Mo',
      role: 'admin',
    );

TenantChatMessage _message(String body) => TenantChatMessage(
      id: 1,
      sender: _peer(),
      body: body,
      createdAt: '2026-09-02T02:02:00Z',
    );

Future<void> _pump(WidgetTester tester, String body, {bool arabicUi = true}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: arabicUi ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          body: TeamChatMessageBubble(
            message: _message(body),
            mine: true,
            lang: arabicUi ? 'ar' : 'en',
            sameSenderAsPrevious: false,
            isCompanyGroup: false,
            tr: (k) => k,
            onReply: () {},
            onForward: () {},
            onPin: () {},
            onJump: (_) {},
            labelCouldNotLoad: 'x',
            labelReply: 'reply',
            labelForward: 'forward',
            labelPin: 'pin',
            labelForwarded: 'forwarded',
            labelJumpFwd: 'jump',
            labelJumpQ: 'jump',
            labelRead: 'read',
            labelDelivered: 'delivered',
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  testWidgets('bubble hugs a short message instead of stretching', (tester) async {
    await _pump(tester, 'hi');
    final short = tester.getSize(find.byType(Material).last).width;

    await _pump(tester, 'a much longer message body that has to wrap onto '
        'several lines inside the bubble to be rendered fully');
    final long = tester.getSize(find.byType(Material).last).width;

    final maxWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio * 0.82;
    expect(short, lessThan(maxWidth / 2));
    expect(long, greaterThan(short));
  });

  testWidgets('message body direction follows its own text', (tester) async {
    await _pump(tester, 'مرحبا');
    expect(
      Directionality.of(tester.element(find.text('مرحبا'))),
      TextDirection.rtl,
    );

    await _pump(tester, 'hello');
    expect(
      Directionality.of(tester.element(find.text('hello'))),
      TextDirection.ltr,
    );
  });

  testWidgets('row labels keep the UI direction and isolate their content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: TeamChatIsolatedText('memo')),
        ),
      ),
    );

    final text = tester.widget<Text>(find.byType(Text));
    expect(text.data, bidiIsolate('memo'));
    expect(text.textAlign, TextAlign.start);
    expect(Directionality.of(tester.element(find.byType(Text))), TextDirection.rtl);
  });
}
