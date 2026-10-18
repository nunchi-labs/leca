import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:leca_auth/leca_auth.dart';
import 'package:leca_auth/quote.dart';
import 'package:leca_auth/talk_hub.dart';
import 'package:leca_auth/trust.dart';
import 'package:test/test.dart';

const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

void main() {
  group('quote', () {
    test('the server card matches the app, and a bad trip is refused', () {
      expect(
        [
          fareCents(
            kind: 'ride',
            vehicle: 'bicycle',
            meters: 5000,
            minutes: 10,
          ),
          fareCents(
            kind: 'ride',
            vehicle: 'motorcycle',
            meters: 5000,
            minutes: 10,
          ),
          fareCents(kind: 'ride', vehicle: 'tuktuk', meters: 5000, minutes: 10),
          fareCents(
            kind: 'ride',
            vehicle: 'remorque',
            meters: 5000,
            minutes: 10,
          ),
          fareCents(kind: 'ride', vehicle: 'car', meters: 5000, minutes: 10),
          fareCents(kind: 'ride', vehicle: 'van6', meters: 5000, minutes: 10),
        ],
        [133, 190, 247, 266, 342, 418],
      );
      expect(
        fareCents(
          kind: 'rent',
          vehicle: 'car',
          meters: 500,
          minutes: 1,
          hours: 24,
        ),
        1440,
      );
      expect(
        fareCents(kind: 'delivery', vehicle: '', meters: 0, minutes: 0),
        50,
      );

      final weird = quoteTrip({
        'kind': 'spaceship',
        'vehicle': 'car',
        'fromLat': 11,
        'fromLng': 104,
        'toLat': 12,
        'toLng': 105,
      });
      expect(weird['kind'], 'delivery');
      expect(weird['vehicle'], '');
      expect(weird['routed'], isFalse);

      final invented = quoteTrip({
        'kind': 'ride',
        'vehicle': 'car',
        'fromLat': 11,
        'fromLng': 104,
        'toLat': 11.1,
        'toLng': 104.1,
        'meters': 500,
        'minutes': 9,
      });
      expect(invented['routed'], isFalse);
      expect(invented['meters'], isNot(500));

      final routed = quoteTrip({
        'kind': 'ride',
        'vehicle': 'car',
        'fromLat': 11,
        'fromLng': 104,
        'toLat': 11.1,
        'toLng': 104.1,
        'meters': 20000,
        'minutes': 20,
      });
      expect(routed['routed'], isTrue);
      expect(routed['meters'], 20000);
      expect(routed['minutes'], 20);

      final tooFar = quoteTrip({
        'kind': 'ride',
        'vehicle': 'car',
        'fromLat': 11,
        'fromLng': 104,
        'toLat': 11.01,
        'toLng': 104.01,
        'meters': 2000001,
        'minutes': '90',
      });
      expect(tooFar['routed'], isFalse);
      expect(tooFar['minutes'], isNot(90));

      final year = quoteTrip({
        'kind': 'rent-self',
        'vehicle': 'car',
        'fromLat': 11.5,
        'fromLng': 104.9,
        'toLat': 11.5,
        'toLng': 104.9,
        'hours': 24 * 90,
      });
      final over = quoteTrip({
        'kind': 'rent-self',
        'vehicle': 'car',
        'fromLat': 11.5,
        'fromLng': 104.9,
        'toLat': 11.5,
        'toLng': 104.9,
        'hours': 24 * 90 + 1,
      });
      expect(year['hours'], 2160);
      expect(over['hours'], 0);
      expect(year['cents'], greaterThan(over['cents']! as int));
      expect(
        quoteTrip({
          'kind': 'rent',
          'vehicle': 'car',
          'fromLat': 11.5,
          'fromLng': 104.9,
          'toLat': 11.5,
          'toLng': 104.9,
          'hours': -4,
        })['hours'],
        0,
      );

      for (final bad in [181, -181, double.nan, double.infinity]) {
        expect(
          () => quoteTrip({
            'kind': 'delivery',
            'fromLat': bad,
            'fromLng': 0,
            'toLat': 0,
            'toLng': 0,
          }),
          throwsFormatException,
        );
      }
      expect(
        () => quoteTrip({
          'kind': 'delivery',
          'fromLat': '11',
          'fromLng': 104,
          'toLat': 12,
          'toLng': 105,
        }),
        throwsFormatException,
      );
    });
  });

  group('trust', () {
    test('files and reports refuse the cases a person should not see', () {
      final dir = Directory.systemTemp.createTempSync('leca-trust-edges');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/trust.json';
      var store = TrustStore(path: path, adminKey: 'secret');
      const rider = AuthUser(
        id: 'phone:1',
        method: 'phone',
        displayName: 'Ada',
        handle: '1',
      );
      const driver = AuthUser(
        id: 'phone:2',
        method: 'phone',
        displayName: 'Bo',
        handle: '2',
      );
      const stranger = AuthUser(
        id: 'phone:3',
        method: 'phone',
        displayName: 'Cy',
        handle: '3',
      );

      expect(
        () => TrustStore().requireAdmin('secret'),
        throwsA(
          predicate<AuthFailure>(
            (e) => e.code == 'admin_unconfigured' && e.status == 503,
          ),
        ),
      );
      expect(
        () => store.requireAdmin('nope'),
        throwsA(
          predicate<AuthFailure>(
            (e) => e.code == 'forbidden' && e.status == 403,
          ),
        ),
      );
      store.requireAdmin('secret');

      expect(
        () => store.submitDriver(driver, {
          'staffId': '',
          'vehicleKind': 'car',
          'selfie': _png,
          'idCard': _png,
        }),
        throwsA(predicate<AuthFailure>((e) => e.code == 'driver_invalid')),
      );
      expect(
        () => store.submitDriver(driver, {
          'staffId': 'LECA-KH-22',
          'vehicleKind': 'car',
          'selfie': _png,
        }),
        throwsA(predicate<AuthFailure>((e) => e.code == 'photo_missing')),
      );
      expect(
        () => store.submitDriver(driver, {
          'staffId': 'LECA-KH-22',
          'vehicleKind': 'car',
          'selfie': '****',
          'idCard': _png,
        }),
        throwsA(predicate<AuthFailure>((e) => e.code == 'photo_invalid')),
      );
      expect(
        () => store.submitDriver(driver, {
          'staffId': 'LECA-KH-22',
          'vehicleKind': 'car',
          'selfie': 'A' * (6 * 1024 * 1024 + 1),
          'idCard': _png,
        }),
        throwsA(predicate<AuthFailure>((e) => e.code == 'photo_too_large')),
      );

      store.submitDriver(driver, {
        'staffId': 'LECA-KH-22',
        'vehicleKind': 'car',
        'legalName': 'Bo',
        'selfie': _png,
        'idCard': _png,
      });
      expect(
        () => store.reviewDriver({'userId': 'missing', 'decision': 'approved'}),
        throwsA(
          predicate<AuthFailure>(
            (e) => e.code == 'driver_unknown' && e.status == 404,
          ),
        ),
      );
      expect(
        () => store.reviewDriver({'userId': driver.id, 'decision': 'maybe'}),
        throwsA(predicate<AuthFailure>((e) => e.code == 'decision_invalid')),
      );
      store.reviewDriver({
        'userId': driver.id,
        'decision': 'rejected',
        'note': 'blur',
      });
      expect(store.queue(), isEmpty);
      expect(store.status(driver)['review'], 'rejected');
      expect(store.status(driver)['note'], 'blur');

      store = TrustStore(path: path, adminKey: 'secret');
      expect(store.status(driver)['review'], 'rejected');
      store.submitDriver(driver, {
        'staffId': 'LECA-KH-22',
        'vehicleKind': 'motorcycle',
        'selfie': _png,
        'idCard': _png,
      });
      expect(store.status(driver)['review'], 'pending');
      expect(store.queue(), hasLength(1));
      store.reviewDriver({'userId': driver.id, 'decision': 'approved'});

      expect(
        () => store.fileReport(rider, {
          'category': 'rude',
          'subjectId': 'LECA-KH-22',
        }),
        throwsA(predicate<AuthFailure>((e) => e.code == 'report_invalid')),
      );
      final report = store.fileReport(rider, {
        'category': 'violence',
        'subjectId': 'LECA-KH-22',
        'note': 'swerving',
      });
      expect(
        () => store.appeal(stranger, {'id': report['id'], 'note': 'not me'}),
        throwsA(predicate<AuthFailure>((e) => e.code == 'forbidden')),
      );
      expect(
        () => store.appeal(driver, {'id': report['id'], 'note': '   '}),
        throwsA(predicate<AuthFailure>((e) => e.code == 'appeal_empty')),
      );
      expect(
        () => store.resolveReport({'id': 'missing', 'decision': 'cleared'}),
        throwsA(predicate<AuthFailure>((e) => e.code == 'report_unknown')),
      );
      expect(
        () => store.resolveReport({'id': report['id'], 'decision': 'maybe'}),
        throwsA(predicate<AuthFailure>((e) => e.code == 'decision_invalid')),
      );
      store.resolveReport({
        'id': report['id'],
        'decision': 'upheld',
        'note': 'kept',
      });
      expect(store.isSuspended('LECA-KH-22'), isTrue);
      expect(store.openReports(), isEmpty);
      expect(
        () => store.appeal(driver, {'id': report['id'], 'note': 'again'}),
        throwsA(predicate<AuthFailure>((e) => e.code == 'report_closed')),
      );

      final second = store.fileReport(rider, {
        'category': 'intoxication',
        'subjectId': 'LECA-KH-22',
      });
      store.resolveReport({'id': second['id'], 'decision': 'cleared'});
      expect(store.isSuspended('LECA-KH-22'), isTrue);
    });
  });

  group('talk', () {
    test('empty, unsigned, and broken lines never join the chain', () async {
      final dir = Directory.systemTemp.createTempSync('leca-room-edges');
      addTearDown(() => dir.deleteSync(recursive: true));
      TalkIdentity? member(String token) => switch (token) {
        'guest' => (id: 'key:guest', name: 'Guest'),
        _ => null,
      };
      final hub = TalkHub(logDir: dir.path, resolve: member);
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
      final socket = await open();
      addTearDown(socket.close);
      final inbox = _Inbox(socket);
      socket.add(
        jsonEncode({
          'type': 'join',
          'room': 'trip/1 east',
          'name': '   ',
          'token': 'guest',
        }),
      );
      final hello = await inbox.nextWhere((m) => m['type'] == 'welcome');
      expect(hello['you'], 'Guest');

      socket
        ..add(jsonEncode({'type': 'say', 'kind': 'text', 'text': '   '}))
        ..add(jsonEncode({'type': 'say', 'kind': 'photo', 'text': 'picture'}))
        ..add(jsonEncode({'type': 'say', 'kind': 'text', 'text': 'B' * 300}));
      final entry = await inbox.nextWhere((m) => m['type'] == 'entry');
      final line = (entry['entry']! as Map).map(
        (key, value) => MapEntry('$key', value),
      );
      expect(line['seq'], 1);
      expect(line['text'], 'B' * 280);
      expect(line['kind'], 'text');
      expect(publishedTalkChecks(line), isTrue);

      final log = File('${dir.path}/trip_1_east.jsonl');
      expect(log.readAsLinesSync(), hasLength(1));
      log
        ..writeAsStringSync('{"seq":2,"proof":"dead"}\n', mode: FileMode.append)
        ..writeAsStringSync('not json\n', mode: FileMode.append);

      final again = TalkHub(logDir: dir.path, resolve: member);
      final server2 = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server2.listen((request) async {
        if (WebSocketTransformer.isUpgradeRequest(request) &&
            request.uri.path == '/v1/room') {
          again.attach(await WebSocketTransformer.upgrade(request));
        }
      });
      addTearDown(server2.close);
      final late = await WebSocket.connect(
        'ws://127.0.0.1:${server2.port}/v1/room',
      );
      addTearDown(late.close);
      final lateIn = _Inbox(late);
      late.add(
        jsonEncode({
          'type': 'join',
          'room': 'trip/1 east',
          'name': 'Cy',
          'token': 'guest',
        }),
      );
      final lateHello = await lateIn.nextWhere((m) => m['type'] == 'welcome');
      final restored = lateHello['log']! as List;
      expect(restored, hasLength(1));
      expect((restored.single as Map)['proof'], line['proof']);

      final kept = _talkLine(seq: 1, room: 'lobby', text: 'earlier', prev: '');
      File(
        '${dir.path}/lobby.jsonl',
      ).writeAsStringSync('${jsonEncode(kept)}\n{"seq":2}\n');
      final fresh = await WebSocket.connect(
        'ws://127.0.0.1:${server2.port}/v1/room',
      );
      addTearDown(fresh.close);
      final freshIn = _Inbox(fresh);
      fresh.add(
        jsonEncode({'type': 'join', 'room': '', 'name': 'Cy', 'token': 'guest'}),
      );
      final lobby = await freshIn.nextWhere((m) => m['type'] == 'welcome');
      final lobbyLog = lobby['log']! as List;
      expect(lobbyLog, hasLength(1));
      expect((lobbyLog.single as Map)['text'], 'earlier');
      fresh.add(jsonEncode({'type': 'say', 'text': 'hi'}));
      final said = await freshIn.nextWhere((m) => m['type'] == 'entry');
      expect((said['entry']! as Map)['seq'], 2);
      expect((said['entry']! as Map)['prev'], kept['proof']);
      expect((said['entry']! as Map)['room'], 'lobby');
    }, timeout: const Timeout(Duration(seconds: 20)));
  });
}

Map<String, Object?> _talkLine({
  required int seq,
  required String room,
  required String text,
  required String prev,
}) {
  const at = '2026-10-18T00:00:00.000Z';
  const name = 'Ada';
  final body =
      'leca-talk/2\n'
      'seq=$seq\n'
      'room=$room\n'
      'kind=text\n'
      'name=$name\n'
      'who=\n'
      'at=$at\n'
      'text=$text\n'
      'prev=$prev\n';
  return {
    'seq': seq,
    'room': room,
    'kind': 'text',
    'name': name,
    'who': '',
    'at': at,
    'text': text,
    'prev': prev,
    'proof': sha256.convert(utf8.encode(body)).toString(),
  };
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
