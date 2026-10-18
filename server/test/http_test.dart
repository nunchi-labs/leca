import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:leca_auth/leca_auth.dart';
import 'package:leca_auth/trust.dart';
import 'package:test/test.dart';

const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

void main() {
  late AuthCore core;
  late TrustStore trust;
  late HttpServer server;
  late int port;

  setUp(() async {
    final dir = Directory.systemTemp.createTempSync('leca-http');
    addTearDown(() => dir.deleteSync(recursive: true));
    core = AuthCore(config: const AuthConfig(devOtp: true));
    trust = TrustStore(path: '${dir.path}/trust.json', adminKey: 'secret');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    port = server.port;
    final pending = server.listen(
      (request) => handleAuth(core, request, trust: trust),
    );
    addTearDown(() async {
      await pending.cancel();
      await server.close(force: true);
    });
  });

  test('health, the card, the home page, and unknown paths', () async {
    final health = await _call(port, 'GET', '/health');
    expect(health.status, 200);
    expect(health.json['ok'], isTrue);

    final card = await _call(port, 'GET', '/v1/card');
    expect(card.json['id'], 'leca-kh-1');
    expect((await _call(port, 'GET', '/v1/quote')).json['id'], 'leca-kh-1');

    final home = await _call(port, 'GET', '/');
    expect(home.status, 200);
    expect(home.raw, contains('Leca sign-in'));
    expect((await _call(port, 'GET', '/index.html')).raw, contains('<html'));

    final options = await _call(port, 'OPTIONS', '/v1/quote');
    expect(options.status, 204);

    expect((await _call(port, 'GET', '/missing')).status, 404);
    expect((await _call(port, 'GET', '/missing')).json['error'], 'not_found');
    expect(
      (await _call(port, 'GET', '/tls-ask?domain=example.com')).status,
      403,
    );
    expect((await _call(port, 'GET', '/tls-ask')).status, 403);

    final links = await _call(port, 'GET', '/.well-known/assetlinks.json');
    expect(links.raw, '[]');
    final apple = await _call(
      port,
      'GET',
      '/.well-known/apple-app-site-association',
    );
    final association = jsonDecode(apple.raw) as Map<String, Object?>;
    final credentials = association['webcredentials']! as Map<String, Object?>;
    expect(credentials['apps'], isEmpty);
  });

  test('a quote is priced, and a bad body is refused', () async {
    final quote = await _call(
      port,
      'POST',
      '/v1/quote',
      json: {
        'kind': 'ride',
        'vehicle': 'tuktuk',
        'fromLat': 11.5564,
        'fromLng': 104.9282,
        'toLat': 10.4829,
        'toLng': 104.3167,
      },
    );
    expect(quote.status, 200);
    expect(quote.json['card'], 'leca-kh-1');
    expect(quote.json['cents'], greaterThanOrEqualTo(50));
    expect(quote.json['proof'], hasLength(64));

    final bad = await _call(
      port,
      'POST',
      '/v1/quote',
      json: {'kind': 'delivery', 'fromLat': 11},
    );
    expect(bad.status, 400);
    expect(bad.json['error'], 'quote_invalid');

    final array = await _call(port, 'POST', '/v1/quote', raw: '[1]');
    expect(array.status, 400);
    expect(array.json['error'], 'bad_request');

    final broken = await _call(port, 'POST', '/v1/quote', raw: '{');
    expect(broken.status, 500);
    expect(broken.json['error'], 'failed');

    final route = await _call(port, 'POST', '/v1/route', json: {});
    expect(route.status, 401);
    expect(route.json['error'], 'unauthorized');
  });

  test('email and a dev phone code sign in over HTTP', () async {
    final created = await _call(
      port,
      'POST',
      '/v1/auth/email/register',
      json: {
        'email': 'Ada@Leca.app',
        'password': 'correct-horse',
        'name': 'Ada',
      },
    );
    expect(created.status, 200);
    final token = created.json['token']! as String;
    expect(
      (created.json['user']! as Map<String, Object?>)['id'],
      'email:ada@leca.app',
    );

    final me = await _call(port, 'GET', '/v1/auth/me', token: token);
    expect(me.status, 200);
    expect((me.json['user']! as Map<String, Object?>)['displayName'], 'Ada');
    expect((await _call(port, 'GET', '/v1/auth/me')).status, 401);
    expect(
      (await _call(port, 'GET', '/v1/auth/me', token: 'nope')).json['error'],
      'unauthorized',
    );

    final again = await _call(
      port,
      'POST',
      '/v1/auth/email/login',
      json: {'email': 'ada@leca.app', 'password': 'correct-horse'},
    );
    expect(again.status, 200);
    expect(
      (await _call(
        port,
        'POST',
        '/v1/auth/email/login',
        json: {'email': 'ada@leca.app', 'password': 'wrong-password'},
      )).json['error'],
      'credentials_invalid',
    );

    final started = await _call(
      port,
      'POST',
      '/v1/auth/phone/start',
      json: {'phone': '012345678'},
    );
    expect(started.json['devCode'], hasLength(4));
    final phone = await _call(
      port,
      'POST',
      '/v1/auth/whatsapp/verify',
      json: {'phone': '012345678', 'code': started.json['devCode']},
    );
    expect(phone.status, 200);
    expect((phone.json['user']! as Map<String, Object?>)['method'], 'whatsapp');
  });

  test('a device key finishes over HTTP', () async {
    final pair = await Ed25519().newKeyPair();
    final public = await pair.extractPublicKey();
    final encoded = base64Url.encode(public.bytes).replaceAll('=', '');
    final challenge = await _call(
      port,
      'POST',
      '/v1/auth/key/challenge',
      json: {'publicKey': encoded},
    );
    expect(challenge.status, 200);
    final nonce = challenge.json['challenge']! as String;
    final signature = await Ed25519().sign(
      utf8.encode(
        keyProofMessage(challenge: nonce, publicKey: encoded, name: 'Ada'),
      ),
      keyPair: pair,
    );
    final done = await _call(
      port,
      'POST',
      '/v1/auth/key/finish',
      json: {
        'publicKey': encoded,
        'challenge': nonce,
        'signature': base64Url.encode(signature.bytes).replaceAll('=', ''),
        'name': 'Ada',
      },
    );
    expect(done.status, 200);
    expect((done.json['user']! as Map<String, Object?>)['displayName'], 'Ada');
    expect(
      (done.json['user']! as Map<String, Object?>)['id'],
      startsWith('key:'),
    );
  });

  test('admin review, a report, and an appeal go through HTTP', () async {
    final rider = await _call(
      port,
      'POST',
      '/v1/auth/email/register',
      json: {
        'email': 'rider@leca.app',
        'password': 'correct-horse',
        'name': 'Rider',
      },
    );
    final driver = await _call(
      port,
      'POST',
      '/v1/auth/email/register',
      json: {
        'email': 'driver@leca.app',
        'password': 'correct-horse',
        'name': 'Driver',
      },
    );
    final riderToken = rider.json['token']! as String;
    final driverToken = driver.json['token']! as String;

    final filed = await _call(
      port,
      'POST',
      '/v1/driver/file',
      token: driverToken,
      json: {
        'staffId': 'LECA-KH-22',
        'vehicleKind': 'car',
        'legalName': 'Driver',
        'selfie': _png,
        'idCard': _png,
      },
    );
    expect(filed.status, 200);
    expect(filed.json['review'], 'pending');
    expect(
      (await _call(port, 'POST', '/v1/driver/file', json: {})).status,
      401,
    );

    expect((await _call(port, 'GET', '/v1/admin/driver/queue')).status, 403);
    final queue = await _call(
      port,
      'GET',
      '/v1/admin/driver/queue',
      admin: 'secret',
    );
    expect(queue.status, 200);
    expect(queue.json['queue'], hasLength(1));

    final approved = await _call(
      port,
      'POST',
      '/v1/admin/driver/review',
      admin: 'secret',
      json: {
        'userId': (driver.json['user']! as Map<String, Object?>)['id'],
        'decision': 'approved',
      },
    );
    expect(approved.json['status'], 'approved');

    final report = await _call(
      port,
      'POST',
      '/v1/report',
      token: riderToken,
      json: {'category': 'harassment', 'subjectId': 'LECA-KH-22'},
    );
    expect(report.json['status'], 'suspended');
    final suspended = await _call(port, 'GET', '/v1/suspended');
    expect(suspended.json['staffIds'], contains('LECA-KH-22'));

    final status = await _call(
      port,
      'GET',
      '/v1/driver/status',
      token: driverToken,
    );
    expect(status.json['suspended'], isTrue);
    expect(status.json['reports'], hasLength(1));

    final appeal = await _call(
      port,
      'POST',
      '/v1/report/appeal',
      token: driverToken,
      json: {'id': report.json['id'], 'note': 'wrong rider'},
    );
    expect(appeal.json['status'], 'appealed');
    final open = await _call(
      port,
      'GET',
      '/v1/admin/report/open',
      admin: 'secret',
    );
    expect(open.json['reports'], hasLength(1));

    final cleared = await _call(
      port,
      'POST',
      '/v1/admin/report/resolve',
      admin: 'secret',
      json: {'id': report.json['id'], 'decision': 'cleared'},
    );
    expect(cleared.json['status'], 'cleared');
    expect(
      (await _call(port, 'GET', '/v1/suspended')).json['staffIds'],
      isEmpty,
    );
  });

  test('a provider dev page and a missing pending id', () async {
    final start = await _call(
      port,
      'POST',
      '/v1/auth/provider/start',
      json: {'provider': 'google'},
    );
    expect(start.status, 200);
    expect(start.json['mode'], 'test');
    final page = await _call(
      port,
      'GET',
      '/v1/auth/dev/google?state=${start.json['pending']}',
    );
    expect(page.status, 200);
    expect(page.raw, contains('google'));
    final pending = await _call(port, 'GET', '/v1/auth/pending/missing');
    expect(pending.status, 404);
    expect(pending.json['error'], 'pending_expired');
  });

  test('the proof of a published quote is the fare body', () async {
    final quote = await _call(
      port,
      'POST',
      '/v1/quote',
      json: {
        'kind': 'delivery',
        'fromLat': 11.55,
        'fromLng': 104.92,
        'toLat': 11.56,
        'toLng': 104.93,
        'hours': 3,
      },
    );
    final body =
        'leca-fare/2\n'
        'card=${quote.json['card']}\n'
        'kind=${quote.json['kind']}\n'
        'vehicle=${quote.json['vehicle']}\n'
        'meters=${quote.json['meters']}\n'
        'minutes=${quote.json['minutes']}\n'
        'hours=${quote.json['hours']}\n'
        'fare=${quote.json['cents']}\n';
    expect(
      crypto.sha256.convert(utf8.encode(body)).toString(),
      quote.json['proof'],
    );
    expect(quote.json['hours'], 3);
  });
}

class _Reply {
  _Reply(this.status, this.raw);

  final int status;
  final String raw;

  Map<String, Object?> get json {
    final decoded = jsonDecode(raw);
    return (decoded as Map).map((key, value) => MapEntry('$key', value));
  }
}

Future<_Reply> _call(
  int port,
  String method,
  String path, {
  Object? json,
  String? raw,
  String? token,
  String? admin,
}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(
      method,
      Uri.parse('http://127.0.0.1:$port$path'),
    );
    if (token != null) request.headers.set('authorization', 'Bearer $token');
    if (admin != null) request.headers.set('x-admin-key', admin);
    final payload = raw ?? (json == null ? null : jsonEncode(json));
    if (payload != null) {
      request.headers.contentType = ContentType.json;
      request.write(payload);
    }
    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();
    return _Reply(response.statusCode, text);
  } finally {
    client.close(force: true);
  }
}
