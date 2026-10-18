import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

import 'password.dart';
import 'quote.dart';
import 'trust.dart';
import 'webauthn.dart';

String assetLinksJson(String fingerprint) {
  if (fingerprint.isEmpty) return '[]';
  return jsonEncode([
    {
      'relation': ['delegate_permission/common.get_login_creds'],
      'target': {
        'namespace': 'android_app',
        'package_name': 'app.leca.leca',
        'sha256_cert_fingerprints': [fingerprint],
      },
    },
  ]);
}

String appleAssociationJson(String teamId) {
  final apps = teamId.isEmpty ? const <String>[] : ['$teamId.app.leca.leca'];
  return jsonEncode({
    'webcredentials': {'apps': apps},
  });
}

class AuthFailure implements Exception {
  AuthFailure(this.code, [this.status = 400]);

  final String code;
  final int status;
}

/// Bytes the device signs. The app builds this same text in `keyProofMessage`.
String keyProofMessage({
  required String challenge,
  required String publicKey,
  required String name,
}) {
  return 'leca-key/1\n$challenge\n$publicKey\n$name\n';
}

/// A display name tied to a key. Newlines are spaces. Eighty characters is the cap.
String normalizeKeyName(String raw) {
  final name = raw.replaceAll(RegExp(r'[\r\n]'), ' ').trim();
  if (name.length <= 80) return name;
  return name.substring(0, 80);
}

String keyAccountId(List<int> publicKey) {
  final hex = publicKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return 'key:$hex';
}

String keyHandle(List<int> publicKey) =>
    keyAccountId(publicKey).substring(4, 12);

String _encodeKey(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

Uint8List _decodeKey(String raw) {
  final pad = '=' * ((4 - raw.length % 4) % 4);
  try {
    return Uint8List.fromList(base64Url.decode('$raw$pad'));
  } on FormatException {
    throw AuthFailure('key_invalid');
  }
}

String _canonicalPublicKey(String raw) {
  final bytes = _decodeKey(raw);
  if (bytes.length != 32) throw AuthFailure('key_invalid');
  return _encodeKey(bytes);
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
    this.telegramBotToken = '',
    this.xClientId = '',
    this.xClientSecret = '',
    this.whatsappToken = '',
    this.whatsappPhoneId = '',
    this.whatsappTemplate = 'leca_login',
    this.twilioAccountSid = '',
    this.twilioAuthToken = '',
    this.twilioWhatsappFrom = '',
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
  final String telegramBotToken;
  final String xClientId;
  final String xClientSecret;
  final String whatsappToken;
  final String whatsappPhoneId;
  final String whatsappTemplate;
  final String twilioAccountSid;
  final String twilioAuthToken;
  final String twilioWhatsappFrom;
  final bool devOtp;
  final String googleMapsKey;

  bool get googleReady =>
      googleClientId.isNotEmpty && googleClientSecret.isNotEmpty;

  bool get facebookReady =>
      facebookAppId.isNotEmpty && facebookAppSecret.isNotEmpty;

  bool get wechatReady => wechatAppId.isNotEmpty && wechatAppSecret.isNotEmpty;

  bool get telegramReady => telegramBotToken.contains(':');

  bool get xReady => xClientId.isNotEmpty && xClientSecret.isNotEmpty;

  /// Meta Cloud API, or Twilio's WhatsApp sender.
  bool get whatsappReady =>
      (whatsappToken.isNotEmpty && whatsappPhoneId.isNotEmpty) ||
      (twilioAccountSid.isNotEmpty &&
          twilioAuthToken.isNotEmpty &&
          twilioWhatsappFrom.isNotEmpty);

  String get telegramBotId => telegramBotToken.split(':').first;

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
      telegramBotToken: env['TELEGRAM_BOT_TOKEN'] ?? '',
      xClientId: env['X_CLIENT_ID'] ?? '',
      xClientSecret: env['X_CLIENT_SECRET'] ?? '',
      whatsappToken: env['WHATSAPP_TOKEN'] ?? '',
      whatsappPhoneId: env['WHATSAPP_PHONE_ID'] ?? '',
      whatsappTemplate: (env['WHATSAPP_TEMPLATE'] ?? '').isEmpty
          ? 'leca_login'
          : env['WHATSAPP_TEMPLATE']!,
      twilioAccountSid: env['TWILIO_ACCOUNT_SID'] ?? '',
      twilioAuthToken: env['TWILIO_AUTH_TOKEN'] ?? '',
      twilioWhatsappFrom: env['TWILIO_WHATSAPP_FROM'] ?? '',
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

class _PasskeyAccount {
  _PasskeyAccount({
    required this.userHandle,
    required this.displayName,
    required this.alg,
    required this.x,
    required this.y,
    required this.signCount,
  });

  final String userHandle;
  String displayName;
  final int alg;
  final String x;
  final String y;
  int signCount;
}

class _PasskeyChallenge {
  _PasskeyChallenge({
    required this.create,
    required this.expires,
    this.userHandle = '',
    this.name = '',
  });

  final bool create;
  final DateTime expires;
  final String userHandle;
  final String name;
}

class _KeyAccount {
  _KeyAccount({required this.displayName});

  String displayName;
}

class _KeyChallenge {
  _KeyChallenge(this.publicKey, this.expires);

  final String publicKey;
  final DateTime expires;
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

  /// PKCE verifier for X. Empty for the other providers.
  String verifier = '';
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
    _loadKeys();
    _loadPasskeys();
    _loadSessions();
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
  final Map<String, _KeyAccount> _keys = {};
  final Map<String, _KeyChallenge> _keyChallenges = {};
  final Map<String, _PasskeyAccount> _passkeys = {};
  final Map<String, _PasskeyChallenge> _passkeyChallenges = {};

  Future<Map<String, Object?>> whatsappStart(String rawPhone) async {
    final phone = _digits(rawPhone);
    if (phone.length < 8) throw AuthFailure('phone_invalid');
    if (!config.whatsappReady && !config.devOtp) {
      throw AuthFailure('whatsapp_unconfigured', 503);
    }
    final code = _random.nextInt(10000).toString().padLeft(4, '0');
    _otps[phone] = _Otp(code, now().add(const Duration(minutes: 5)));
    if (config.whatsappReady) await _sendWhatsApp(phone, code);
    return {'ok': true, if (config.devOtp) 'devCode': code};
  }

  Future<Map<String, Object?>> whatsappVerify(String rawPhone, String code) {
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
      id: 'whatsapp:$phone',
      method: 'whatsapp',
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

  /// A fresh challenge for [publicKey]. The signature has to cover this value.
  Future<Map<String, Object?>> keyChallenge(String publicKey) async {
    final encoded = _canonicalPublicKey(publicKey);
    final challenge = _encodeKey(_randomBytes(32));
    _keyChallenges[challenge] = _KeyChallenge(
      encoded,
      now().add(const Duration(minutes: 5)),
    );
    final account = _keys[encoded];
    return {
      'challenge': challenge,
      'known': account != null,
      if (account != null) 'displayName': account.displayName,
    };
  }

  /// Checks the device signature and ties [name] to the public key.
  Future<Map<String, Object?>> keyFinish({
    required String publicKey,
    required String challenge,
    required String signature,
    required String name,
  }) async {
    final encoded = _canonicalPublicKey(publicKey);
    final submitted = normalizeKeyName(name);
    final existing = _keys[encoded];
    final pending = _keyChallenges.remove(challenge);
    if (pending == null ||
        now().isAfter(pending.expires) ||
        pending.publicKey != encoded) {
      throw AuthFailure('challenge_invalid');
    }
    final ok = await _verifyKey(
      publicKey: encoded,
      challenge: challenge,
      name: submitted,
      signature: signature,
    );
    if (!ok) throw AuthFailure('signature_invalid');
    final stored = submitted.isEmpty
        ? (existing?.displayName ?? '')
        : submitted;
    _keys[encoded] = _KeyAccount(displayName: stored);
    _saveKeys();
    final bytes = _decodeKey(encoded);
    final shown = stored.isEmpty ? keyHandle(bytes) : stored;
    return _issue(
      AuthUser(
        id: keyAccountId(bytes),
        method: 'key',
        displayName: shown,
        handle: keyHandle(bytes),
      ),
    );
  }

  Future<bool> _verifyKey({
    required String publicKey,
    required String challenge,
    required String name,
    required String signature,
  }) async {
    final sig = _decodeKey(signature);
    if (sig.length != 64) return false;
    final raw = _decodeKey(publicKey);
    try {
      return Ed25519().verify(
        utf8.encode(
          keyProofMessage(
            challenge: challenge,
            publicKey: publicKey,
            name: name,
          ),
        ),
        signature: Signature(
          sig,
          publicKey: SimplePublicKey(raw, type: KeyPairType.ed25519),
        ),
      );
    } on Object {
      return false;
    }
  }

  String get rpId {
    final host = Uri.parse(config.publicUrl).host;
    return host.isEmpty ? 'leca.world' : host;
  }

  Map<String, Object?> passkeyRegisterStart({String name = ''}) {
    final challenge = _encodeKey(_randomBytes(32));
    final user = _randomBytes(16);
    final handle = _encodeKey(user);
    _passkeyChallenges[challenge] = _PasskeyChallenge(
      create: true,
      expires: now().add(const Duration(minutes: 5)),
      userHandle: handle,
      name: normalizeKeyName(name),
    );
    return {
      'challenge': challenge,
      'userId': base64Url.encode(user),
      'rpId': rpId,
      'name': normalizeKeyName(name),
    };
  }

  Future<Map<String, Object?>> passkeyRegisterFinish({
    required String challenge,
    required String clientDataJSON,
    required String attestationObject,
  }) async {
    final pending = _passkeyChallenges.remove(challenge);
    if (pending == null || !pending.create || now().isAfter(pending.expires)) {
      throw AuthFailure('challenge_invalid');
    }
    final PasskeyPublic credential;
    try {
      credential = WebAuthn.registration(
        rpId: rpId,
        challenge: challenge,
        clientDataJson: clientDataJSON,
        attestationObject: attestationObject,
      );
    } on WebAuthnFailure catch (e) {
      throw AuthFailure(e.code);
    }
    final id = _encodeKey(credential.credentialId);
    _passkeys[id] = _PasskeyAccount(
      userHandle: pending.userHandle,
      displayName: pending.name,
      alg: credential.alg,
      x: _encodeKey(credential.x),
      y: credential.y.isEmpty ? '' : _encodeKey(credential.y),
      signCount: credential.signCount,
    );
    _savePasskeys();
    return _issue(_passkeyUser(_passkeys[id]!, id));
  }

  Map<String, Object?> passkeyLoginStart() {
    final challenge = _encodeKey(_randomBytes(32));
    _passkeyChallenges[challenge] = _PasskeyChallenge(
      create: false,
      expires: now().add(const Duration(minutes: 5)),
    );
    return {'challenge': challenge, 'rpId': rpId};
  }

  Future<Map<String, Object?>> passkeyLoginFinish({
    required String id,
    required String challenge,
    required String clientDataJSON,
    required String authenticatorData,
    required String signature,
  }) async {
    final pending = _passkeyChallenges.remove(challenge);
    if (pending == null || pending.create || now().isAfter(pending.expires)) {
      throw AuthFailure('challenge_invalid');
    }
    final encoded = _canonicalBytes(id);
    final account = _passkeys[encoded];
    if (account == null) throw AuthFailure('passkey_invalid');
    final int count;
    try {
      count = await WebAuthn.assertion(
        rpId: rpId,
        challenge: challenge,
        clientDataJson: clientDataJSON,
        authenticatorData: authenticatorData,
        signature: signature,
        alg: account.alg,
        x: _decodeKey(account.x),
        y: account.y.isEmpty ? const <int>[] : _decodeKey(account.y),
        signCount: account.signCount,
      );
    } on WebAuthnFailure catch (e) {
      throw AuthFailure(e.code);
    }
    if (count > 0) account.signCount = count;
    _savePasskeys();
    return _issue(_passkeyUser(account, encoded));
  }

  AuthUser _passkeyUser(_PasskeyAccount account, String id) {
    final shown = account.displayName.isEmpty
        ? id.substring(0, id.length < 8 ? id.length : 8)
        : account.displayName;
    return AuthUser(
      id: 'passkey:${account.userHandle}',
      method: 'passkey',
      displayName: shown,
      handle: shown,
    );
  }

  String _canonicalBytes(String raw) => _encodeKey(_decodeKey(raw));

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

  String? get _sessionPath {
    final path = accountPath;
    if (path == null) return null;
    return '${File(path).parent.path}/sessions.json';
  }

  void _loadSessions() {
    final path = _sessionPath;
    if (path == null) return;
    final file = File(path);
    if (!file.existsSync()) return;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) return;
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        _sessions['${entry.key}'] = AuthUser(
          id: '${value['id']}',
          method: '${value['method']}',
          displayName: '${value['displayName']}',
          handle: '${value['handle']}',
        );
      }
    } catch (_) {}
  }

  void _saveSessions() {
    final path = _sessionPath;
    if (path == null) return;
    final file = File(path);
    file.parent.createSync(recursive: true);
    final tmp = File('$path.tmp');
    tmp.writeAsStringSync(
      jsonEncode({
        for (final entry in _sessions.entries) entry.key: entry.value.toJson(),
      }),
      flush: true,
    );
    tmp.renameSync(path);
  }

  void _remember(String token, AuthUser user) {
    _sessions[token] = user;
    _saveSessions();
  }

  String? get _keyPath {
    final path = accountPath;
    if (path == null) return null;
    return '${File(path).parent.path}/keys.json';
  }

  void _loadKeys() {
    final path = _keyPath;
    if (path == null) return;
    final file = File(path);
    if (!file.existsSync()) return;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) return;
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        _keys['${entry.key}'] = _KeyAccount(
          displayName: '${value['displayName'] ?? ''}',
        );
      }
    } catch (_) {}
  }

  void _saveKeys() {
    final path = _keyPath;
    if (path == null) return;
    final file = File(path);
    file.parent.createSync(recursive: true);
    final tmp = File('$path.tmp');
    tmp.writeAsStringSync(
      jsonEncode({
        for (final entry in _keys.entries)
          entry.key: {'displayName': entry.value.displayName},
      }),
      flush: true,
    );
    tmp.renameSync(path);
  }

  String? get _passkeyPath {
    final path = accountPath;
    if (path == null) return null;
    return '${File(path).parent.path}/passkeys.json';
  }

  void _loadPasskeys() {
    final path = _passkeyPath;
    if (path == null) return;
    final file = File(path);
    if (!file.existsSync()) return;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) return;
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        _passkeys['${entry.key}'] = _PasskeyAccount(
          userHandle: '${value['userHandle'] ?? ''}',
          displayName: '${value['displayName'] ?? ''}',
          alg: value['alg'] is int ? value['alg'] as int : -7,
          x: '${value['x'] ?? ''}',
          y: '${value['y'] ?? ''}',
          signCount: value['signCount'] is int ? value['signCount'] as int : 0,
        );
      }
    } catch (_) {}
  }

  void _savePasskeys() {
    final path = _passkeyPath;
    if (path == null) return;
    final file = File(path);
    file.parent.createSync(recursive: true);
    final tmp = File('$path.tmp');
    tmp.writeAsStringSync(
      jsonEncode({
        for (final entry in _passkeys.entries)
          entry.key: {
            'userHandle': entry.value.userHandle,
            'displayName': entry.value.displayName,
            'alg': entry.value.alg,
            'x': entry.value.x,
            'y': entry.value.y,
            'signCount': entry.value.signCount,
          },
      }),
      flush: true,
    );
    tmp.renameSync(path);
  }

  Uint8List _randomBytes(int length) => Uint8List.fromList(
    List<int>.generate(length, (_) => _random.nextInt(256)),
  );

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
    final pending = _Pending(provider, now().add(const Duration(minutes: 10)));
    if (provider == 'x') pending.verifier = _verifier();
    _pending[id] = pending;
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
      final user = await _profile(provider, code, item.verifier);
      final token = _token();
      _remember(token, user);
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
      case 'telegram':
        return const AuthUser(
          id: 'telegram:dev',
          method: 'telegram',
          displayName: 'Tara Test',
          handle: 'tara',
        );
      case 'x':
        return const AuthUser(
          id: 'x:dev',
          method: 'x',
          displayName: 'Xan Test',
          handle: 'xan',
        );
      default:
        throw AuthFailure('provider_invalid');
    }
  }

  Future<AuthUser> _profile(
    String provider,
    String code,
    String verifier,
  ) async {
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
      case 'telegram':
        return _telegram(code);
      case 'x':
        return _x(code, verifier);
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

  Future<AuthUser> _telegram(String code) async {
    final token = await _json(
      await net.postForm(Uri.parse('https://oauth.telegram.org/token'), {
        'grant_type': 'authorization_code',
        'code': code,
        'client_id': config.telegramBotId,
        'client_secret': config.telegramBotToken,
        'redirect_uri': _callback('telegram'),
      }),
    );
    final access = '${token['access_token'] ?? ''}';
    if (access.isEmpty) throw AuthFailure('provider_failed', 502);
    final profile = await _json(
      await net.get(
        Uri.parse('https://oauth.telegram.org/userinfo'),
        headers: {'authorization': 'Bearer $access'},
      ),
    );
    final id = '${profile['id'] ?? ''}';
    if (id.isEmpty) throw AuthFailure('provider_failed', 502);
    final username =
        '${profile['preferred_username'] ?? profile['username'] ?? id}';
    final name = '${profile['name'] ?? username}';
    return AuthUser(
      id: 'telegram:$id',
      method: 'telegram',
      displayName: name,
      handle: username,
    );
  }

  Future<AuthUser> _x(String code, String verifier) async {
    final basic = base64Encode(
      utf8.encode('${config.xClientId}:${config.xClientSecret}'),
    );
    final token = await _json(
      await net.postForm(
        Uri.parse('https://api.x.com/2/oauth2/token'),
        {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': _callback('x'),
          'code_verifier': verifier,
        },
        headers: {'authorization': 'Basic $basic'},
      ),
    );
    final access = '${token['access_token'] ?? ''}';
    if (access.isEmpty) throw AuthFailure('provider_failed', 502);
    final profile = await _json(
      await net.get(
        Uri.parse('https://api.x.com/2/users/me?user.fields=name,username'),
        headers: {'authorization': 'Bearer $access'},
      ),
    );
    final data = profile['data'];
    if (data is! Map) throw AuthFailure('provider_failed', 502);
    final id = '${data['id'] ?? ''}';
    if (id.isEmpty) throw AuthFailure('provider_failed', 502);
    final username = '${data['username'] ?? id}';
    final name = '${data['name'] ?? username}';
    return AuthUser(
      id: 'x:$id',
      method: 'x',
      displayName: name,
      handle: username,
    );
  }

  Future<void> _sendWhatsApp(String phone, String code) async {
    final to = _e164(phone).replaceAll('+', '');
    if (config.whatsappToken.isNotEmpty && config.whatsappPhoneId.isNotEmpty) {
      final response = await net.postJson(
        Uri.parse(
          'https://graph.facebook.com/v21.0/${config.whatsappPhoneId}/messages',
        ),
        {
          'messaging_product': 'whatsapp',
          'to': to,
          'type': 'template',
          'template': {
            'name': config.whatsappTemplate,
            'language': {'code': 'en'},
            'components': [
              {
                'type': 'body',
                'parameters': [
                  {'type': 'text', 'text': code},
                ],
              },
              {
                'type': 'button',
                'sub_type': 'url',
                'index': '0',
                'parameters': [
                  {'type': 'text', 'text': code},
                ],
              },
            ],
          },
        },
        headers: {'authorization': 'Bearer ${config.whatsappToken}'},
      );
      if (response.status < 200 || response.status >= 300) {
        throw AuthFailure('whatsapp_failed', 502);
      }
      return;
    }
    final sid = config.twilioAccountSid;
    final basic = base64Encode(utf8.encode('$sid:${config.twilioAuthToken}'));
    final response = await net.postForm(
      Uri.parse(
        'https://api.twilio.com/2010-04-01/Accounts/$sid/Messages.json',
      ),
      {
        'To': 'whatsapp:+$to',
        'From': config.twilioWhatsappFrom,
        'Body': 'Leca code: $code',
      },
      headers: {'authorization': 'Basic $basic'},
    );
    if (response.status < 200 || response.status >= 300) {
      throw AuthFailure('whatsapp_failed', 502);
    }
  }

  Map<String, Object?> _issue(AuthUser user) {
    final token = _token();
    _remember(token, user);
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
      case 'telegram':
        return Uri.https('oauth.telegram.org', '/auth', {
          'client_id': config.telegramBotId,
          'redirect_uri': redirect,
          'response_type': 'code',
          'scope': 'openid',
          'state': state,
        }).toString();
      case 'x':
        final verifier = _pending[state]?.verifier ?? '';
        return Uri.https('twitter.com', '/i/oauth2/authorize', {
          'response_type': 'code',
          'client_id': config.xClientId,
          'redirect_uri': redirect,
          'scope': 'users.read',
          'state': state,
          'code_challenge': _challenge(verifier),
          'code_challenge_method': 'S256',
        }).toString();
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
      case 'telegram':
        return config.telegramReady;
      case 'x':
        return config.xReady;
      default:
        return false;
    }
  }

  bool _known(String provider) =>
      provider == 'google' ||
      provider == 'facebook' ||
      provider == 'wechat' ||
      provider == 'telegram' ||
      provider == 'x';

  String _verifier() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _challenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier)).bytes;
    return base64Url.encode(digest).replaceAll('=', '');
  }

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
#facebook { display: inline-flex; align-items: center; gap: 8px; }
#facebook svg { display: block; width: 16px; height: 16px; }
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
<button id="facebook" class="alt" type="button"><svg viewBox="0 0 24 24" aria-hidden="true"><path fill="#0866FF" d="M9.101 23.691v-7.98H6.627v-3.667h2.474v-1.58c0-4.085 1.848-5.978 5.858-5.978.401 0 .955.042 1.468.103a8.68 8.68 0 0 1 1.141.195v3.325a8.623 8.623 0 0 0-.653-.036 26.805 26.805 0 0 0-.733-.009c-.707 0-1.259.096-1.675.309a1.686 1.686 0 0 0-.679.622c-.258.42-.374.995-.374 1.752v1.297h3.919l-.386 2.103-.287 1.564h-3.246v8.245C19.396 23.238 24 18.179 24 12.044c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.628 3.874 10.35 9.101 11.647Z"/></svg>Continue with Facebook</button>
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
    if (request.method == 'POST' &&
        (path == '/v1/auth/whatsapp/start' || path == '/v1/auth/phone/start')) {
      final body = await _readJson(request);
      await _json(response, 200, await core.whatsappStart('${body['phone']}'));
      return;
    }
    if (request.method == 'POST' &&
        (path == '/v1/auth/whatsapp/verify' ||
            path == '/v1/auth/phone/verify')) {
      final body = await _readJson(request);
      await _json(
        response,
        200,
        await core.whatsappVerify('${body['phone']}', '${body['code']}'),
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
    if (request.method == 'POST' && path == '/v1/auth/key/challenge') {
      final body = await _readJson(request);
      await _json(
        response,
        200,
        await core.keyChallenge('${body['publicKey']}'),
      );
      return;
    }
    if (request.method == 'POST' && path == '/v1/auth/key/finish') {
      final body = await _readJson(request);
      await _json(
        response,
        200,
        await core.keyFinish(
          publicKey: '${body['publicKey']}',
          challenge: '${body['challenge']}',
          signature: '${body['signature']}',
          name: '${body['name'] ?? ''}',
        ),
      );
      return;
    }
    if (request.method == 'GET' && path == '/.well-known/assetlinks.json') {
      response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(
          assetLinksJson(Platform.environment['ANDROID_CERT_SHA256'] ?? ''),
        );
      await response.close();
      return;
    }
    if (request.method == 'GET' &&
        path == '/.well-known/apple-app-site-association') {
      response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(
          appleAssociationJson(Platform.environment['APPLE_TEAM_ID'] ?? ''),
        );
      await response.close();
      return;
    }
    if (request.method == 'POST' && path == '/v1/auth/passkey/register/start') {
      final body = await _readJson(request);
      await _json(
        response,
        200,
        core.passkeyRegisterStart(name: '${body['name'] ?? ''}'),
      );
      return;
    }
    if (request.method == 'POST' &&
        path == '/v1/auth/passkey/register/finish') {
      final body = await _readJson(request);
      await _json(
        response,
        200,
        await core.passkeyRegisterFinish(
          challenge: '${body['challenge']}',
          clientDataJSON: '${body['clientDataJSON']}',
          attestationObject: '${body['attestationObject']}',
        ),
      );
      return;
    }
    if (request.method == 'POST' && path == '/v1/auth/passkey/login/start') {
      await _json(response, 200, core.passkeyLoginStart());
      return;
    }
    if (request.method == 'POST' && path == '/v1/auth/passkey/login/finish') {
      final body = await _readJson(request);
      await _json(
        response,
        200,
        await core.passkeyLoginFinish(
          id: '${body['id']}',
          challenge: '${body['challenge']}',
          clientDataJSON: '${body['clientDataJSON']}',
          authenticatorData: '${body['authenticatorData']}',
          signature: '${body['signature']}',
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
    for (final provider in ['google', 'facebook', 'wechat', 'telegram', 'x']) {
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
      _bearer(core, request);
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

const lecaHosts = {
  'leca.world',
  'leca.my',
  'leca.homes',
  'leca.quest',
  'leca.autos',
  'leca.boats',
  'leca.beer',
  'leca.beauty',
  'leca.baby',
  // The published Mac app calls this host. Its A record is this machine.
  'gno.money',
};

Future<bool> domainPointsHere(String domain) async {
  final name = domain.toLowerCase();
  if (!lecaHosts.contains(name) || InternetAddress.tryParse(name) != null) {
    return false;
  }
  try {
    final answers = await InternetAddress.lookup(name);
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
