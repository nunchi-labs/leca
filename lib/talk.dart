import 'dart:convert';

import 'package:crypto/crypto.dart';

/// One line in a chat. The proof covers the line and every line before it.
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
  });

  final int seq;
  final String room;
  final String kind;
  final String name;
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
      at: _field(raw['at']),
      text: _field(raw['text']),
      prev: _field(raw['prev']),
      proof: _field(raw['proof']),
    );
  }
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
  return 'leca-talk/1\n'
      'seq=${line.seq}\n'
      'room=${line.room}\n'
      'kind=${line.kind}\n'
      'name=${line.name}\n'
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
}) {
  final prev = prior.isEmpty ? '' : prior.last.proof;
  final draft = TalkLine(
    seq: prior.length + 1,
    room: room,
    kind: _kindOk(kind) ? kind : 'text',
    name: _clip(name, 24, 'Guest'),
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

/// price lines carry a fare ask or an allow, so the bargain is in the proof.
bool _kindOk(String kind) =>
    kind == 'text' || kind == 'voice' || kind == 'video' || kind == 'price';

String _clip(String raw, int max, String fallback) {
  final cleaned = raw.replaceAll(RegExp(r'[\r\n]'), ' ').trim();
  if (cleaned.isEmpty) return fallback;
  return cleaned.length <= max ? cleaned : cleaned.substring(0, max);
}

String _field(Object? raw) => '$raw'.replaceAll(RegExp(r'[\r\n]'), ' ');
