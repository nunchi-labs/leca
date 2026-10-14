import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chow_auth/quote.dart';
import 'package:chow_auth/talk_hub.dart';
import 'package:test/test.dart';

void main() {
  test('the server prices the same trip the app does', () {
    final quote = quoteTrip({
      'kind': 'delivery',
      'fromLat': 11.5454,
      'fromLng': 104.9108,
      'toLat': 11.5564,
      'toLng': 104.9282,
    });
    expect(quote['cents'], greaterThanOrEqualTo(50));
    expect(fareProof(fareBody(
      kind: 'delivery',
      vehicle: '',
      meters: quote['meters'] as int,
      minutes: quote['minutes'] as int,
      cents: quote['cents'] as int,
    )), quote['proof']);
    expect(
      () => quoteTrip({'kind': 'delivery', 'fromLat': 11}),
      throwsFormatException,
    );
  });

  test('two people share a room and the lines check out', () async {
    final hub = TalkHub();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (WebSocketTransformer.isUpgradeRequest(request) &&
          request.uri.path == '/v1/room') {
        hub.attach(await WebSocketTransformer.upgrade(request));
      }
    });
    addTearDown(server.close);
    final ada = await WebSocket.connect('ws://127.0.0.1:${server.port}/v1/room');
    final bo = await WebSocket.connect('ws://127.0.0.1:${server.port}/v1/room');
    addTearDown(() async {
      await ada.close();
      await bo.close();
    });
    final adaIn = _Inbox(ada);
    final boIn = _Inbox(bo);
    ada.add(jsonEncode({'type': 'join', 'room': 'ride:tuktuk', 'name': 'Ada'}));
    await adaIn.nextWhere((m) => m['type'] == 'welcome');
    bo.add(jsonEncode({'type': 'join', 'room': 'ride:tuktuk', 'name': 'Bo'}));
    final boHello = await boIn.nextWhere((m) => m['type'] == 'welcome');
    expect(boHello['you'], 'Bo');
    expect('${boHello['names']}', contains('Ada'));
    expect('${boHello['you']}', isNot(contains('endpoint')));

    ada.add(jsonEncode({'type': 'say', 'kind': 'text', 'text': 'hello'}));
    final heard = await boIn.nextWhere((m) => m['type'] == 'entry');
    final entry = (heard['entry'] as Map).map(
      (key, value) => MapEntry('$key', value),
    );
    expect(entry['name'], 'Ada');
    expect(entry['text'], 'hello');
    expect(publishedTalkChecks(entry), isTrue);

    bo.add(jsonEncode({'type': 'say', 'kind': 'voice', 'text': 'open'}));
    final call = await adaIn.nextWhere((m) {
      final line = m['entry'];
      return m['type'] == 'entry' && line is Map && line['kind'] == 'voice';
    });
    final voice = (call['entry'] as Map).map(
      (key, value) => MapEntry('$key', value),
    );
    expect(voice['prev'], entry['proof']);
    expect(publishedTalkChecks(voice), isTrue);
  });
}

class _Inbox {
  _Inbox(WebSocket socket) {
    socket.listen((raw) {
      final decoded = jsonDecode('$raw');
      final message =
          (decoded as Map).map((key, value) => MapEntry('$key', value));
      if (_waiters.isNotEmpty) {
        _waiters.removeAt(0).complete(message);
      } else {
        _queued.add(message);
      }
    });
  }

  final _queued = <Map<String, Object?>>[];
  final _waiters = <Completer<Map<String, Object?>>>[];

  Future<Map<String, Object?>> nextWhere(
    bool Function(Map<String, Object?> message) test,
  ) async {
    while (true) {
      final message = await _next();
      if (test(message)) return message;
    }
  }

  Future<Map<String, Object?>> _next() {
    if (_queued.isNotEmpty) return Future.value(_queued.removeAt(0));
    final waiter = Completer<Map<String, Object?>>();
    _waiters.add(waiter);
    return waiter.future;
  }
}
