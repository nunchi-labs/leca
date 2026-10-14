import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const passwordIterations = 120000;

String hashPassword(String password, List<int> salt) {
  final digest = _pbkdf2(
    utf8.encode(password),
    salt,
    passwordIterations,
    32,
  );
  return base64Encode(digest);
}

List<int> newSalt(Random random) =>
    List<int>.generate(16, (_) => random.nextInt(256));

bool sameHash(String a, String b) {
  final left = ascii.encode(a);
  final right = ascii.encode(b);
  var diff = left.length ^ right.length;
  final n = left.length < right.length ? left.length : right.length;
  for (var i = 0; i < n; i++) {
    diff |= left[i] ^ right[i];
  }
  return diff == 0;
}

Uint8List _pbkdf2(List<int> password, List<int> salt, int iterations, int length) {
  final out = BytesBuilder();
  var block = 1;
  while (out.length < length) {
    out.add(_block(password, salt, iterations, block));
    block += 1;
  }
  final bytes = out.toBytes();
  return Uint8List.fromList(bytes.sublist(0, length));
}

List<int> _block(List<int> password, List<int> salt, int iterations, int index) {
  final hmac = Hmac(sha256, password);
  var u = hmac.convert([...salt, ..._be(index)]).bytes;
  final result = List<int>.from(u);
  for (var i = 1; i < iterations; i++) {
    u = hmac.convert(u).bytes;
    for (var j = 0; j < result.length; j++) {
      result[j] ^= u[j];
    }
  }
  return result;
}

List<int> _be(int value) => [
  (value >> 24) & 0xff,
  (value >> 16) & 0xff,
  (value >> 8) & 0xff,
  value & 0xff,
];
