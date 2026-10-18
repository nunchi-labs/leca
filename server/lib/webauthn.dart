import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:pointycastle/export.dart' hide Signature;

import 'cbor.dart';

class WebAuthnFailure implements Exception {
  WebAuthnFailure(this.code);

  final String code;
}

class PasskeyPublic {
  const PasskeyPublic({
    required this.alg,
    required this.x,
    required this.y,
    required this.credentialId,
    required this.signCount,
  });

  /// COSE alg: -7 is ES256, -8 is Ed25519.
  final int alg;
  final Uint8List x;
  final Uint8List y;
  final Uint8List credentialId;
  final int signCount;
}

/// Checks a WebAuthn ceremony. The face or fingerprint stays on the device.
class WebAuthn {
  static PasskeyPublic registration({
    required String rpId,
    required String challenge,
    required String clientDataJson,
    required String attestationObject,
  }) {
    _clientData(
      clientDataJson,
      type: 'webauthn.create',
      challenge: challenge,
      rpId: rpId,
    );
    final attestation = Cbor.decode(_b64(attestationObject));
    if (attestation is! Map) throw WebAuthnFailure('passkey_invalid');
    final authData = attestation['authData'];
    if (authData is! List<int>) throw WebAuthnFailure('passkey_invalid');
    return _credential(authData, rpId, attested: true);
  }

  static Future<int> assertion({
    required String rpId,
    required String challenge,
    required String clientDataJson,
    required String authenticatorData,
    required String signature,
    required int alg,
    required List<int> x,
    required List<int> y,
    required int signCount,
  }) async {
    _clientData(
      clientDataJson,
      type: 'webauthn.get',
      challenge: challenge,
      rpId: rpId,
    );
    final auth = _b64(authenticatorData);
    final count = _counter(auth, rpId, attested: false);
    if (signCount > 0 && count > 0 && count <= signCount) {
      throw WebAuthnFailure('passkey_invalid');
    }
    final hash = sha256.convert(_b64(clientDataJson)).bytes;
    final message = Uint8List.fromList([...auth, ...hash]);
    final sig = _b64(signature);
    final ok = alg == -8
        ? await _ed25519(message, sig, x)
        : _es256(message, sig, x, y);
    if (!ok) throw WebAuthnFailure('signature_invalid');
    return count;
  }

  static Map<String, Object?> _clientData(
    String encoded, {
    required String type,
    required String challenge,
    required String rpId,
  }) {
    final decoded = jsonDecode(utf8.decode(_b64(encoded)));
    if (decoded is! Map) throw WebAuthnFailure('passkey_invalid');
    final map = decoded.map((key, value) => MapEntry('$key', value));
    if (map['type'] != type) throw WebAuthnFailure('passkey_invalid');
    if (_unpad('${map['challenge'] ?? ''}') != _unpad(challenge)) {
      throw WebAuthnFailure('challenge_invalid');
    }
    if (!_originOk('${map['origin'] ?? ''}', rpId)) {
      throw WebAuthnFailure('passkey_invalid');
    }
    return map;
  }

  static bool _originOk(String origin, String rpId) {
    if (origin.startsWith('android:apk-key-hash:')) return true;
    final uri = Uri.tryParse(origin);
    if (uri == null || uri.host != rpId) return false;
    if (uri.scheme == 'https') return true;
    return rpId == 'localhost' || rpId == '127.0.0.1';
  }

  static PasskeyPublic _credential(
    List<int> auth,
    String rpId, {
    required bool attested,
  }) {
    if (auth.length < 37) throw WebAuthnFailure('passkey_invalid');
    final hash = sha256.convert(utf8.encode(rpId)).bytes;
    for (var i = 0; i < 32; i++) {
      if (auth[i] != hash[i]) throw WebAuthnFailure('passkey_invalid');
    }
    final flags = auth[32];
    if (flags & 0x01 == 0 || flags & 0x04 == 0) {
      throw WebAuthnFailure('passkey_invalid');
    }
    if (attested && flags & 0x40 == 0) throw WebAuthnFailure('passkey_invalid');
    final count = _u32(auth.sublist(33, 37));
    if (!attested) {
      return PasskeyPublic(
        alg: 0,
        x: Uint8List(0),
        y: Uint8List(0),
        credentialId: Uint8List(0),
        signCount: count,
      );
    }
    if (auth.length < 55) throw WebAuthnFailure('passkey_invalid');
    final credLen = (auth[53] << 8) | auth[54];
    final credStart = 55;
    final credEnd = credStart + credLen;
    if (credEnd > auth.length) throw WebAuthnFailure('passkey_invalid');
    final cose = Cbor.decode(auth.sublist(credEnd));
    if (cose is! Map) throw WebAuthnFailure('passkey_invalid');
    final x = cose[-2];
    if (x is! List<int> || x.length != 32) {
      throw WebAuthnFailure('passkey_invalid');
    }
    final alg = cose[3];
    final y = cose[-3];
    final parsedAlg = alg is int ? alg : -7;
    if (parsedAlg == -8) {
      return PasskeyPublic(
        alg: -8,
        x: Uint8List.fromList(x),
        y: Uint8List(0),
        credentialId: Uint8List.fromList(auth.sublist(credStart, credEnd)),
        signCount: count,
      );
    }
    if (y is! List<int> || y.length != 32) {
      throw WebAuthnFailure('passkey_invalid');
    }
    return PasskeyPublic(
      alg: -7,
      x: Uint8List.fromList(x),
      y: Uint8List.fromList(y),
      credentialId: Uint8List.fromList(auth.sublist(credStart, credEnd)),
      signCount: count,
    );
  }

  static int _counter(List<int> auth, String rpId, {required bool attested}) {
    return _credential(auth, rpId, attested: attested).signCount;
  }

  static int _u32(List<int> bytes) =>
      (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];

  static Future<bool> _ed25519(List<int> message, List<int> sig, List<int> x) {
    if (sig.length != 64) return Future.value(false);
    try {
      return Ed25519().verify(
        message,
        signature: Signature(
          sig,
          publicKey: SimplePublicKey(x, type: KeyPairType.ed25519),
        ),
      );
    } on Object {
      return Future.value(false);
    }
  }

  static bool _es256(
    List<int> message,
    List<int> sig,
    List<int> x,
    List<int> y,
  ) {
    final parts = sig.length == 64
        ? (sig.sublist(0, 32), sig.sublist(32))
        : _der(sig);
    if (parts == null) return false;
    try {
      final curve = ECCurve_secp256r1();
      final point = curve.curve.createPoint(_big(x), _big(y));
      final key = ECPublicKey(point, curve);
      final verifier = ECDSASigner(SHA256Digest())
        ..init(false, PublicKeyParameter<ECPublicKey>(key));
      return verifier.verifySignature(
        Uint8List.fromList(message),
        ECSignature(_big(parts.$1), _big(parts.$2)),
      );
    } on Object {
      return false;
    }
  }

  static (List<int>, List<int>)? _der(List<int> sig) {
    if (sig.length < 8 || sig[0] != 0x30 || sig[1] != sig.length - 2) {
      return null;
    }
    var i = 2;
    if (sig[i] != 0x02) return null;
    final rLen = sig[i + 1];
    i += 2;
    if (i + rLen >= sig.length) return null;
    final r = _pad32(sig.sublist(i, i + rLen));
    i += rLen;
    if (i >= sig.length || sig[i] != 0x02) return null;
    final sLen = sig[i + 1];
    i += 2;
    if (i + sLen != sig.length) return null;
    return (r, _pad32(sig.sublist(i, i + sLen)));
  }

  static List<int> _pad32(List<int> raw) {
    var body = raw;
    if (body.isNotEmpty && body[0] == 0) body = body.sublist(1);
    if (body.length > 32) return body.sublist(body.length - 32);
    return [...List<int>.filled(32 - body.length, 0), ...body];
  }

  static BigInt _big(List<int> bytes) {
    var n = BigInt.zero;
    for (final byte in bytes) {
      n = (n << 8) | BigInt.from(byte);
    }
    return n;
  }

  static Uint8List _b64(String raw) {
    final pad = '=' * ((4 - raw.length % 4) % 4);
    try {
      return base64Url.decode('$raw$pad');
    } on FormatException {
      throw WebAuthnFailure('passkey_invalid');
    }
  }

  static String _unpad(String raw) => raw.replaceAll('=', '');
}
