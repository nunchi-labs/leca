import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'password.dart';
import 'quote.dart';
import 'trust.dart';

class AuthFailure implements Exception {
  AuthFailure(this.code, [this.status = 400]);

  final String code;
  final int status;
}

class AuthConfig {
  const AuthConfig({
    this.publicUrl = 'http://127.0.0.1:8080',
    this.googleClientId = '',
    this.googleClientSecret = '',
    this.facebookAppId = '',
    this.facebookAppSecret = '',
    this.wechatAppId = '',
    this.wechatAppSecret = '',
    this.twilioAccountSid = '',
    this.twilioAuthToken = '',
    this.twilioFrom = '',
    this.devOtp = false,
    this.googleMapsKey = '',
  });

  final String publicUrl;
  final String googleClientId;
  final String googleClientSecret;
  final String facebookAppId;
  final String facebookAppSecret;
  final String wechatAppId;
  final String wechatAppSecret;
  final String twilioAccountSid;
  final String twilioAuthToken;
  final String twilioFrom;
  final bool devOtp;
  final String googleMapsKey;

  bool get googleReady =>
      googleClientId.isNotEmpty && googleClientSecret.isNotEmpty;

  bool get facebookReady =>
      facebookAppId.isNotEmpty && facebookAppSecret.isNotEmpty;

  bool get wechatReady => wechatAppId.isNotEmpty && wechatAppSecret.isNotEmpty;

  bool get twilioReady =>
      twilioAccountSid.isNotEmpty &&
      twilioAuthToken.isNotEmpty &&
      twilioFrom.isNotEmpty;

  static AuthConfig fromEnvironment() {
    final env = Platform.environment;
    return AuthConfig(
      publicUrl: env['PUBLIC_URL'] ?? 'http://127.0.0.1:8080',
      googleClientId: env['GOOGLE_CLIENT_ID'] ?? '',
      googleClientSecret: env['GOOGLE_CLIENT_SECRET'] ?? '',
      facebookAppId: env['FACEBOOK_APP_ID'] ?? '',
      facebookAppSecret: env['FACEBOOK_APP_SECRET'] ?? '',
      wechatAppId: env['WECHAT_APP_ID'] ?? '',
      wechatAppSecret: env['WECHAT_APP_SECRET'] ?? '',
      twilioAccountSid: env['TWILIO_ACCOUNT_SID'] ?? '',
      twilioAuthToken: env['TWILIO_AUTH_TOKEN'] ?? '',
      twilioFrom: env['TWILIO_FROM'] ?? '',
      devOtp: env['LECA_DEV_OTP'] == '1',
      googleMapsKey: env['GOOGLE_MAPS_API_KEY'] ?? '',
    );
  }
}

class NetResponse {
  const NetResponse(this.status, this.body);

  final int status;
  final String body;
}

class Net {
  const Net();

  Future<NetResponse> get(Uri uri, {Map<String, String>? headers}) {
    return _send('GET', uri, headers: headers);
  }

  Future<NetResponse> postForm(
    Uri uri,
    Map<String, String> fields, {
    Map<String, String>? headers,
  }) {
    return _send(
      'POST',
      uri,
      headers: {
        'content-type': 'application/x-www-form-urlencoded',
        ...?headers,
      },
      body: fields.entries
          .map(
            (e) =>
                '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
          )
          .join('&'),
    );
  }

  Future<NetResponse> postJson(
    Uri uri,
    Object body, {
    Map<String, String>? headers,
  }) {
    return _send(
      'POST',
      uri,
      headers: {'content-type': 'application/json', ...?headers},
      body: jsonEncode(body),
    );
  }

  Future<NetResponse> _send(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    String? body,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, uri);
      headers?.forEach(request.headers.set);
      if (body != null) request.write(body);
      final response = await request.close();
      final text = await utf8.decoder.bind(response).join();
      return NetResponse(response.statusCode, text);
    } finally {
      client.close(force: true);
    }
  }
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.method,
    required this.displayName,
    required this.handle,
  });

  final String id;
  final String method;
  final String displayName;
  final String handle;

  Map<String, Object?> toJson() => {
    'id': id,
    'method': method,
    'displayName': displayName,
    'handle': handle,
  };
}

class _EmailAccount {
  _EmailAccount({
    required this.salt,
    required this.hash,
    required this.displayName,
  });

  final String salt;
  final String hash;
  final String displayName;
}

class _Otp {
  _Otp(this.code, this.expires);

  final String code;
  final DateTime expires;
  int tries = 0;
}

class _Pending {
  _Pending(this.provider, this.expires);

  final String provider;
  final DateTime expires;
  String status = 'pending';
  String? error;
  String? token;
}

class AuthCore {
  AuthCore({
    required this.config,
    Net? net,
    DateTime Function()? now,
    Random? random,
    this.accountPath,
  }) : net = net ?? const Net(),
       now = now ?? DateTime.now,
       _random = random ?? Random.secure() {
    _loadAccounts();
  }

  final AuthConfig config;
  final Net net;
  final DateTime Function() now;
  final Random _random;
  final String? accountPath;
  final Map<String, _Otp> _otps = {};
  final Map<String, _Pending> _pending = {};
  final Map<String, AuthUser> _sessions = {};
  final Map<String, _EmailAccount> _emails = {};

  Future<Map<String, Object?>> phoneStart(String rawPhone) async {
    final phone = _digits(rawPhone);
    if (phone.length < 8) throw AuthFailure('phone_invalid');
    if (!config.twilioReady && !config.devOtp) {
      throw AuthFailure('sms_unconfigured', 503);
    }
    final code = _random.nextInt(10000).toString().padLeft(4, '0');
    _otps[phone] = _Otp(code, now().add(const Duration(minutes: 5)));
    if (config.twilioReady) {
      await _sendSms(phone, code);
    }
    return {'ok': true, if (config.devOtp) 'devCode': code};
  }

  Future<Map<String, Object?>> phoneVerify(String rawPhone, String code) {
    final phone = _digits(rawPhone);
    if (phone.length < 8) throw AuthFailure('phone_invalid');
    final otp = _otps[phone];
    if (otp == null || now().isAfter(otp.expires) || otp.tries >= 5) {
      _otps.remove(phone);
      throw AuthFailure('code_invalid');
    }
    if (otp.code != code.trim()) {
      otp.tries += 1;
      throw AuthFailure('code_invalid');
    }
    _otps.remove(phone);
    final user = AuthUser(
      id: 'phone:$phone',
      method: 'phone',
      displayName: phone,
      handle: phone,
    );
    return Future.value(_issue(user));
  }

  Future<Map<String, Object?>> emailRegister({
    required String email,
    required String password,
    String name = '',
  }) {
    final address = _email(email);
    if (password.length < 8) throw AuthFailure('password_short');
    if (_emails.containsKey(address)) throw AuthFailure('email_taken');
    final salt = base64Encode(newSalt(_random));
    final display = name.trim().isEmpty
        ? address.split('@').first
        : name.trim();
    _emails[address] = _EmailAccount(
      salt: salt,
      hash: hashPassword(password, base64Decode(salt)),
      displayName: display,
    );
    _saveAccounts();
    return Future.value(
      _issue(
        AuthUser(
          id: 'email:$address',
          method: 'email',
          displayName: display,
          handle: address,
        ),
      ),
    );
  }

  Future<Map<String, Object?>> emailLogin({
    required String email,
    required String password,
  }) {
    final address = _email(email);
    final account = _emails[address];
    final salt = account == null
        ? base64Encode(List<int>.filled(16, 0))
        : account.salt;
    final actual =
        account?.hash ?? hashPassword('missing-account', base64Decode(salt));
    final offered = hashPassword(password, base64Decode(salt));
    if (account == null || !sameHash(actual, offered)) {
      throw AuthFailure('credentials_invalid');
    }
    return Future.value(
      _issue(
        AuthUser(
          id: 'email:$address',
          method: 'email',
          displayName: account.displayName,
          handle: address,
        ),
      ),
    );
  }

  String _email(String raw) {
    final address = raw.trim().toLowerCase();
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(address);
    if (!ok) throw AuthFailure('email_invalid');
    return address;
  }

  void _loadAccounts() {
    final path = accountPath;
    if (path == null) return;
    final file = File(path);
    if (!file.existsSync()) return;
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map) return;
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is! Map) continue;
      _emails['${entry.key}'] = _EmailAccount(
        salt: '${value['salt']}',
        hash: '${value['hash']}',
        displayName: '${value['displayName']}',
      );
    }
  }

  void _saveAccounts() {
    final path = accountPath;
    if (path == null) return;
    final file = File(path);
    file.parent.createSync(recursive: true);
    final data = {
      for (final entry in _emails.entries)
        entry.key: {
          'salt': entry.value.salt,
          'hash': entry.value.hash,
          'displayName': entry.value.displayName,
        },
    };
    file.writeAsStringSync(jsonEncode(data));
  }

  Future<Map<String, Object?>> providerStart(String provider) async {
    if (!_known(provider)) throw AuthFailure('provider_invalid');
    final id = _token();
    _pending[id] = _Pending(provider, now().add(const Duration(minutes: 10)));
    if (_ready(provider)) {
      return {
        'pending': id,
        'mode': 'live',
        'url': _authorizeUrl(provider, id),
      };
    }
    if (config.devOtp) {
      return {
        'pending': id,
        'mode': 'test',
        'url': '${config.publicUrl}/v1/auth/dev/$provider?state=$id',
      };
    }
    _pending.remove(id);
    throw AuthFailure('provider_unconfigured', 503);
  }

  String devPage(String provider, String? state) {
    if (!config.devOtp || !_known(provider)) {
      return _page('Sign-in failed', 'Test sign-in is off.');
    }
    final item = state == null ? null : _pending[state];
    if (item == null || item.provider != provider) {
      return _page('Sign-in failed', 'That login attempt is unknown.');
    }
    final user = _devUser(provider);
    final next = _callback(provider);
    final url = '$next?code=dev&state=${Uri.encodeQueryComponent(state!)}';
    return '''
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Test ${user.method}</title>
<meta http-equiv="refresh" content="0;url=$url">
</head>
<body style="font-family: sans-serif; padding: 2rem;">
<h1>Test ${user.method} sign-in</h1>
<p>${user.displayName} · ${user.handle}</p>
<p><a href="$url">Continue</a></p>
</body></html>
''';
  }

  Map<String, Object?> pending(String id) {
    final item = _pending[id];
    if (item == null || now().isAfter(item.expires)) {
      throw AuthFailure('pending_expired', 404);
    }
    if (item.status == 'ready' && item.token != null) {
      final user = _sessions[item.token!];
      return {'status': 'ready', 'token': item.token, 'user': user?.toJson()};
    }
    if (item.status == 'error') {
      return {'status': 'error', 'error': item.error ?? 'failed'};
    }
    return {'status': 'pending'};
  }

  AuthUser? userForToken(String token) => _sessions[token];

  Future<String> providerCallback(
    String provider,
    String? code,
    String? state,
  ) async {
    final item = state == null ? null : _pending[state];
    if (item == null || item.provider != provider) {
      return _page('Sign-in failed', 'That login attempt is unknown.');
    }
    if (code == null || code.isEmpty) {
      item.status = 'error';
      item.error = 'provider_denied';
      return _page('Sign-in cancelled', 'Return to Leca and try again.');
    }
    try {
      final user = await _profile(provider, code);
      final token = _token();
      _sessions[token] = user;
      item
        ..status = 'ready'
        ..token = token;
      return _page(
        'Signed in',
        'You can return to Leca. This window can close.',
      );
    } on AuthFailure catch (e) {
      item
        ..status = 'error'
        ..error = e.code;
      return _page('Sign-in failed', 'Leca could not verify that account.');
    }
  }

  AuthUser _devUser(String provider) {
    switch (provider) {
      case 'google':
        return const AuthUser(
          id: 'google:dev',
          method: 'google',
          displayName: 'Ada Test',
          handle: 'ada@leca.app',
        );
      case 'facebook':
        return const AuthUser(
          id: 'facebook:dev',
          method: 'facebook',
          displayName: 'Grace Test',
          handle: 'grace@leca.app',
        );
      case 'wechat':
        return const AuthUser(
          id: 'wechat:dev',
          method: 'wechat',
          displayName: 'Wei Test',
          handle: 'wx-dev',
        );
      default:
        throw AuthFailure('provider_invalid');
    }
  }

  Future<AuthUser> _profile(String provider, String code) async {
    if (code == 'dev') {
      if (!config.devOtp) throw AuthFailure('provider_failed', 403);
      return _devUser(provider);
    }
    switch (provider) {
      case 'google':
        return _google(code);
      case 'facebook':
        return _facebook(code);
      case 'wechat':
        return _wechat(code);
      default:
        throw AuthFailure('provider_invalid');
    }
  }

  Future<AuthUser> _google(String code) async {
    final redirect = _callback('google');
    final token = await _json(
      await net.postForm(Uri.parse('https://oauth2.googleapis.com/token'), {
        'code': code,
        'client_id': config.googleClientId,
        'client_secret': config.googleClientSecret,
        'redirect_uri': redirect,
        'grant_type': 'authorization_code',
      }),
    );
    final access = token['access_token'] as String?;
    if (access == null || access.isEmpty) {
      throw AuthFailure('provider_failed', 502);
    }
    final profile = await _json(
      await net.get(
        Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
        headers: {'authorization': 'Bearer $access'},
      ),
    );
    final sub = '${profile['sub'] ?? ''}';
    if (sub.isEmpty) throw AuthFailure('provider_failed', 502);
    final email = '${profile['email'] ?? sub}';
    final name = '${profile['name'] ?? email}';
    return AuthUser(
      id: 'google:$sub',
      method: 'google',
      displayName: name,
      handle: email,
    );
  }

  Future<AuthUser> _facebook(String code) async {
    final redirect = _callback('facebook');
    final token = await _json(
      await net.get(
        Uri.https('graph.facebook.com', '/v21.0/oauth/access_token', {
          'client_id': config.facebookAppId,
          'client_secret': config.facebookAppSecret,
          'redirect_uri': redirect,
          'code': code,
        }),
      ),
    );
    final access = token['access_token'] as String?;
    if (access == null || access.isEmpty) {
      throw AuthFailure('provider_failed', 502);
    }
    final profile = await _json(
      await net.get(
        Uri.https('graph.facebook.com', '/me', {
          'fields': 'id,name,email',
          'access_token': access,
        }),
      ),
    );
    final id = '${profile['id'] ?? ''}';
    if (id.isEmpty) throw AuthFailure('provider_failed', 502);
    final email = '${profile['email'] ?? id}';
    final name = '${profile['name'] ?? email}';
    return AuthUser(
      id: 'facebook:$id',
      method: 'facebook',
      displayName: name,
      handle: email,
    );
  }

  Future<AuthUser> _wechat(String code) async {
    final token = await _json(
      await net.get(
        Uri.https('api.weixin.qq.com', '/sns/oauth2/access_token', {
          'appid': config.wechatAppId,
          'secret': config.wechatAppSecret,
          'code': code,
          'grant_type': 'authorization_code',
        }),
      ),
    );
    if (token['errcode'] != null) throw AuthFailure('provider_failed', 502);
    final access = '${token['access_token'] ?? ''}';
    final openid = '${token['openid'] ?? ''}';
    if (access.isEmpty || openid.isEmpty) {
      throw AuthFailure('provider_failed', 502);
    }
    final profile = await _json(
      await net.get(
        Uri.https('api.weixin.qq.com', '/sns/userinfo', {
          'access_token': access,
          'openid': openid,
          'lang': 'en',
        }),
      ),
    );
    if (profile['errcode'] != null) throw AuthFailure('provider_failed', 502);
    final name = '${profile['nickname'] ?? openid}';
    return AuthUser(
      id: 'wechat:$openid',
      method: 'wechat',
      displayName: name,
      handle: openid,
    );
  }

  Future<void> _sendSms(String phone, String code) async {
    final sid = config.twilioAccountSid;
    final basic = base64Encode(utf8.encode('$sid:${config.twilioAuthToken}'));
    final response = await net.postForm(
      Uri.parse(
        'https://api.twilio.com/2010-04-01/Accounts/$sid/Messages.json',
      ),
      {
        'To': _e164(phone),
        'From': config.twilioFrom,
        'Body': 'Leca code: $code',
      },
      headers: {'authorization': 'Basic $basic'},
    );
    if (response.status < 200 || response.status >= 300) {
      throw AuthFailure('sms_failed', 502);
    }
  }

  Map<String, Object?> _issue(AuthUser user) {
    final token = _token();
    _sessions[token] = user;
    return {'token': token, 'user': user.toJson()};
  }

  String _authorizeUrl(String provider, String state) {
    final redirect = _callback(provider);
    switch (provider) {
      case 'google':
        return Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
          'client_id': config.googleClientId,
          'redirect_uri': redirect,
          'response_type': 'code',
          'scope': 'openid email profile',
          'state': state,
        }).toString();
      case 'facebook':
        return Uri.https('www.facebook.com', '/v21.0/dialog/oauth', {
          'client_id': config.facebookAppId,
          'redirect_uri': redirect,
          'state': state,
          'scope': 'email,public_profile',
        }).toString();
      case 'wechat':
        return '${Uri.https('open.weixin.qq.com', '/connect/qrconnect', {'appid': config.wechatAppId, 'redirect_uri': redirect, 'response_type': 'code', 'scope': 'snsapi_login', 'state': state})}#wechat_redirect';
      default:
        throw AuthFailure('provider_invalid');
    }
  }

  String _callback(String provider) =>
      '${config.publicUrl}/v1/auth/$provider/callback';

  bool _ready(String provider) {
    switch (provider) {
      case 'google':
        return config.googleReady;
      case 'facebook':
        return config.facebookReady;
      case 'wechat':
        return config.wechatReady;
      default:
        return false;
    }
  }

  bool _known(String provider) =>
      provider == 'google' || provider == 'facebook' || provider == 'wechat';

  Future<Map<String, Object?>> _json(NetResponse response) async {
    if (response.status < 200 || response.status >= 300) {
      throw AuthFailure('provider_failed', 502);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw AuthFailure('provider_failed', 502);
    return decoded.map((key, value) => MapEntry('$key', value));
  }

  String _token() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  String _digits(String value) => value.replaceAll(RegExp(r'\D'), '');

  String _e164(String digits) {
    if (digits.startsWith('855')) return '+$digits';
    if (digits.startsWith('0')) return '+855${digits.substring(1)}';
    return '+$digits';
  }

  /// Driving minutes that include the jam. Google Routes `TRAFFIC_AWARE`.
  Future<Map<String, Object?>> trafficRoute(Map<String, Object?> body) async {
    final key = config.googleMapsKey;
    if (key.isEmpty) throw AuthFailure('route_unconfigured', 503);
    final originLat = _coord(body['originLat']);
    final originLng = _coord(body['originLng']);
    final destLat = _coord(body['destLat']);
    final destLng = _coord(body['destLng']);
    if (originLat.abs() > 90 || destLat.abs() > 90) {
      throw AuthFailure('route_invalid');
    }
    if (originLng.abs() > 180 || destLng.abs() > 180) {
      throw AuthFailure('route_invalid');
    }
    final mode = body['mode'] == 'TWO_WHEELER' ? 'TWO_WHEELER' : 'DRIVE';
    final depart = now().toUtc().add(const Duration(seconds: 30));
    final response = await net.postJson(
      Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes'),
      {
        'origin': {
          'location': {
            'latLng': {'latitude': originLat, 'longitude': originLng},
          },
        },
        'destination': {
          'location': {
            'latLng': {'latitude': destLat, 'longitude': destLng},
          },
        },
        'travelMode': mode,
        'routingPreference': 'TRAFFIC_AWARE',
        'departureTime': depart.toIso8601String(),
      },
      headers: {
        'X-Goog-Api-Key': key,
        'X-Goog-FieldMask':
            'routes.duration,routes.distanceMeters,routes.staticDuration',
      },
    );
    if (response.status < 200 || response.status >= 300) {
      throw AuthFailure('route_failed', 502);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw AuthFailure('route_failed', 502);
    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty || routes.first is! Map) {
      throw AuthFailure('route_unavailable', 502);
    }
    final route = (routes.first as Map).map((k, v) => MapEntry('$k', v));
    final seconds = _googleSeconds(route['duration']);
    if (seconds == null) throw AuthFailure('route_failed', 502);
    final minutes = (seconds / 60).ceil().clamp(1, 24 * 60);
    return {
      'minutes': minutes,
      'seconds': seconds,
      'distanceMeters': route['distanceMeters'] ?? 0,
      'traffic': true,
    };
  }

  String homePage() {
    final mode = config.devOtp
        ? 'Test mode is on. A phone code appears on this page. Google, Facebook, and WeChat sign in as test users. A domain is not required.'
        : 'Email and password are live. Google, Facebook, WeChat, and phone use their own apps.';
    return '''
<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Leca sign-in</title>
<style>
body { font-family: sans-serif; margin: 0; background: #f6f0e6; color: #1a1410; }
main { max-width: 28rem; margin: 0 auto; padding: 1.5rem; }
h1 { color: #b42318; }
label { display: block; margin-top: 0.8rem; font-weight: 600; }
input, button { font: inherit; }
input { width: 100%; box-sizing: border-box; padding: 0.6rem; margin-top: 0.3rem; border: 1px solid #ccc; border-radius: 8px; }
button { margin-top: 0.8rem; margin-right: 0.4rem; padding: 0.6rem 0.8rem; border-radius: 8px; border: 0; background: #b42318; color: white; }
button.alt { background: white; color: #1a1410; border: 1px solid #1a1410; }
#out { margin-top: 1rem; white-space: pre-wrap; }
</style></head>
<body><main>
<h1>Leca sign-in</h1>
<p>$mode</p>
<label>Email <input id="email" type="email" autocomplete="username" placeholder="you@example.com"></label>
<label>Password <input id="password" type="password" autocomplete="current-password" placeholder="At least 8 characters"></label>
<label>Name <input id="name" autocomplete="name" placeholder="Only for a new account"></label>
<button id="create" type="button">Create account</button>
<button id="login" class="alt" type="button">Sign in</button>
<label>Phone <input id="phone" type="tel" placeholder="012 345 678"></label>
<button id="send" type="button">Send code</button>
<label>Code <input id="code" inputmode="numeric" placeholder="4-digit code"></label>
<button id="verify" class="alt" type="button">Verify phone</button>
<p>
<button id="google" class="alt" type="button">Google</button>
<button id="facebook" class="alt" type="button">Facebook</button>
<button id="wechat" class="alt" type="button">WeChat</button>
</p>
<p id="out"></p>
<script>
const messages = {
  email_invalid: "Enter a valid email address.",
  password_short: "Use a password of at least 8 characters.",
  email_taken: "That email already has an account. Sign in instead.",
  credentials_invalid: "That email or password is not right.",
  phone_invalid: "Enter a phone number with at least 8 digits.",
  code_invalid: "That code is not valid.",
  sms_unconfigured: "Phone sign-in is not configured.",
  provider_unconfigured: "That provider is not configured."
};
const out = document.getElementById("out");
function show(text) { out.textContent = text; }
async function post(path, body) {
  const res = await fetch(path, {
    method: "POST",
    headers: {"content-type": "application/json"},
    body: JSON.stringify(body)
  });
  const data = await res.json();
  if (!res.ok) throw new Error(messages[data.error] || data.error || "Could not sign in.");
  return data;
}
function signedIn(data) {
  const user = data.user || {};
  show("Signed in as " + (user.displayName || "") + " (" + (user.handle || "") + ").");
}
document.getElementById("create").onclick = function () {
  post("/v1/auth/email/register", {
    email: document.getElementById("email").value,
    password: document.getElementById("password").value,
    name: document.getElementById("name").value
  }).then(signedIn).catch(function (e) { show(e.message); });
};
document.getElementById("login").onclick = function () {
  post("/v1/auth/email/login", {
    email: document.getElementById("email").value,
    password: document.getElementById("password").value
  }).then(signedIn).catch(function (e) { show(e.message); });
};
document.getElementById("send").onclick = function () {
  post("/v1/auth/phone/start", {phone: document.getElementById("phone").value})
    .then(function (data) {
      show(data.devCode ? "Code: " + data.devCode : "Code sent.");
    }).catch(function (e) { show(e.message); });
};
document.getElementById("verify").onclick = function () {
  post("/v1/auth/phone/verify", {
    phone: document.getElementById("phone").value,
    code: document.getElementById("code").value
  }).then(signedIn).catch(function (e) { show(e.message); });
};
function provider(name) {
  post("/v1/auth/provider/start", {provider: name})
    .then(function (data) { location.href = data.url; })
    .catch(function (e) { show(e.message); });
}
document.getElementById("google").onclick = function () { provider("google"); };
document.getElementById("facebook").onclick = function () { provider("facebook"); };
document.getElementById("wechat").onclick = function () { provider("wechat"); };
</script>
</main></body></html>
''';
  }

  String _page(String title, String body) =>
      '''
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>$title</title></head>
<body style="font-family: sans-serif; padding: 2rem;">
<h1>$title</h1><p>$body</p></body></html>
''';
}

Future<void> handleAuth(
  AuthCore core,
  HttpRequest request, {
  TrustStore? trust,
}) async {
  final response = request.response;
  response.headers
    ..set('access-control-allow-origin', '*')
    ..set(
      'access-control-allow-headers',
      'content-type, authorization, x-admin-key',
    )
    ..set('access-control-allow-methods', 'GET, POST, OPTIONS');
  if (request.method == 'OPTIONS') {
    response.statusCode = 204;
    await response.close();
    return;
  }
  final path = request.uri.path;
  try {
    if (request.method == 'GET' && (path == '/' || path == '/index.html')) {
      response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write(core.homePage());
      await response.close();
      return;
    }
    if (request.method == 'GET' && path == '/tls-ask') {
      final domain = request.uri.queryParameters['domain'] ?? '';
      final ok = await domainPointsHere(domain);
      response.statusCode = ok ? 200 : 403;
      await response.close();
      return;
    }
    if (request.method == 'GET' && path == '/health') {
      await _json(response, 200, {'ok': true});
      return;
    }
    if (request.method == 'GET' &&
        (path == '/v1/card' || path == '/v1/quote')) {
      await _json(response, 200, RateCard.active.toJson());
      return;
    }
    if (request.method == 'POST' && path == '/v1/auth/phone/start') {
      final body = await _readJson(request);
      await _json(response, 200, await core.phoneStart('${body['phone']}'));
      return;
    }
    if (request.method == 'POST' && path == '/v1/auth/phone/verify') {
      final body = await _readJson(request);
      await _json(
        response,
        200,
        await core.phoneVerify('${body['phone']}', '${body['code']}'),
      );
      return;
    }
    if (request.method == 'POST' && path == '/v1/auth/email/register') {
      final body = await _readJson(request);
      await _json(
        response,
        200,
        await core.emailRegister(
          email: '${body['email']}',
          password: '${body['password']}',
          name: '${body['name'] ?? ''}',
        ),
      );
      return;
    }
    if (request.method == 'POST' && path == '/v1/auth/email/login') {
      final body = await _readJson(request);
      await _json(
        response,
        200,
        await core.emailLogin(
          email: '${body['email']}',
          password: '${body['password']}',
        ),
      );
      return;
    }
    if (request.method == 'POST' && path == '/v1/auth/provider/start') {
      final body = await _readJson(request);
      await _json(
        response,
        200,
        await core.providerStart('${body['provider']}'),
      );
      return;
    }
    if (request.method == 'GET' && path.startsWith('/v1/auth/dev/')) {
      final provider = path.substring('/v1/auth/dev/'.length);
      final html = core.devPage(provider, request.uri.queryParameters['state']);
      response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write(html);
      await response.close();
      return;
    }
    if (request.method == 'GET' && path.startsWith('/v1/auth/pending/')) {
      final id = path.substring('/v1/auth/pending/'.length);
      await _json(response, 200, core.pending(id));
      return;
    }
    if (request.method == 'GET' && path == '/v1/auth/me') {
      final header = request.headers.value('authorization') ?? '';
      final token = header.startsWith('Bearer ') ? header.substring(7) : '';
      final user = core.userForToken(token);
      if (user == null) throw AuthFailure('unauthorized', 401);
      await _json(response, 200, {'user': user.toJson()});
      return;
    }
    for (final provider in ['google', 'facebook', 'wechat']) {
      if (request.method == 'GET' && path == '/v1/auth/$provider/callback') {
        final html = await core.providerCallback(
          provider,
          request.uri.queryParameters['code'],
          request.uri.queryParameters['state'],
        );
        response
          ..statusCode = 200
          ..headers.contentType = ContentType.html
          ..write(html);
        await response.close();
        return;
      }
    }
    if (request.method == 'POST' && path == '/v1/quote') {
      final body = await _readJson(request);
      try {
        await _json(response, 200, quoteTrip(body));
      } on FormatException {
        throw AuthFailure('quote_invalid');
      }
      return;
    }
    if (request.method == 'POST' && path == '/v1/route') {
      final body = await _readJson(request);
      await _json(response, 200, await core.trafficRoute(body));
      return;
    }
    if (trust != null &&
        (path.startsWith('/v1/driver/') ||
            path.startsWith('/v1/report') ||
            path.startsWith('/v1/admin/') ||
            path == '/v1/suspended')) {
      await _handleTrust(core, trust, request, response, path);
      return;
    }
    throw AuthFailure('not_found', 404);
  } on AuthFailure catch (e) {
    await _json(response, e.status, {'error': e.code});
  } catch (_) {
    await _json(response, 500, {'error': 'failed'});
  }
}

AuthUser _bearer(AuthCore core, HttpRequest request) {
  final header = request.headers.value('authorization') ?? '';
  final token = header.startsWith('Bearer ') ? header.substring(7) : '';
  final user = core.userForToken(token);
  if (user == null) throw AuthFailure('unauthorized', 401);
  return user;
}

Future<void> _handleTrust(
  AuthCore core,
  TrustStore trust,
  HttpRequest request,
  HttpResponse response,
  String path,
) async {
  final method = request.method;
  if (method == 'GET' && path == '/v1/suspended') {
    await _json(response, 200, {'staffIds': trust.suspended()});
    return;
  }
  if (method == 'POST' && path == '/v1/driver/file') {
    final user = _bearer(core, request);
    final body = await _readJson(request, maxBytes: 40 * 1024 * 1024);
    await _json(response, 200, trust.submitDriver(user, body));
    return;
  }
  if (method == 'GET' && path == '/v1/driver/status') {
    final user = _bearer(core, request);
    await _json(response, 200, trust.status(user));
    return;
  }
  if (method == 'POST' && path == '/v1/report') {
    final user = _bearer(core, request);
    await _json(
      response,
      200,
      trust.fileReport(user, await _readJson(request)),
    );
    return;
  }
  if (method == 'POST' && path == '/v1/report/appeal') {
    final user = _bearer(core, request);
    await _json(response, 200, trust.appeal(user, await _readJson(request)));
    return;
  }
  if (path.startsWith('/v1/admin/')) {
    trust.requireAdmin(request.headers.value('x-admin-key'));
    if (method == 'GET' && path == '/v1/admin/driver/queue') {
      await _json(response, 200, {'queue': trust.queue()});
      return;
    }
    if (method == 'POST' && path == '/v1/admin/driver/review') {
      await _json(response, 200, trust.reviewDriver(await _readJson(request)));
      return;
    }
    if (method == 'GET' && path == '/v1/admin/report/open') {
      await _json(response, 200, {'reports': trust.openReports()});
      return;
    }
    if (method == 'POST' && path == '/v1/admin/report/resolve') {
      await _json(response, 200, trust.resolveReport(await _readJson(request)));
      return;
    }
  }
  throw AuthFailure('not_found', 404);
}

Future<bool> domainPointsHere(String domain) async {
  if (domain.isEmpty ||
      domain.length > 253 ||
      domain.contains(' ') ||
      InternetAddress.tryParse(domain) != null) {
    return false;
  }
  try {
    final answers = await InternetAddress.lookup(domain);
    return answers.any((address) => address.address == '65.21.232.29');
  } catch (_) {
    return false;
  }
}

double _coord(Object? value) {
  final number = value is num ? value.toDouble() : double.tryParse('$value');
  if (number == null || number.isNaN || number.isInfinite) {
    throw AuthFailure('route_invalid');
  }
  return number;
}

int? _googleSeconds(Object? value) {
  final match = RegExp(r'^(\d+)s$').firstMatch('$value');
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

Future<Map<String, Object?>> _readJson(
  HttpRequest request, {
  int maxBytes = 1024 * 1024,
}) async {
  final length = request.contentLength;
  if (length > maxBytes) throw AuthFailure('too_large', 413);
  final text = await utf8.decoder.bind(request).join();
  if (text.length > maxBytes) throw AuthFailure('too_large', 413);
  if (text.isEmpty) return {};
  final decoded = jsonDecode(text);
  if (decoded is! Map) throw AuthFailure('bad_request');
  return decoded.map((key, value) => MapEntry('$key', value));
}

Future<void> _json(
  HttpResponse response,
  int status,
  Map<String, Object?> body,
) async {
  response
    ..statusCode = status
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body));
  await response.close();
}
