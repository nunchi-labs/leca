import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Who a session token belongs to. Null when the token is unknown.
typedef TalkIdentity = ({String id, String name});
typedef TalkResolver = TalkIdentity? Function(String token);

/// One room for everyone on a trip. Names are shown. Addresses stay inside.
///
/// Each room's lines are appended to a file under [logDir] as they happen,
/// so a restart loses nothing and every proof chain can be re-read later.
class TalkHub {
  TalkHub({this.logDir, TalkResolver? resolve}) : _resolve = resolve ?? _nobody;

  static TalkIdentity? _nobody(String token) => null;

  final String? logDir;
  final TalkResolver _resolve;
  final Map<String, List<_Line>> _rooms = {};
  final Map<String, List<_Seat>> _seats = {};

  static const maxLines = 500;
  static const maxRooms = 4000;

  static final _priceLine = RegExp(
    r'^(ask|allow|end) (\d{1,6}\.\d{2}) (driver|customer)$',
  );

  void attach(WebSocket socket) {
    _Seat? seat;
    socket.listen(
      (raw) {
        final message = _decode(raw);
        if (message == null) return;
        if (seat == null) {
          if (message['type'] != 'join') return;
          seat = _join(socket, message);
          return;
        }
        _on(seat!, message);
      },
      onDone: () {
        if (seat != null) _leave(seat!);
      },
      onError: (_) {
        if (seat != null) _leave(seat!);
      },
    );
  }

  /// The lines of a room, loading from disk on first touch.
  List<_Line> _log(String room) {
    final cached = _rooms[room];
    if (cached != null) return cached;
    final lines = <_Line>[];
    final file = _file(room);
    if (file != null && file.existsSync()) {
      for (final raw in file.readAsLinesSync()) {
        if (raw.trim().isEmpty) continue;
        try {
          final decoded = jsonDecode(raw);
          if (decoded is! Map) continue;
          final line = _Line.fromJson(decoded.map((k, v) => MapEntry('$k', v)));
          if (line != null &&
              line.seq == lines.length + 1 &&
              line.prev == (lines.isEmpty ? '' : lines.last.proof) &&
              _proof(line) == line.proof) {
            lines.add(line);
          } else {
            break;
          }
        } catch (_) {
          break;
        }
      }
    }
    _rooms[room] = lines;
    return lines;
  }

  File? _file(String room) {
    final dir = logDir;
    if (dir == null) return null;
    final safe = room.replaceAll(RegExp(r'[^A-Za-z0-9_.:-]'), '_');
    return File('$dir/$safe.jsonl');
  }

  void _persist(String room, _Line line) {
    final file = _file(room);
    if (file == null) return;
    try {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${jsonEncode(line.toJson())}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
  }

  _Seat? _join(WebSocket socket, Map<String, Object?> message) {
    final room = _clip('${message['room'] ?? ''}', 80, 'lobby');
    final known =
        _rooms.containsKey(room) || (_file(room)?.existsSync() ?? false);
    if (!known && _rooms.length >= maxRooms) {
      socket.close();
      return null;
    }
    var name = _clip('${message['name'] ?? ''}', 24, 'Guest');
    var who = '';
    final token = '${message['token'] ?? ''}';
    final identity = token.isEmpty ? null : _resolve(token);
    if (identity != null) {
      who = talkWho(identity.id);
      if (identity.name.trim().isNotEmpty) {
        name = _clip(identity.name, 24, name);
      }
    }
    final seat = _Seat(socket, room, name, who);
    _seats.putIfAbsent(room, () => []).add(seat);
    _remember(seat, message);
    final log = _log(room);
    _send(seat, {
      'type': 'welcome',
      'you': name,
      'who': who,
      'log': [for (final line in log) line.toJson()],
      'names': _names(room),
      'peers': _peers(room, except: seat),
    });
    _presence(room);
    return seat;
  }

  void _on(_Seat seat, Map<String, Object?> message) {
    switch (message['type']) {
      case 'addr':
        _remember(seat, message);
        _presence(seat.room);
      case 'say':
        final kind = '${message['kind'] ?? 'text'}';
        final text = _clip('${message['text'] ?? ''}', 280, '');
        if (text.isEmpty) return;
        const kinds = {'text', 'voice', 'video', 'price'};
        if (!kinds.contains(kind)) return;
        if (kind == 'price') {
          // A bargain line needs a signed-in account behind it.
          if (seat.who.isEmpty || !_priceLine.hasMatch(text)) return;
        }
        final prior = _log(seat.room);
        if (prior.length >= maxLines) return;
        final line = _append(
          prior: prior,
          room: seat.room,
          kind: kind,
          name: seat.name,
          who: seat.who,
          text: text,
        );
        prior.add(line);
        _persist(seat.room, line);
        _broadcast(seat.room, {'type': 'entry', 'entry': line.toJson()});
    }
  }

  void _leave(_Seat seat) {
    _seats[seat.room]?.remove(seat);
    _presence(seat.room);
  }

  void _remember(_Seat seat, Map<String, Object?> message) {
    final endpoint = '${message['endpoint'] ?? ''}';
    final addr = '${message['addr'] ?? ''}';
    if (endpoint.isEmpty || addr.isEmpty) return;
    if (endpoint.length > 80 || addr.length > 4000) return;
    seat.endpoint = endpoint;
    seat.addr = addr;
  }

  void _presence(String room) {
    _broadcast(room, {
      'type': 'presence',
      'names': _names(room),
      'peers': _peers(room),
    });
  }

  List<String> _names(String room) => [
    for (final seat in _seats[room] ?? const <_Seat>[]) seat.name,
  ];

  List<Map<String, String>> _peers(String room, {_Seat? except}) {
    return [
      for (final seat in _seats[room] ?? const <_Seat>[])
        if (seat != except && seat.endpoint.isNotEmpty && seat.addr.isNotEmpty)
          {'endpoint': seat.endpoint, 'addr': seat.addr, 'name': seat.name},
    ];
  }

  void _broadcast(String room, Map<String, Object?> message) {
    for (final seat in List<_Seat>.from(_seats[room] ?? const [])) {
      _send(seat, message);
    }
  }

  void _send(_Seat seat, Map<String, Object?> message) {
    try {
      seat.socket.add(jsonEncode(message));
    } catch (_) {}
  }

  Map<String, Object?>? _decode(Object? raw) {
    try {
      final decoded = jsonDecode('$raw');
      if (decoded is! Map) return null;
      return decoded.map((key, value) => MapEntry('$key', value));
    } catch (_) {
      return null;
    }
  }
}

/// Same derivation as the app: a short hash, never the account id.
String talkWho(String accountId) {
  if (accountId.isEmpty) return '';
  final digest = sha256.convert(utf8.encode('leca-who/1\n$accountId\n'));
  return digest.toString().substring(0, 16);
}

class _Seat {
  _Seat(this.socket, this.room, this.name, this.who);

  final WebSocket socket;
  final String room;
  final String name;
  final String who;
  String endpoint = '';
  String addr = '';
}

class _Line {
  _Line({
    required this.seq,
    required this.room,
    required this.kind,
    required this.name,
    required this.who,
    required this.at,
    required this.text,
    required this.prev,
    required this.proof,
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

  static _Line? fromJson(Map<String, Object?> json) {
    final seq = json['seq'];
    if (seq is! int) return null;
    return _Line(
      seq: seq,
      room: '${json['room']}',
      kind: '${json['kind']}',
      name: '${json['name']}',
      who: '${json['who'] ?? ''}',
      at: '${json['at']}',
      text: '${json['text']}',
      prev: '${json['prev']}',
      proof: '${json['proof']}',
    );
  }
}

_Line _append({
  required List<_Line> prior,
  required String room,
  required String kind,
  required String name,
  required String who,
  required String text,
}) {
  final prev = prior.isEmpty ? '' : prior.last.proof;
  final at = _stamp(DateTime.now().toUtc());
  final draft = _Line(
    seq: prior.length + 1,
    room: room,
    kind: kind,
    name: name,
    who: who,
    at: at,
    text: text,
    prev: prev,
    proof: '',
  );
  return _Line(
    seq: draft.seq,
    room: draft.room,
    kind: draft.kind,
    name: draft.name,
    who: draft.who,
    at: draft.at,
    text: draft.text,
    prev: draft.prev,
    proof: _proof(draft),
  );
}

String _proof(_Line line) {
  final body =
      'leca-talk/2\n'
      'seq=${line.seq}\n'
      'room=${line.room}\n'
      'kind=${line.kind}\n'
      'name=${line.name}\n'
      'who=${line.who}\n'
      'at=${line.at}\n'
      'text=${line.text}\n'
      'prev=${line.prev}\n';
  return sha256.convert(utf8.encode(body)).toString();
}

String _stamp(DateTime utc) {
  String two(int n) => n.toString().padLeft(2, '0');
  String three(int n) => n.toString().padLeft(3, '0');
  return '${utc.year}-${two(utc.month)}-${two(utc.day)}'
      'T${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}'
      '.${three(utc.millisecond)}Z';
}

bool publishedTalkChecks(Map<String, Object?> json) {
  final line = _Line.fromJson(json);
  if (line == null) return false;
  return _proof(line) == json['proof'];
}

String _clip(String raw, int max, String fallback) {
  final cleaned = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (cleaned.isEmpty) return fallback;
  return cleaned.length <= max ? cleaned : cleaned.substring(0, max);
}
