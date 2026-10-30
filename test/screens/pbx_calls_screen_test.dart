import 'package:crm_mobile/models/pbx_call_model.dart';
import 'package:crm_mobile/screens/calls/pbx_calls_screen.dart';
import 'package:crm_mobile/services/app_route_observer.dart';
import 'package:crm_mobile/services/sync_invalidation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

PbxCallRecord _call(String id, String from) => PbxCallRecord.fromJson({
  'id': id,
  'direction': 'inbound',
  'status': 'answered',
  'from_party': from,
  'to_party': '+9647700000001',
  'crm_contact': null,
  'crm_contact_name': null,
  'billsec_s': 12,
  'has_recording': false,
  'started_at': '2026-10-17T09:00:00Z',
});

/// A fake API: each call returns the current [rows] (newest first) and is counted.
class _FakeCalls {
  List<PbxCallRecord> rows = [_call('c1', '+9647801111111')];
  int calls = 0;
  bool fail = false;
  final List<bool> missedFlags = [];

  Future<PbxCallsPage> load({String? cursor, bool missedOnly = false}) async {
    calls++;
    missedFlags.add(missedOnly);
    if (fail) throw Exception('HTTP 503');
    return PbxCallsPage(results: List.of(rows));
  }
}

void main() {
  late _FakeCalls api;
  final navKey = GlobalKey<NavigatorState>();

  Future<void> pumpScreen(
    WidgetTester tester, {
    bool missedOnly = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        navigatorObservers: [appRouteObserver],
        home: PbxCallsScreen(missedOnly: missedOnly, loadPage: api.load),
      ),
    );
    await tester.pump();
  }

  /// Unmounts the screen so its fallback poll and debounce timers are cancelled.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  setUpAll(() => initializeDateFormatting('en'));
  setUp(() => api = _FakeCalls());

  testWidgets('loads the first page on open', (tester) async {
    await pumpScreen(tester);
    expect(api.calls, 1);
    expect(find.text('+9647801111111'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets(
    'the telephony invalidation re-reads and swaps rows in without blanking',
    (tester) async {
      await pumpScreen(tester);
      api.rows = [_call('c2', '+9647802222222'), ...api.rows];

      SyncInvalidation.instance.emit({
        'invalidate': kTelephonyCallsInvalidation,
      });
      SyncInvalidation.instance.emit({
        'invalidate': kTelephonyCallsInvalidation,
      }); // debounced into one
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.text('+9647801111111'),
        findsOneWidget,
        reason: 'old rows stay until the new page lands',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(api.calls, 2);
      expect(find.text('+9647802222222'), findsOneWidget);
      expect(find.text('+9647801111111'), findsOneWidget);
      await unmount(tester);
    },
  );

  testWidgets('other invalidations are ignored', (tester) async {
    await pumpScreen(tester);
    SyncInvalidation.instance.emit({'invalidate': 'crm:leads'});
    await tester.pump(const Duration(seconds: 1));
    expect(api.calls, 1);
    await unmount(tester);
  });

  testWidgets('coming back to the screen refreshes it', (tester) async {
    await pumpScreen(tester);
    navKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('lead')),
      ),
    );
    await tester.pumpAndSettle();
    api.rows = [_call('c3', '+9647803333333')];

    navKey.currentState!.pop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(api.calls, 2);
    expect(find.text('+9647803333333'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets(
    'returning to the foreground refreshes it, with the current filter',
    (tester) async {
      await pumpScreen(tester, missedOnly: true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(api.calls, 2);
      expect(api.missedFlags, [true, true]);
      await unmount(tester);
    },
  );

  testWidgets('a failed background refresh keeps the rows on screen', (
    tester,
  ) async {
    await pumpScreen(tester);
    api.fail = true;
    SyncInvalidation.instance.emit({'invalidate': kTelephonyCallsInvalidation});
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(api.calls, 2);
    expect(find.text('+9647801111111'), findsOneWidget);
    expect(find.text('pbxCallsLoadFailed'), findsNothing);
    await unmount(tester);
  });

  testWidgets('the fallback poll refreshes without any signal', (tester) async {
    await pumpScreen(tester);
    await tester.pump(kSyncFallbackPollInterval);
    await tester.pump(const Duration(milliseconds: 500));
    expect(api.calls, 2);
    await unmount(tester);
  });

  testWidgets('pull to refresh reloads', (tester) async {
    await pumpScreen(tester);
    await tester.fling(find.text('+9647801111111'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(api.calls, 2);
    await unmount(tester);
  });
}
