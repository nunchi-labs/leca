import 'dart:convert';

import 'package:crypto/crypto.dart';

/// One line in a chat. The proof covers the line and every line before it.
///
/// [who] binds the line to an account: a short hash of the account id, so
/// two people with the same name stay apart and the id itself stays private.
class TalkLine {
  const TalkLine({
    required this.seq,
    required this.room,
    required this.kind,
    required this.name,
    required this.at,
    required this.text,
    required this.prev,
    required this.proof,
    this.who = '',
  });

  final int seq;
  final String room;
  final String kind;
  final String name;
  final String who;
  final String at;
  final String text;
  final String prev;
  final String proof;

  bool get checksOut => proof == talkProof(this) && _kindOk(kind);

  Map<String, Object?> toJson() => {
    'seq': seq,
    'room': room,
    'kind': kind,
    'name': name,
    'who': who,
    'at': at,
    'text': text,
    'prev': prev,
    'proof': proof,
  };

  static TalkLine? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final seq = raw['seq'];
    if (seq is! int || seq < 1) return null;
    return TalkLine(
      seq: seq,
      room: _field(raw['room']),
      kind: _field(raw['kind']),
      name: _field(raw['name']),
      who: _field(raw['who'] ?? ''),
      at: _field(raw['at']),
      text: _field(raw['text']),
      prev: _field(raw['prev']),
      proof: _field(raw['proof']),
    );
  }
}

/// The public handle for an account inside a room. Same on every device
/// and on the server, so a line can be matched to its author without
/// publishing the account id.
String talkWho(String accountId) {
  if (accountId.isEmpty) return '';
  final digest = sha256.convert(utf8.encode('leca-who/1\n$accountId\n'));
  return digest.toString().substring(0, 16);
}

String talkStamp(DateTime at) {
  final utc = at.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  String three(int n) => n.toString().padLeft(3, '0');
  return '${utc.year}-${two(utc.month)}-${two(utc.day)}'
      'T${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}'
      '.${three(utc.millisecond)}Z';
}

String talkBody(TalkLine line) {
  return 'leca-talk/2\n'
      'seq=${line.seq}\n'
      'room=${line.room}\n'
      'kind=${line.kind}\n'
      'name=${line.name}\n'
      'who=${line.who}\n'
      'at=${line.at}\n'
      'text=${line.text}\n'
      'prev=${line.prev}\n';
}

String talkProof(TalkLine line) =>
    sha256.convert(utf8.encode(talkBody(line))).toString();

TalkLine talkAppend({
  required List<TalkLine> prior,
  required String room,
  required String kind,
  required String name,
  required DateTime at,
  required String text,
  String who = '',
}) {
  final prev = prior.isEmpty ? '' : prior.last.proof;
  final draft = TalkLine(
    seq: prior.length + 1,
    room: room,
    kind: _kindOk(kind) ? kind : 'text',
    name: _clip(name, 24, 'Guest'),
    who: _clip(who, 16, ''),
    at: talkStamp(at),
    text: _clip(text.replaceAll(RegExp(r'\s+'), ' ').trim(), 280, ''),
    prev: prev,
    proof: '',
  );
  return TalkLine(
    seq: draft.seq,
    room: draft.room,
    kind: draft.kind,
    name: draft.name,
    who: draft.who,
    at: draft.at,
    text: draft.text,
    prev: draft.prev,
    proof: talkProof(draft),
  );
}

/// True when every line matches its proof and follows the one before it.
bool talkChecks(List<TalkLine> lines) {
  var prev = '';
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.seq != i + 1 || line.prev != prev || !line.checksOut) {
      return false;
    }
    prev = line.proof;
  }
  return true;
}

/// A price line: `ask 2.40 driver`, `allow 2.40 customer`, `end 0.00 driver`.
/// Plain words so the proof can be read without the app.
class PriceLine {
  const PriceLine(this.verb, this.usd, this.side);

  final String verb;
  final double usd;
  final String side;

  static const verbs = {'ask', 'allow', 'end'};

  String encode() =>
      '$verb ${usd.toStringAsFixed(2)} ${side == 'driver' ? 'driver' : 'customer'}';

  static PriceLine? parse(String text) {
    final parts = text.trim().split(' ');
    if (parts.length != 3) return null;
    if (!verbs.contains(parts[0])) return null;
    final usd = double.tryParse(parts[1]);
    if (usd == null || usd < 0) return null;
    if (parts[2] != 'driver' && parts[2] != 'customer') return null;
    if (parts[0] != 'end' && usd <= 0) return null;
    return PriceLine(parts[0], usd, parts[2]);
  }
}

/// price lines carry a fare ask or an allow, so the bargain is in the proof.
bool _kindOk(String kind) =>
    kind == 'text' || kind == 'voice' || kind == 'video' || kind == 'price';

String _clip(String raw, int max, String fallback) {
  final cleaned = raw.replaceAll(RegExp(r'[\r\n]'), ' ').trim();
  if (cleaned.isEmpty) return fallback;
  return cleaned.length <= max ? cleaned : cleaned.substring(0, max);
}

String _field(Object? raw) => '$raw'.replaceAll(RegExp(r'[\r\n]'), ' ');
