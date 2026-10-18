import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:leca_auth/cbor.dart';
import 'package:leca_auth/leca_auth.dart';
import 'package:leca_auth/password.dart';
import 'package:leca_auth/webauthn.dart';
import 'package:pointycastle/export.dart' hide Mac, Signature;
import 'package:test/test.dart';

void main() {
  group('password', () {
    test('pbkdf2 matches an independent vector, and the compare is exact', () {
      final salt = List<int>.generate(16, (i) => i);
      expect(
        hashPassword('correct-horse', salt),
        'VWRVAxeBtV29a3SPo2HnJtkj/ovvhThmUidQQXqjsqs=',
      );
      expect(
        hashPassword('correct-horse', salt),
        hashPassword('correct-horse', salt),
      );
      expect(
        hashPassword('other-horse', salt),
        isNot(hashPassword('correct-horse', salt)),
      );
      expect(passwordIterations, 120000);
      expect(sameHash('abc', 'abc'), isTrue);
      expect(sameHash('', ''), isTrue);
      expect(sameHash('abc', 'abd'), isFalse);
      expect(sameHash('abc', 'abcd'), isFalse);
      expect(newSalt(Random(1)), newSalt(Random(1)));
      expect(newSalt(Random(1)), isNot(newSalt(Random(2))));
      expect(newSalt(Random(4)), hasLength(16));
    });
  });

  group('cbor', () {
    test('the webauthn slice round-trips, and rejects what it cannot read', () {
      expect(Cbor.encode(Uint8List.fromList([1, 2, 3])).first, 0x43);
      expect(Cbor.encode(<Object>[1, 2, 3]).first, 0x83);
      expect(Cbor.encode(Uint8List(0)).first, 0x40);
      expect(Cbor.encode(<Object>[]).first, 0x80);
      expect(Cbor.encode(0), [0x00]);
      expect(Cbor.encode(23), [0x17]);
      expect(Cbor.encode(24), [0x18, 24]);
      expect(Cbor.encode(255), [0x18, 0xff]);
      expect(Cbor.encode(256), [0x19, 0x01, 0x00]);
      expect(Cbor.encode(-1), [0x20]);
      expect(Cbor.encode(-25), [0x38, 24]);

      final value = {
        'city': 'ភ្នំពេញ',
        'n': -25,
        'big': 100000,
        'raw': Uint8List.fromList([9, 8]),
        'list': <Object>[1, 'a' * 24, <Object>[]],
      };
      expect(Cbor.decode(Cbor.encode(value)), value);
      expect(Cbor.decode([0xf4]), isFalse);
      expect(Cbor.decode([0xf5]), isTrue);
      expect(Cbor.decode([0xf6]), isNull);

      expect(() => Cbor.decode([0x00, 0x00]), throwsFormatException);
      expect(() => Cbor.decode([0x18]), throwsFormatException);
      expect(() => Cbor.decode([0xf7]), throwsFormatException);
      expect(() => Cbor.decode([0xc0]), throwsFormatException);
      expect(() => Cbor.encode(true), throwsArgumentError);
      expect(() => Cbor.encode(null), throwsArgumentError);
    });
  });

  group('keys', () {
    test('the proof text and the account id match the app', () {
      expect(assetLinksJson(''), '[]');
      final links = jsonDecode(assetLinksJson('AA:BB')) as List;
      final target = (links.single as Map)['target'] as Map;
      expect(target['package_name'], 'app.leca.leca');
      expect(target['sha256_cert_fingerprints'], ['AA:BB']);
      expect((jsonDecode(appleAssociationJson('')) as Map)['webcredentials'], {
        'apps': <String>[],
      });
      expect(jsonDecode(appleAssociationJson('TEAM')), {
        'webcredentials': {
          'apps': ['TEAM.app.leca.leca'],
        },
      });
      expect(
        keyProofMessage(challenge: 'c', publicKey: 'p', name: 'Ada'),
        'leca-key/1\nc\np\nAda\n',
      );
      expect(normalizeKeyName('  Ada\r\nBo  '), 'Ada  Bo');
      expect(normalizeKeyName('A' * 90), hasLength(80));
      expect(
        keyHandle([0x0a, 0x0b, 0x0c, 0x0d, ...List<int>.filled(28, 0)]),
        '0a0b0c0d',
      );
      expect(keyAccountId([0x0a, 0x0b]), 'key:0a0b');
    });
  });

  group('webauthn', () {
    const rpId = 'leca.world';

    test('a passkey registers and a signature has to be new', () async {
      final p256 = _P256();
      const credentialId = [9, 8, 7, 6];
      final cose = Cbor.encode({1: 2, 3: -7, -1: 1, -2: p256.x, -3: p256.y});
      final auth = _authData(
        rpId: rpId,
        flags: 0x45,
        count: 7,
        credentialId: credentialId,
        cose: cose,
      );
      final created = WebAuthn.registration(
        rpId: rpId,
        challenge: 'abc=',
        clientDataJson: _b64(
          _client(
            type: 'webauthn.create',
            challenge: 'abc',
            origin: 'https://leca.world',
          ),
        ),
        attestationObject: _b64(
          Cbor.encode({
            'fmt': 'none',
            'attStmt': <String, Object>{},
            'authData': auth,
          }),
        ),
      );
      expect(created.alg, -7);
      expect(created.signCount, 7);
      expect(created.x, p256.x);
      expect(created.y, p256.y);
      expect(created.credentialId, credentialId);

      final edCose = Cbor.encode({1: 1, 3: -8, -2: List<int>.filled(32, 4)});
      final ed = WebAuthn.registration(
        rpId: rpId,
        challenge: 'abc',
        clientDataJson: _b64(
          _client(
            type: 'webauthn.create',
            challenge: 'abc',
            origin: 'android:apk-key-hash:abc',
          ),
        ),
        attestationObject: _b64(
          Cbor.encode({
            'fmt': 'none',
            'attStmt': <String, Object>{},
            'authData': _authData(
              rpId: rpId,
              flags: 0x45,
              count: 1,
              credentialId: [1],
              cose: edCose,
            ),
          }),
        ),
      );
      expect(ed.alg, -8);
      expect(ed.y, isEmpty);

      final get = _client(
        type: 'webauthn.get',
        challenge: 'abc',
        origin: 'https://leca.world',
      );
      final asserted = _authData(rpId: rpId, flags: 0x05, count: 8);
      final message = [...asserted, ...sha256.convert(get).bytes];
      final count = await WebAuthn.assertion(
        rpId: rpId,
        challenge: 'abc',
        clientDataJson: _b64(get),
        authenticatorData: _b64(asserted),
        signature: _b64(p256.sign(message)),
        alg: -7,
        x: p256.x,
        y: p256.y,
        signCount: 0,
      );
      expect(count, 8);

      final der = await WebAuthn.assertion(
        rpId: rpId,
        challenge: 'abc',
        clientDataJson: _b64(get),
        authenticatorData: _b64(asserted),
        signature: _b64(p256.signDer(message)),
        alg: -7,
        x: p256.x,
        y: p256.y,
        signCount: 0,
      );
      expect(der, 8);

      await expectLater(
        WebAuthn.assertion(
          rpId: rpId,
          challenge: 'abc',
          clientDataJson: _b64(get),
          authenticatorData: _b64(asserted),
          signature: _b64(p256.sign(message)),
          alg: -7,
          x: p256.x,
          y: p256.y,
          signCount: 8,
        ),
        throwsA(predicate<WebAuthnFailure>((e) => e.code == 'passkey_invalid')),
      );

      final flipped = p256.sign(message);
      flipped[0] ^= 0xff;
      await expectLater(
        WebAuthn.assertion(
          rpId: rpId,
          challenge: 'abc',
          clientDataJson: _b64(get),
          authenticatorData: _b64(asserted),
          signature: _b64(flipped),
          alg: -7,
          x: p256.x,
          y: p256.y,
          signCount: 0,
        ),
        throwsA(
          predicate<WebAuthnFailure>((e) => e.code == 'signature_invalid'),
        ),
      );

      final quiet = _authData(rpId: rpId, flags: 0x05, count: 0);
      final quietMessage = [...quiet, ...sha256.convert(get).bytes];
      expect(
        await WebAuthn.assertion(
          rpId: rpId,
          challenge: 'abc',
          clientDataJson: _b64(get),
          authenticatorData: _b64(quiet),
          signature: _b64(p256.sign(quietMessage)),
          alg: -7,
          x: p256.x,
          y: p256.y,
          signCount: 8,
        ),
        0,
      );
    });

    test('ed25519 signs in, and a bad ceremony is refused', () async {
      final algorithm = Ed25519();
      final pair = await algorithm.newKeyPair();
      final public = await pair.extractPublicKey();
      final get = _client(
        type: 'webauthn.get',
        challenge: 'abc',
        origin: 'http://localhost',
      );
      final auth = _authData(rpId: 'localhost', flags: 0x05, count: 3);
      final message = [...auth, ...sha256.convert(get).bytes];
      final signature = await algorithm.sign(message, keyPair: pair);
      expect(
        await WebAuthn.assertion(
          rpId: 'localhost',
          challenge: 'abc',
          clientDataJson: _b64(get),
          authenticatorData: _b64(auth),
          signature: _b64(signature.bytes),
          alg: -8,
          x: public.bytes,
          y: const [],
          signCount: 1,
        ),
        3,
      );

      Future<int> attempt({
        String rpId = 'leca.world',
        String type = 'webauthn.get',
        String challenge = 'abc',
        String origin = 'https://leca.world',
        String? presented,
        List<int>? authData,
        String signature = 'AA',
        int alg = -7,
      }) {
        return WebAuthn.assertion(
          rpId: rpId,
          challenge: presented ?? challenge,
          clientDataJson: _b64(
            _client(type: type, challenge: challenge, origin: origin),
          ),
          authenticatorData: _b64(
            authData ?? _authData(rpId: rpId, flags: 0x05, count: 1),
          ),
          signature: signature,
          alg: alg,
          x: List<int>.filled(32, 1),
          y: List<int>.filled(32, 2),
          signCount: 0,
        );
      }

      await expectLater(
        attempt(origin: 'http://leca.world'),
        throwsA(predicate<WebAuthnFailure>((e) => e.code == 'passkey_invalid')),
      );
      await expectLater(
        attempt(origin: 'https://evil.example'),
        throwsA(predicate<WebAuthnFailure>((e) => e.code == 'passkey_invalid')),
      );
      await expectLater(
        attempt(presented: 'nope'),
        throwsA(
          predicate<WebAuthnFailure>((e) => e.code == 'challenge_invalid'),
        ),
      );
      await expectLater(
        attempt(type: 'webauthn.create'),
        throwsA(predicate<WebAuthnFailure>((e) => e.code == 'passkey_invalid')),
      );
      await expectLater(
        attempt(authData: [1, 2, 3]),
        throwsA(predicate<WebAuthnFailure>((e) => e.code == 'passkey_invalid')),
      );
      await expectLater(
        attempt(authData: _authData(rpId: 'other', flags: 0x05, count: 1)),
        throwsA(predicate<WebAuthnFailure>((e) => e.code == 'passkey_invalid')),
      );
      await expectLater(
        attempt(authData: _authData(rpId: rpId, flags: 0x01, count: 1)),
        throwsA(predicate<WebAuthnFailure>((e) => e.code == 'passkey_invalid')),
      );
      await expectLater(
        attempt(signature: 'AA', alg: -8),
        throwsA(
          predicate<WebAuthnFailure>((e) => e.code == 'signature_invalid'),
        ),
      );
      await expectLater(
        WebAuthn.assertion(
          rpId: rpId,
          challenge: 'abc',
          clientDataJson: '!!!!',
          authenticatorData: 'AA',
          signature: 'AA',
          alg: -7,
          x: const [1],
          y: const [1],
          signCount: 0,
        ),
        throwsA(predicate<WebAuthnFailure>((e) => e.code == 'passkey_invalid')),
      );

      expect(
        () => WebAuthn.registration(
          rpId: rpId,
          challenge: 'abc',
          clientDataJson: _b64(
            _client(
              type: 'webauthn.create',
              challenge: 'abc',
              origin: 'https://leca.world',
            ),
          ),
          attestationObject: _b64(Cbor.encode('nope')),
        ),
        throwsA(predicate<WebAuthnFailure>((e) => e.code == 'passkey_invalid')),
      );
      expect(
        () => WebAuthn.registration(
          rpId: rpId,
          challenge: 'abc',
          clientDataJson: _b64(
            _client(
              type: 'webauthn.create',
              challenge: 'abc',
              origin: 'https://leca.world',
            ),
          ),
          attestationObject: _b64(
            Cbor.encode({
              'fmt': 'none',
              'attStmt': <String, Object>{},
              'authData': _authData(rpId: rpId, flags: 0x05, count: 1),
            }),
          ),
        ),
        throwsA(predicate<WebAuthnFailure>((e) => e.code == 'passkey_invalid')),
      );
      expect(
        () => WebAuthn.registration(
          rpId: rpId,
          challenge: 'abc',
          clientDataJson: _b64(
            _client(
              type: 'webauthn.get',
              challenge: 'abc',
              origin: 'https://127.0.0.1',
            ),
          ),
          attestationObject: 'AA',
        ),
        throwsA(predicate<WebAuthnFailure>((e) => e.code == 'passkey_invalid')),
      );
    });
  });
}

String _b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

Uint8List _client({
  required String type,
  required String challenge,
  required String origin,
}) {
  return Uint8List.fromList(
    utf8.encode(
      jsonEncode({'type': type, 'challenge': challenge, 'origin': origin}),
    ),
  );
}

Uint8List _authData({
  required String rpId,
  required int flags,
  required int count,
  List<int>? credentialId,
  List<int>? cose,
}) {
  final out = BytesBuilder()
    ..add(sha256.convert(utf8.encode(rpId)).bytes)
    ..addByte(flags)
    ..addByte((count >> 24) & 0xff)
    ..addByte((count >> 16) & 0xff)
    ..addByte((count >> 8) & 0xff)
    ..addByte(count & 0xff);
  if (credentialId != null) {
    out
      ..add(Uint8List(16))
      ..addByte((credentialId.length >> 8) & 0xff)
      ..addByte(credentialId.length & 0xff)
      ..add(credentialId)
      ..add(cose!);
  }
  return out.toBytes();
}

Uint8List _be(BigInt value) {
  final hex = value.toRadixString(16).padLeft(64, '0');
  return Uint8List.fromList([
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ]);
}

List<int> _derInt(List<int> raw) {
  final body = raw.isNotEmpty && raw.first & 0x80 != 0 ? [0, ...raw] : raw;
  return [0x02, body.length, ...body];
}

List<int> _der(List<int> r, List<int> s) {
  final body = [..._derInt(r), ..._derInt(s)];
  return [0x30, body.length, ...body];
}

class _P256 {
  _P256() {
    final domain = ECCurve_secp256r1();
    final secret = BigInt.parse('1234567890123456789012345678901234567890');
    final point = (domain.G * secret)!;
    x = _be(point.x!.toBigInteger()!);
    y = _be(point.y!.toBigInteger()!);
    _key = ECPrivateKey(secret, domain);
  }

  late final Uint8List x;
  late final Uint8List y;
  late final ECPrivateKey _key;

  Uint8List sign(List<int> message) {
    final signer = ECDSASigner(SHA256Digest(), HMac(SHA256Digest(), 64))
      ..init(true, PrivateKeyParameter<ECPrivateKey>(_key));
    final signature =
        signer.generateSignature(Uint8List.fromList(message)) as ECSignature;
    return Uint8List.fromList([..._be(signature.r), ..._be(signature.s)]);
  }

  Uint8List signDer(List<int> message) {
    final signer = ECDSASigner(SHA256Digest(), HMac(SHA256Digest(), 64))
      ..init(true, PrivateKeyParameter<ECPrivateKey>(_key));
    final signature =
        signer.generateSignature(Uint8List.fromList(message)) as ECSignature;
    return Uint8List.fromList(_der(_be(signature.r), _be(signature.s)));
  }
}
