import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:leca_auth/talk_hub.dart';
import 'package:test/test.dart';

void main() {
  test('a line before join is ignored, and two rooms stay apart', () async {
    final dir = Directory.systemTemp.createTempSync('leca-rooms-split');
    addTearDown(() => dir.deleteSync(recursive: true));
    final hub = TalkHub(
      logDir: dir.path,
      resolve: (token) => switch (token) {
        'ada' => (id: 'phone:1', name: 'Ada'),
        'bo' => (id: 'email:bo', name: 'Bo'),
        _ => null,
      },
    );
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

    final early = await open();
    addTearDown(early.close);
    final earlyIn = _Inbox(early);
    early
      ..add(jsonEncode({'type': 'say', 'text': 'too soon'}))
      ..add(
        jsonEncode({
          'type': 'join',
          'room': 'kitchen',
          'name': 'Guest',
          'token': 'ada',
        }),
      );
    final hello = await earlyIn.nextWhere((m) => m['type'] == 'welcome');
    expect(hello['log'], isEmpty);
    expect(hello['you'], 'Ada');

    final other = await open();
    addTearDown(other.close);
    final otherIn = _Inbox(other);
    other.add(
      jsonEncode({
        'type': 'join',
        'room': 'parcel',
        'name': 'Bo',
        'token': 'bo',
      }),
    );
    await otherIn.nextWhere((m) => m['type'] == 'welcome');

    early.add(jsonEncode({'type': 'say', 'text': 'noodles'}));
    final entry = await earlyIn.nextWhere((m) => m['type'] == 'entry');
    expect((entry['entry']! as Map<String, Object?>)['room'], 'kitchen');
    expect((entry['entry']! as Map<String, Object?>)['seq'], 1);

    other
      ..add(
        jsonEncode({'type': 'addr', 'endpoint': 'bo-node', 'addr': 'direct'}),
      )
      ..add(jsonEncode({'type': 'say', 'text': 'parcel'}));
    final parcel = await otherIn.nextWhere((m) => m['type'] == 'entry');
    expect((parcel['entry']! as Map<String, Object?>)['seq'], 1);
    expect((parcel['entry']! as Map<String, Object?>)['text'], 'parcel');
    expect(File('${dir.path}/kitchen.jsonl').readAsLinesSync(), hasLength(1));
    expect(File('${dir.path}/parcel.jsonl').readAsLinesSync(), hasLength(1));
  });

  test('an address is shared with the other person in the room', () async {
    final hub = TalkHub(
      resolve: (token) => switch (token) {
        'ada' => (id: 'phone:1', name: 'Ada'),
        'bo' => (id: 'email:bo', name: 'Bo'),
        _ => null,
      },
    );
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
        'room': 'ride',
        'name': 'Ada',
        'token': 'ada',
      }),
    );
    await adaIn.nextWhere((m) => m['type'] == 'welcome');
    bo.add(
      jsonEncode({'type': 'join', 'room': 'ride', 'name': 'Bo', 'token': 'bo'}),
    );
    final boHello = await boIn.nextWhere((m) => m['type'] == 'welcome');
    expect('${boHello['names']}', contains('Ada'));

    ada.add(
      jsonEncode({'type': 'addr', 'endpoint': 'ada-node', 'addr': 'iroh-addr'}),
    );
    final presence = await boIn.nextWhere(
      (m) =>
          m['type'] == 'presence' && (m['peers']! as List<Object?>).isNotEmpty,
    );
    final peers = presence['peers']! as List<Object?>;
    expect(peers, hasLength(1));
    expect((peers.single! as Map<String, Object?>)['endpoint'], 'ada-node');
    expect((peers.single! as Map<String, Object?>)['name'], 'Ada');

    ada.add(
      jsonEncode({'type': 'addr', 'endpoint': 'x' * 81, 'addr': 'too-long'}),
    );
    bo.add(jsonEncode({'type': 'say', 'text': 'still here'}));
    final said = await adaIn.nextWhere((m) => m['type'] == 'entry');
    expect((said['entry']! as Map<String, Object?>)['name'], 'Bo');
  });

  test('a swarm frame reaches the other person, with its id on the say', () async {
    final hub = TalkHub(
      resolve: (token) => switch (token) {
        'ada' => (id: 'phone:1', name: 'Ada'),
        'bo' => (id: 'email:bo', name: 'Bo'),
        _ => null,
      },
    );
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
        'room': 'front',
        'name': 'Ada',
        'token': 'ada',
        'lat': 11.5564,
        'lng': 104.9282,
        'radius': 10,
        'face': 'anon',
      }),
    );
    await adaIn.nextWhere((m) => m['type'] == 'welcome');
    bo.add(
      jsonEncode({
        'type': 'join',
        'room': 'front',
        'name': 'Bo',
        'token': 'bo',
        'lat': 11.5564,
        'lng': 104.9282,
        'radius': 10,
        'face': 'name',
      }),
    );
    await boIn.nextWhere((m) => m['type'] == 'welcome');

    const frame =
        '{"topic":"front","kind":"text","text":"noodles","from":"ada","id":"abc"}';
    ada.add(jsonEncode({'type': 'swarm', 'frame': frame}));
    final relayed = await boIn.nextWhere((m) => m['type'] == 'swarm');
    expect(relayed['frame'], frame);

    ada.add(jsonEncode({'type': 'say', 'text': 'noodles', 'id': 'abc'}));
    final entry = await adaIn.nextWhere((m) => m['type'] == 'entry');
    expect(entry['id'], 'abc');
    expect((entry['entry']! as Map<String, Object?>)['text'], 'noodles');
  });

  test(
    'front chat shows distance, a name, or nobody outside the radius',
    () async {
      final hub = TalkHub(
        resolve: (token) => switch (token) {
          'ada' => (id: 'phone:1', name: 'Ada'),
          'bo' => (id: 'email:bo', name: 'Bo'),
          _ => null,
        },
      );
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
          'room': 'front',
          'token': 'ada',
          'lat': 11.5564,
          'lng': 104.9282,
          'radius': 20,
          'face': 'anon',
        }),
      );
      await adaIn.nextWhere((m) => m['type'] == 'welcome');
      bo.add(
        jsonEncode({
          'type': 'join',
          'room': 'front',
          'token': 'bo',
          'lat': 11.6014,
          'lng': 104.9282,
          'radius': 20,
          'face': 'name',
        }),
      );
      final boHello = await boIn.nextWhere((m) => m['type'] == 'welcome');
      final nearAda = (boHello['people']! as List).single as Map;
      expect(nearAda.containsKey('name'), isFalse);
      expect(nearAda['km'], inInclusiveRange(4, 6));

      final adaSeen = await adaIn.nextWhere(
        (m) => m['type'] == 'presence' && (m['people']! as List).isNotEmpty,
      );
      final nearBo = (adaSeen['people']! as List).single as Map;
      expect(nearBo['name'], 'Bo');

      ada.add(jsonEncode({'type': 'place', 'face': 'hide'}));
      final hidden = await boIn.nextWhere(
        (m) => m['type'] == 'presence' && (m['people']! as List).isEmpty,
      );
      expect(hidden['people'], isEmpty);

      ada.add(jsonEncode({'type': 'place', 'face': 'anon', 'radius': 1}));
      final tooFar = await boIn.nextWhere(
        (m) => m['type'] == 'presence' && (m['people']! as List).isEmpty,
      );
      expect(tooFar['people'], isEmpty);

      ada.add(jsonEncode({'type': 'place', 'face': 'anon', 'radius': 20}));
      final back = await boIn.nextWhere(
        (m) => m['type'] == 'presence' && (m['people']! as List).isNotEmpty,
      );
      expect(back['people'], hasLength(1));
    },
  );

  test('a guest joins the front chat and cannot join a ride', () async {
    final hub = TalkHub(resolve: (_) => null);
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

    final ride = await open();
    final closed = Completer<void>();
    ride.listen((_) {}, onDone: closed.complete);
    addTearDown(ride.close);
    ride.add(
      jsonEncode({'type': 'join', 'room': 'ride', 'guest': 'guest-12345678'}),
    );
    await closed.future.timeout(const Duration(seconds: 2));

    final front = await open();
    addTearDown(front.close);
    final inbox = _Inbox(front);
    front.add(
      jsonEncode({
        'type': 'join',
        'room': 'front',
        'guest': 'guest-12345678',
        'name': 'Visitor',
        'lat': 11.55,
        'lng': 104.92,
        'radius': 10,
        'face': 'name',
      }),
    );
    final hello = await inbox.nextWhere((m) => m['type'] == 'welcome');
    expect(hello['you'], 'Visitor');
    expect('${hello['who']}', hasLength(16));
  });
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
