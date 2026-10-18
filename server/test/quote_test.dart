import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:leca_auth/quote.dart';
import 'package:leca_auth/talk_hub.dart';
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
    expect(quote['rates'], isA<Map<Object?, Object?>>());
    expect((quote['rates']! as Map)['id'], 'leca-kh-1');
    expect(quote['hours'], 0);
    expect(quote['routed'], isFalse);
    expect(
      fareProof(
        fareBody(
          kind: 'delivery',
          vehicle: '',
          meters: quote['meters']! as int,
          minutes: quote['minutes']! as int,
          cents: quote['cents']! as int,
        ),
      ),
      quote['proof'],
    );
    final along = quoteTrip({
      'kind': 'ride',
      'vehicle': 'car',
      'fromLat': 10.6,
      'fromLng': 104.18,
      'toLat': 10.48,
      'toLng': 104.32,
      'meters': 42000,
      'minutes': 70,
    });
    expect(along['routed'], isTrue);
    expect(along['meters'], 42000);
    expect(along['minutes'], 70);
    final day = quoteTrip({
      'kind': 'rent-self',
      'vehicle': 'car',
      'fromLat': 13.36,
      'fromLng': 103.85,
      'toLat': 13.36,
      'toLng': 103.85,
      'hours': 24,
    });
    expect(day['hours'], 24);
    final hop = quoteTrip({
      'kind': 'rent-self',
      'vehicle': 'car',
      'fromLat': 13.36,
      'fromLng': 103.85,
      'toLat': 13.36,
      'toLng': 103.85,
    });
    expect(day['cents'], greaterThan(hop['cents']! as int));
    expect(
      () => quoteTrip({'kind': 'delivery', 'fromLat': 11}),
      throwsFormatException,
    );
  });

  test(
    'two people share a room, the lines check out, and the log survives',
    () async {
      final dir = Directory.systemTemp.createTempSync('leca-rooms');
      addTearDown(() => dir.deleteSync(recursive: true));
      TalkIdentity? resolve(String token) => switch (token) {
        'tok-ada' => (id: 'phone:85512000001', name: 'Ada Real'),
        'tok-bo' => (id: 'email:bo@x.kh', name: 'Bo'),
        'tok-cy' => (id: 'key:cy', name: 'Cy'),
        _ => null,
      };
      var hub = TalkHub(logDir: dir.path, resolve: resolve);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        if (WebSocketTransformer.isUpgradeRequest(request) &&
            request.uri.path == '/v1/room') {
          hub.attach(await WebSocketTransformer.upgrade(request));
        }
      });
      addTearDown(server.close);
      Future<WebSocket> open() =>
          WebSocket.connect('ws://127.0.0.1:${server.port}/v1/room');
      final ada = await open();
      final bo = await open();
      addTearDown(() async {
        await ada.close();
        await bo.close();
      });
      final adaIn = _Inbox(ada);
      final boIn = _Inbox(bo);
      ada.add(
        jsonEncode({
          'type': 'join',
          'room': 'ride:tuktuk',
          'name': 'Ada',
          'token': 'tok-ada',
        }),
      );
      final adaHello = await adaIn.nextWhere((m) => m['type'] == 'welcome');
      // The account decides the name and the handle, not the join message.
      expect(adaHello['you'], 'Ada Real');
      expect(adaHello['who'], talkWho('phone:85512000001'));
      expect('${adaHello['who']}', isNot(contains('85512')));
      bo.add(
        jsonEncode({
          'type': 'join',
          'room': 'ride:tuktuk',
          'name': 'Bo',
          'token': 'tok-bo',
        }),
      );
      final boHello = await boIn.nextWhere((m) => m['type'] == 'welcome');
      expect(boHello['you'], 'Bo');
      expect(boHello['who'], talkWho('email:bo@x.kh'));
      expect('${boHello['names']}', contains('Ada Real'));

      ada.add(jsonEncode({'type': 'say', 'kind': 'text', 'text': 'hello'}));
      final heard = await boIn.nextWhere((m) => m['type'] == 'entry');
      final entry = (heard['entry']! as Map).map(
        (key, value) => MapEntry('$key', value),
      );
      expect(entry['name'], 'Ada Real');
      expect(entry['who'], talkWho('phone:85512000001'));
      expect(publishedTalkChecks(entry), isTrue);

      // A badly formed price is ignored. A signed-in account can bargain.
      ada
        ..add(
          jsonEncode({
            'type': 'say',
            'kind': 'price',
            'text': 'ask 2.4 driver',
          }),
        )
        ..add(
          jsonEncode({
            'type': 'say',
            'kind': 'price',
            'text': 'ask 2.40 driver',
          }),
        );
      final priced = await boIn.nextWhere((m) {
        final line = m['entry'];
        return m['type'] == 'entry' && line is Map && line['kind'] == 'price';
      });
      final price = (priced['entry']! as Map).map(
        (key, value) => MapEntry('$key', value),
      );
      expect(price['seq'], 2);
      expect(price['who'], talkWho('phone:85512000001'));
      expect(price['prev'], entry['proof']);
      expect(publishedTalkChecks(price), isTrue);

      // A new hub on the same directory serves the same chain.
      hub = TalkHub(logDir: dir.path, resolve: resolve);
      final late = await open();
      addTearDown(late.close);
      final lateIn = _Inbox(late);
      late.add(
        jsonEncode({
          'type': 'join',
          'room': 'ride:tuktuk',
          'name': 'Cy',
          'token': 'tok-cy',
        }),
      );
      final lateHello = await lateIn.nextWhere((m) => m['type'] == 'welcome');
      final log = lateHello['log']! as List;
      expect(log, hasLength(2));
      expect((log.last as Map)['proof'], price['proof']);
    },
  );
}

class _Inbox {
  _Inbox(WebSocket socket) {
    socket.listen((raw) {
      final decoded = jsonDecode('$raw');
      final message = (decoded as Map).map(
        (key, value) => MapEntry('$key', value),
      );
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
