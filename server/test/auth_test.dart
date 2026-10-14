import 'dart:convert';
import 'dart:io';

import 'package:chow_auth/chow_auth.dart';
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

void main() {
  test('email register then login, and rejects a bad password', () async {
    final core = AuthCore(config: const AuthConfig());
    final created = await core.emailRegister(
      email: 'Sokha@Chow.app',
      password: 'correct-horse',
      name: 'Sokha',
    );
    expect((created['user'] as Map)['id'], 'email:sokha@chow.app');
    expect((created['user'] as Map)['displayName'], 'Sokha');
    expect(
      () => core.emailRegister(email: 'sokha@chow.app', password: 'another-one'),
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
      email: 'sokha@chow.app',
      password: 'correct-horse',
    );
    expect((signed['user'] as Map)['method'], 'email');
    expect(
      () => core.emailLogin(email: 'sokha@chow.app', password: 'wrong-password'),
      throwsA(predicate<AuthFailure>((e) => e.code == 'credentials_invalid')),
    );
    expect(
      () => core.emailLogin(email: 'missing@chow.app', password: 'correct-horse'),
      throwsA(predicate<AuthFailure>((e) => e.code == 'credentials_invalid')),
    );
  });

  test('phone dev code signs the same number in', () async {
    final core = AuthCore(config: const AuthConfig(devOtp: true));
    final started = await core.phoneStart('012 345 678');
    final code = started['devCode'] as String;
    expect(code, hasLength(4));
    final session = await core.phoneVerify('012345678', code);
    final user = session['user'] as Map;
    expect(user['method'], 'phone');
    expect(user['id'], 'phone:012345678');
    expect(core.userForToken(session['token'] as String)?.handle, '012345678');
    expect(() => core.phoneVerify('012345678', code), throwsA(isA<AuthFailure>()));
  });

  test('a short phone and a wrong code are rejected', () async {
    final core = AuthCore(config: const AuthConfig(devOtp: true));
    expect(() => core.phoneStart('123'), throwsA(isA<AuthFailure>()));
    await core.phoneStart('012345678');
    expect(
      () => core.phoneVerify('012345678', '0000'),
      throwsA(isA<AuthFailure>()),
    );
  });

  test('sms stays closed without Twilio or the dev flag', () {
    final core = AuthCore(config: const AuthConfig());
    expect(
      () => core.phoneStart('012345678'),
      throwsA(
        predicate<AuthFailure>((e) => e.code == 'sms_unconfigured'),
      ),
    );
  });

  test('google, facebook, and wechat exchange a code for a session', () async {
    final net = ScriptedNet({
      'oauth2.googleapis.com/token': jsonEncode({'access_token': 'g'}),
      'www.googleapis.com/oauth2/v3/userinfo': jsonEncode({
        'sub': 'g1',
        'email': 'ada@chow.app',
        'name': 'Ada',
      }),
      'graph.facebook.com/v21.0/oauth/access_token': jsonEncode({
        'access_token': 'f',
      }),
      'graph.facebook.com/me': jsonEncode({
        'id': 'f1',
        'name': 'Grace',
        'email': 'grace@chow.app',
      }),
      'api.weixin.qq.com/sns/oauth2/access_token': jsonEncode({
        'access_token': 'w',
        'openid': 'wx1',
      }),
      'api.weixin.qq.com/sns/userinfo': jsonEncode({
        'openid': 'wx1',
        'nickname': 'Wei',
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
      ),
      net: net,
    );
    for (final provider in ['google', 'facebook', 'wechat']) {
      final start = await core.providerStart(provider);
      expect(start['url'], contains(provider == 'wechat' ? 'weixin' : provider));
      final html = await core.providerCallback(
        provider,
        'auth-code',
        start['pending'] as String,
      );
      expect(html, contains('Signed in'));
      final ready = core.pending(start['pending'] as String);
      expect(ready['status'], 'ready');
      expect((ready['user'] as Map)['method'], provider);
    }
  });

  test('a provider without secrets is not started', () {
    final core = AuthCore(config: const AuthConfig());
    expect(
      () => core.providerStart('wechat'),
      throwsA(
        predicate<AuthFailure>((e) => e.code == 'provider_unconfigured'),
      ),
    );
  });

  test('dev mode signs in Google, Facebook, and WeChat without those consoles', () async {
    final core = AuthCore(
      config: const AuthConfig(
        devOtp: true,
        publicUrl: 'http://65.21.232.29:8088',
      ),
    );
    for (final provider in ['google', 'facebook', 'wechat']) {
      final start = await core.providerStart(provider);
      expect(start['mode'], 'test');
      expect(start['url'], contains('/v1/auth/dev/$provider'));
      final html = await core.providerCallback(
        provider,
        'dev',
        start['pending'] as String,
      );
      expect(html, contains('Signed in'));
      final ready = core.pending(start['pending'] as String);
      expect((ready['user'] as Map)['method'], provider);
    }
  });

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
    final startBody = jsonDecode(
      await utf8.decoder.bind(await start.close()).join(),
    ) as Map;
    final verify = await client.postUrl(
      Uri.parse('http://127.0.0.1:$port/v1/auth/phone/verify'),
    );
    verify.headers.contentType = ContentType.json;
    verify.write(
      jsonEncode({'phone': '012345678', 'code': startBody['devCode']}),
    );
    final verifyResponse = await verify.close();
    final session = jsonDecode(await utf8.decoder.bind(verifyResponse).join());
    expect(verifyResponse.statusCode, 200);
    expect(session['token'], isNotEmpty);
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
}
