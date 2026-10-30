import 'dart:async';

import 'package:crm_mobile/services/realtime_channel.dart';
import 'package:crm_mobile/services/sync_invalidation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A server that is down: the handshake never completes.
class _UnreachableChannel extends Fake implements WebSocketChannel {
  @override
  Future<void> get ready =>
      Future<void>.error(WebSocketChannelException('Connection refused'));

  @override
  WebSocketSink get sink => _FakeSink();
}

/// A refused handshake whose error quotes the URL, as dart:io's does.
class _LeakyChannel extends Fake implements WebSocketChannel {
  _LeakyChannel(this.uri);
  final Uri uri;

  @override
  Future<void> get ready => Future<void>.error(
    WebSocketChannelException(
      "WebSocketException: Connection to '$uri#' was not upgraded to websocket",
    ),
  );

  @override
  WebSocketSink get sink => _FakeSink();
}

/// A server that accepts the socket; the test closes it through [frames].
class _OpenChannel extends Fake implements WebSocketChannel {
  final StreamController<dynamic> frames = StreamController<dynamic>();
  final _FakeSink _sink = _FakeSink();

  @override
  Future<void> get ready => Future<void>.value();

  @override
  Stream<dynamic> get stream => frames.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  int? get closeCode => 1006;
}

class _FakeSink extends Fake implements WebSocketSink {
  final List<dynamic> sent = [];

  @override
  void add(dynamic data) => sent.add(data);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {}
}

void main() {
  final rt = RealtimeChannel.instance;
  late List<WebSocketChannel Function()> script;
  late int connects;
  late List<Uri> uris;

  setUpAll(() {
    dotenv.testLoad(fileInput: 'BASE_URL=http://127.0.0.1:8765/api/v1');
  });

  setUp(() {
    connects = 0;
    uris = [];
    script = [];
    RealtimeChannel.tokenReader = () async => 'token';
    RealtimeChannel.connector = (uri) {
      uris.add(uri);
      final next = script.isNotEmpty
          ? script.removeAt(0)
          : _UnreachableChannel.new;
      connects++;
      return next();
    };
  });

  tearDown(() async {
    await rt.stop();
  });

  test(
    'reconnectDelay grows from 1s and is capped at 30s, with 0.5x to 1.5x jitter',
    () {
      expect(
        RealtimeChannel.reconnectDelay(0, 0.5),
        const Duration(seconds: 1),
      );
      expect(
        RealtimeChannel.reconnectDelay(1, 0.5),
        const Duration(seconds: 2),
      );
      expect(
        RealtimeChannel.reconnectDelay(4, 0.5),
        const Duration(seconds: 16),
      );
      expect(
        RealtimeChannel.reconnectDelay(5, 0.5),
        const Duration(seconds: 30),
      );
      expect(
        RealtimeChannel.reconnectDelay(10, 0.5),
        const Duration(seconds: 30),
      );
      expect(
        RealtimeChannel.reconnectDelay(0, 0),
        const Duration(milliseconds: 500),
      );
      expect(
        RealtimeChannel.reconnectDelay(10, 1),
        const Duration(seconds: 45),
      );
    },
  );

  test('redactSocketError drops the token from a failed handshake message', () {
    const message =
        "WebSocketException: Connection to 'http://127.0.0.1:8765/ws/sync/?token=eyJ.abc.def#' "
        'was not upgraded to websocket';
    final redacted = redactSocketError(message);
    expect(redacted, isNot(contains('eyJ')));
    expect(redacted, contains('token=<redacted>#'));
    expect(redactSocketError('token=a.b.c&x=1'), 'token=<redacted>&x=1');
  });

  testWidgets('failed connects are logged without the access token', (
    tester,
  ) async {
    final logged = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) =>
        logged.add(message ?? '');
    RealtimeChannel.tokenReader = () async => 'secret.jwt.value';
    RealtimeChannel.connector = (uri) => _LeakyChannel(uri);
    try {
      await rt.start();
      await tester.pump();
      await rt.stop();
    } finally {
      debugPrint = original;
    }
    expect(logged.where((l) => l.contains('connect failed')), isNotEmpty);
    expect(logged.join('\n'), isNot(contains('secret.jwt.value')));
  });

  testWidgets(
    'an unreachable server is retried with growing delays and no unhandled error',
    (tester) async {
      await rt.start();
      await tester.pump();
      expect(connects, 1);
      expect(rt.isConnected, isFalse);
      expect(uris.single.path, '/ws/sync/');
      expect(uris.single.queryParameters['token'], 'token');

      final delays = <Duration>[];
      for (var i = 0; i < 6; i++) {
        final delay = rt.lastReconnectDelay!;
        delays.add(delay);
        await tester.pump(delay);
        await tester.pump();
        expect(connects, i + 2);
      }
      expect(rt.isConnected, isFalse);
      // Every failed handshake counts: the backoff is no longer reset to 1s each time.
      for (var i = 0; i < delays.length; i++) {
        final nominal = RealtimeChannel.reconnectDelay(i, 0.5);
        expect(
          delays[i] >= nominal * 0.5 && delays[i] <= nominal * 1.5,
          isTrue,
          reason: 'attempt $i waited ${delays[i]}, nominal $nominal',
        );
      }
      expect(delays.last > const Duration(seconds: 7), isTrue);
      // tester fails the test on any unhandled async error, so reaching here means none.
      await rt.stop();
    },
  );

  testWidgets('a connection that drops at once does not reset the backoff', (
    tester,
  ) async {
    final first = _OpenChannel();
    final second = _OpenChannel();
    script = [
      _UnreachableChannel.new,
      _UnreachableChannel.new,
      () => first,
      () => second,
    ];
    await rt.start();
    await tester.pump();
    await tester.pump(rt.lastReconnectDelay!);
    await tester.pump();
    await tester.pump(rt.lastReconnectDelay!);
    await tester.pump();
    expect(rt.isConnected, isTrue);
    expect(rt.attempt, 2);

    await first.frames.close(); // dropped after a moment
    await tester.pump();
    expect(rt.isConnected, isFalse);
    expect(rt.attempt, 3);
    expect(
      rt.lastReconnectDelay! >= RealtimeChannel.reconnectDelay(2, 0),
      isTrue,
    );
    await rt.stop();
  });

  testWidgets('a connection that stays up resets the backoff', (tester) async {
    final channel = _OpenChannel();
    script = [_UnreachableChannel.new, _UnreachableChannel.new, () => channel];
    await rt.start();
    await tester.pump();
    await tester.pump(rt.lastReconnectDelay!);
    await tester.pump();
    await tester.pump(rt.lastReconnectDelay!);
    await tester.pump();
    expect(rt.isConnected, isTrue);

    await tester.pump(const Duration(seconds: 11));
    expect(rt.attempt, 0);

    await channel.frames.close();
    await tester.pump();
    expect(rt.isConnected, isFalse);
    expect(
      rt.lastReconnectDelay! <= RealtimeChannel.reconnectDelay(0, 1),
      isTrue,
    );
    await rt.stop();
  });

  testWidgets('a telephony frame invalidates the PBX call history', (
    tester,
  ) async {
    final channel = _OpenChannel();
    script = [() => channel];
    final seen = <String?>[];
    final sub = SyncInvalidation.instance.stream.listen(
      (e) => seen.add(e['invalidate']),
    );
    await rt.start();
    await tester.pump();
    expect(rt.isConnected, isTrue);

    channel.frames.add(
      '{"scope": "telephony", "event": "call.ended", "call_id": "c1"}',
    );
    await tester.pump();
    expect(seen, [kTelephonyCallsInvalidation]);
    // Cancelling a live subscription completes in the root zone, which fake
    // time never drains: run those outside it.
    await tester.runAsync(() async {
      await sub.cancel();
      await rt.stop();
    });
  });
}
