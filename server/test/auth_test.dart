import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:leca_auth/cbor.dart';
import 'package:leca_auth/leca_auth.dart';
import 'package:pointycastle/export.dart';
import 'package:test/test.dart';

class ScriptedNet extends Net {
  ScriptedNet(this.pages);

  final Map<String, String> pages;

  @override
  Future<NetResponse> get(Uri uri, {Map<String, String>? headers}) async {
    return NetResponse(200, pages['${uri.host}${uri.path}'] ?? '{}');
  }

  @override
  Future<NetResponse> postForm(
    Uri uri,
    Map<String, String> fields, {
    Map<String, String>? headers,
  }) {
    return get(uri);
  }

  @override
  Future<NetResponse> postJson(
    Uri uri,
    Object body, {
    Map<String, String>? headers,
  }) {
    return get(uri);
  }
}

String _hostHint(String provider) {
  switch (provider) {
    case 'wechat':
      return 'weixin';
    case 'x':
      return 'twitter.com';
    case 'telegram':
      return 'telegram.org';
    default:
      return provider;
  }
}

void main() {
  test('email register then login, and rejects a bad password', () async {
    final core = AuthCore(config: const AuthConfig());
    final created = await core.emailRegister(
      email: 'Sokha@Leca.app',
      password: 'correct-horse',
      name: 'Sokha',
    );
    expect((created['user']! as Map)['id'], 'email:sokha@leca.app');
    expect((created['user']! as Map)['displayName'], 'Sokha');
    expect(
      () =>
          core.emailRegister(email: 'sokha@leca.app', password: 'another-one'),
      throwsA(predicate<AuthFailure>((e) => e.code == 'email_taken')),
    );
    expect(
      () => core.emailRegister(email: 'nope', password: 'long-enough'),
      throwsA(predicate<AuthFailure>((e) => e.code == 'email_invalid')),
    );
    expect(
      () => core.emailRegister(email: 'a@b.co', password: 'short'),
      throwsA(predicate<AuthFailure>((e) => e.code == 'password_short')),
    );
    final signed = await core.emailLogin(
      email: 'sokha@leca.app',
      password: 'correct-horse',
    );
    expect((signed['user']! as Map)['method'], 'email');
    expect(
      () =>
          core.emailLogin(email: 'sokha@leca.app', password: 'wrong-password'),
      throwsA(predicate<AuthFailure>((e) => e.code == 'credentials_invalid')),
    );
    expect(
      () =>
          core.emailLogin(email: 'missing@leca.app', password: 'correct-horse'),
      throwsA(predicate<AuthFailure>((e) => e.code == 'credentials_invalid')),
    );
  });

  test('an email session is still valid after a restart', () async {
    final dir = Directory.systemTemp.createTempSync('leca-email');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/accounts.json';
    final first = AuthCore(config: const AuthConfig(), accountPath: path);
    final created = await first.emailRegister(
      email: 'sokha@leca.app',
      password: 'correct-horse',
      name: 'Sokha',
    );
    final token = created['token']! as String;
    final second = AuthCore(config: const AuthConfig(), accountPath: path);
    expect(second.userForToken(token)?.displayName, 'Sokha');
    final again = await second.emailLogin(
      email: 'sokha@leca.app',
      password: 'correct-horse',
    );
    expect(again['token'], isNotEmpty);
  });

  test('phone dev code signs the same number in', () async {
    final core = AuthCore(config: const AuthConfig(devOtp: true));
    final started = await core.whatsappStart('012 345 678');
    final code = started['devCode']! as String;
    expect(code, hasLength(4));
    final session = await core.whatsappVerify('012345678', code);
    final user = session['user']! as Map;
    expect(user['method'], 'whatsapp');
    expect(user['id'], 'whatsapp:012345678');
    expect(core.userForToken(session['token']! as String)?.handle, '012345678');
    expect(
      () => core.whatsappVerify('012345678', code),
      throwsA(isA<AuthFailure>()),
    );
  });

  test('a short phone and a wrong code are rejected', () async {
    final core = AuthCore(config: const AuthConfig(devOtp: true));
    expect(() => core.whatsappStart('123'), throwsA(isA<AuthFailure>()));
    await core.whatsappStart('012345678');
    expect(
      () => core.whatsappVerify('012345678', '0000'),
      throwsA(isA<AuthFailure>()),
    );
  });

  test('whatsapp stays closed without a sender or the dev flag', () {
    final core = AuthCore(config: const AuthConfig());
    expect(
      () => core.whatsappStart('012345678'),
      throwsA(predicate<AuthFailure>((e) => e.code == 'whatsapp_unconfigured')),
    );
  });

  test('google, facebook, and wechat exchange a code for a session', () async {
    final net = ScriptedNet({
      'oauth2.googleapis.com/token': jsonEncode({'access_token': 'g'}),
      'www.googleapis.com/oauth2/v3/userinfo': jsonEncode({
        'sub': 'g1',
        'email': 'ada@leca.app',
        'name': 'Ada',
      }),
      'graph.facebook.com/v21.0/oauth/access_token': jsonEncode({
        'access_token': 'f',
      }),
      'graph.facebook.com/me': jsonEncode({
        'id': 'f1',
        'name': 'Grace',
        'email': 'grace@leca.app',
      }),
      'api.weixin.qq.com/sns/oauth2/access_token': jsonEncode({
        'access_token': 'w',
        'openid': 'wx1',
      }),
      'api.weixin.qq.com/sns/userinfo': jsonEncode({
        'openid': 'wx1',
        'nickname': 'Wei',
      }),
      'oauth.telegram.org/token': jsonEncode({'access_token': 't'}),
      'oauth.telegram.org/userinfo': jsonEncode({
        'id': 'tg1',
        'name': 'Tara',
        'preferred_username': 'tara',
      }),
      'api.x.com/2/oauth2/token': jsonEncode({'access_token': 'x'}),
      'api.x.com/2/users/me': jsonEncode({
        'data': {'id': 'x1', 'name': 'Xan', 'username': 'xan'},
      }),
    });
    final core = AuthCore(
      config: const AuthConfig(
        googleClientId: 'gid',
        googleClientSecret: 'gsec',
        facebookAppId: 'fid',
        facebookAppSecret: 'fsec',
        wechatAppId: 'wid',
        wechatAppSecret: 'wsec',
        telegramBotToken: '100:bot-secret',
        xClientId: 'xid',
        xClientSecret: 'xsec',
      ),
      net: net,
    );
    for (final provider in ['google', 'facebook', 'wechat', 'telegram', 'x']) {
      final start = await core.providerStart(provider);
      expect(start['url'], contains(_hostHint(provider)));
      if (provider == 'x') {
        expect(start['url'], contains('code_challenge'));
      }
      final html = await core.providerCallback(
        provider,
        'auth-code',
        start['pending']! as String,
      );
      expect(html, contains('Signed in'));
      final ready = core.pending(start['pending']! as String);
      expect(ready['status'], 'ready');
      expect((ready['user']! as Map)['method'], provider);
    }
  });

  test('a provider without secrets is not started', () {
    final core = AuthCore(config: const AuthConfig());
    expect(
      () => core.providerStart('wechat'),
      throwsA(predicate<AuthFailure>((e) => e.code == 'provider_unconfigured')),
    );
  });

  test(
    'dev mode signs in Google, Facebook, and WeChat without those consoles',
    () async {
      final core = AuthCore(
        config: const AuthConfig(
          devOtp: true,
          publicUrl: 'http://65.21.232.29:8088',
        ),
      );
      for (final provider in [
        'google',
        'facebook',
        'wechat',
        'telegram',
        'x',
      ]) {
        final start = await core.providerStart(provider);
        expect(start['mode'], 'test');
        expect(start['url'], contains('/v1/auth/dev/$provider'));
        final html = await core.providerCallback(
          provider,
          'dev',
          start['pending']! as String,
        );
        expect(html, contains('Signed in'));
        final ready = core.pending(start['pending']! as String);
        expect((ready['user']! as Map)['method'], provider);
      }
    },
  );

  test('the http server completes a dev phone login', () async {
    final core = AuthCore(config: const AuthConfig(devOtp: true));
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    final pending = server.listen((request) => handleAuth(core, request));
    addTearDown(() async {
      await pending.cancel();
      await server.close(force: true);
    });

    final client = HttpClient();
    addTearDown(client.close);
    final start = await client.postUrl(
      Uri.parse('http://127.0.0.1:$port/v1/auth/phone/start'),
    );
    start.headers.contentType = ContentType.json;
    start.write(jsonEncode({'phone': '012345678'}));
    final startBody =
        jsonDecode(await utf8.decoder.bind(await start.close()).join()) as Map;
    final verify = await client.postUrl(
      Uri.parse('http://127.0.0.1:$port/v1/auth/phone/verify'),
    );
    verify.headers.contentType = ContentType.json;
    verify.write(
      jsonEncode({'phone': '012345678', 'code': startBody['devCode']}),
    );
    final verifyResponse = await verify.close();
    final session =
        jsonDecode(await utf8.decoder.bind(verifyResponse).join())
            as Map<String, Object?>;
    expect(verifyResponse.statusCode, 200);
    expect(session['token'], isNotEmpty);
  });

  test('a device key signs in without a name, then keeps one', () async {
    expect(
      keyProofMessage(challenge: 'c', publicKey: 'p', name: ''),
      'leca-key/1\nc\np\n\n',
    );
    final pair = await Ed25519().newKeyPair();
    final public = await pair.extractPublicKey();
    final pub = base64Url.encode(public.bytes).replaceAll('=', '');
    final dir = Directory.systemTemp.createTempSync('leca-key');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/accounts.json';
    final core = AuthCore(config: const AuthConfig(), accountPath: path);

    Future<Map<String, Object?>> finish(String name) async {
      final started = await core.keyChallenge(pub);
      final challenge = started['challenge']! as String;
      final signature = await Ed25519().sign(
        utf8.encode(
          keyProofMessage(challenge: challenge, publicKey: pub, name: name),
        ),
        keyPair: pair,
      );
      final raw = base64Url.encode(signature.bytes).replaceAll('=', '');
      return core.keyFinish(
        publicKey: pub,
        challenge: challenge,
        signature: raw,
        name: name,
      );
    }

    final created = await finish('');
    final user = created['user']! as Map;
    expect(user['method'], 'key');
    expect(user['id'], startsWith('key:'));
    expect((user['id'] as String).length, 4 + 64);
    expect(user['displayName'], user['handle']);
    expect(
      () => core.keyFinish(
        publicKey: pub,
        challenge: 'nope',
        signature: 'aa',
        name: '',
      ),
      throwsA(predicate<AuthFailure>((e) => e.code == 'challenge_invalid')),
    );
    final named = await finish('Sokha');
    expect((named['user']! as Map)['displayName'], 'Sokha');
    expect((named['user']! as Map)['id'], user['id']);
    final restarted = AuthCore(config: const AuthConfig(), accountPath: path);
    final again = await restarted.keyChallenge(pub);
    expect(again['known'], isTrue);
    expect(again['displayName'], 'Sokha');
    final bad = await restarted.keyChallenge(pub);
    final wrong = await Ed25519().sign(utf8.encode('nope'), keyPair: pair);
    expect(
      () => restarted.keyFinish(
        publicKey: pub,
        challenge: bad['challenge']! as String,
        signature: base64Url.encode(wrong.bytes).replaceAll('=', ''),
        name: 'Sokha',
      ),
      throwsA(predicate<AuthFailure>((e) => e.code == 'signature_invalid')),
    );
  });

  test('traffic route reports the jam, not the empty-road time', () async {
    final net = ScriptedNet({
      'routes.googleapis.com/directions/v2:computeRoutes':
          '{"routes":[{"duration":"660s","staticDuration":"420s","distanceMeters":3100}]}',
    });
    final core = AuthCore(
      config: const AuthConfig(googleMapsKey: 'test-key'),
      net: net,
    );
    final live = await core.trafficRoute({
      'originLat': 11.55,
      'originLng': 104.92,
      'destLat': 11.57,
      'destLng': 104.93,
    });
    expect(live['minutes'], 11);
    expect(live['seconds'], 660);
    expect(live['traffic'], isTrue);
    final bare = AuthCore(config: const AuthConfig());
    expect(
      () => bare.trafficRoute({
        'originLat': 11.55,
        'originLng': 104.92,
        'destLat': 11.57,
        'destLng': 104.93,
      }),
      throwsA(predicate<AuthFailure>((e) => e.code == 'route_unconfigured')),
    );
  });

  test('a passkey registers and signs in', () async {
    final random = FortunaRandom()
      ..seed(
        KeyParameter(Uint8List.fromList(List<int>.generate(32, (i) => i + 1))),
      );
    final generator = ECKeyGenerator()
      ..init(
        ParametersWithRandom(
          ECKeyGeneratorParameters(ECCurve_secp256r1()),
          random,
        ),
      );
    final pair = generator.generateKeyPair();
    final private = pair.privateKey;
    final point = pair.publicKey.Q!;
    final x = _fixed(point.x!.toBigInteger()!);
    final y = _fixed(point.y!.toBigInteger()!);
    final core = AuthCore(config: const AuthConfig());
    final started = core.passkeyRegisterStart(name: 'Ada');
    final challenge = started['challenge']! as String;
    final credId = Uint8List.fromList(List<int>.generate(16, (i) => i + 3));
    final cose = Cbor.encode({1: 2, 3: -7, -1: 1, -2: x, -3: y});
    final rpHash = sha256.convert(utf8.encode('127.0.0.1')).bytes;
    final auth = BytesBuilder(copy: false)
      ..add(rpHash)
      ..addByte(0x45)
      ..add(const [0, 0, 0, 1])
      ..add(Uint8List(16))
      ..addByte(0)
      ..addByte(credId.length)
      ..add(credId)
      ..add(cose);
    final attestation = Cbor.encode({
      'fmt': 'none',
      'attStmt': <Object?, Object?>{},
      'authData': auth.toBytes(),
    });
    final client = jsonEncode({
      'type': 'webauthn.create',
      'challenge': challenge,
      'origin': 'http://127.0.0.1:8080',
    });
    final created = await core.passkeyRegisterFinish(
      challenge: challenge,
      clientDataJSON: base64Url.encode(utf8.encode(client)).replaceAll('=', ''),
      attestationObject: base64Url.encode(attestation).replaceAll('=', ''),
    );
    final user = created['user']! as Map;
    expect(user['method'], 'passkey');
    expect(user['displayName'], 'Ada');

    final login = core.passkeyLoginStart();
    final loginChallenge = login['challenge']! as String;
    final loginAuth = BytesBuilder(copy: false)
      ..add(rpHash)
      ..addByte(0x05)
      ..add(const [0, 0, 0, 2]);
    final loginClient = jsonEncode({
      'type': 'webauthn.get',
      'challenge': loginChallenge,
      'origin': 'http://127.0.0.1:8080',
    });
    final loginClientBytes = utf8.encode(loginClient);
    final message = <int>[
      ...loginAuth.toBytes(),
      ...sha256.convert(loginClientBytes).bytes,
    ];
    final signer = ECDSASigner(SHA256Digest())
      ..init(
        true,
        ParametersWithRandom(
          PrivateKeyParameter<ECPrivateKey>(private),
          random,
        ),
      );
    final signature =
        signer.generateSignature(Uint8List.fromList(message)) as ECSignature;
    final raw = <int>[..._fixed(signature.r), ..._fixed(signature.s)];
    final signed = await core.passkeyLoginFinish(
      id: base64Url.encode(credId).replaceAll('=', ''),
      challenge: loginChallenge,
      clientDataJSON: base64Url.encode(loginClientBytes).replaceAll('=', ''),
      authenticatorData: base64Url
          .encode(loginAuth.toBytes())
          .replaceAll('=', ''),
      signature: base64Url.encode(raw).replaceAll('=', ''),
    );
    expect((signed['user']! as Map)['id'], user['id']);
  });
}

List<int> _fixed(BigInt n) {
  final hex = n.toUnsigned(256).toRadixString(16).padLeft(64, '0');
  return [
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ];
}
