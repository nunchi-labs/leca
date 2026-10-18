import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Bytes the device signs and the auth server checks.
///
/// The server builds this same text in `keyProofMessage`.
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

String encodeKey(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

Uint8List decodeKey(String raw) {
  final pad = '=' * ((4 - raw.length % 4) % 4);
  return Uint8List.fromList(base64Url.decode('$raw$pad'));
}

/// Account id is the public key itself, so the same device stays the same person.
String keyAccountId(List<int> publicKey) {
  final hex = publicKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return 'key:$hex';
}

String keyHandle(List<int> publicKey) =>
    keyAccountId(publicKey).substring(4, 12);

/// Ed25519 key that stays on this device. The server sees the public half and the name.
class DeviceKey {
  DeviceKey._(this.seed, this.publicKey);

  final Uint8List seed;
  final Uint8List publicKey;

  static final Ed25519 _ed = Ed25519();

  String get publicKeyEncoded => encodeKey(publicKey);

  String get accountId => keyAccountId(publicKey);

  String get handle => keyHandle(publicKey);

  static Future<DeviceKey> generate() async {
    return _fromPair(await _ed.newKeyPair());
  }

  static Future<DeviceKey> fromSeed(List<int> seed) async {
    return _fromPair(await _ed.newKeyPairFromSeed(seed));
  }

  static Future<DeviceKey> _fromPair(SimpleKeyPair pair) async {
    final data = await pair.extract();
    final public = await pair.extractPublicKey();
    return DeviceKey._(
      Uint8List.fromList(data.bytes),
      Uint8List.fromList(public.bytes),
    );
  }

  Future<String> signProof({
    required String challenge,
    required String name,
  }) async {
    final pair = await _ed.newKeyPairFromSeed(seed);
    final signature = await _ed.sign(
      utf8.encode(
        keyProofMessage(
          challenge: challenge,
          publicKey: publicKeyEncoded,
          name: name,
        ),
      ),
      keyPair: pair,
    );
    return encodeKey(signature.bytes);
  }
}
