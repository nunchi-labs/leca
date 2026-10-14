import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// One room for everyone on a trip. Names are shown. Addresses stay inside.
class TalkHub {
  final Map<String, List<_Line>> _rooms = {};
  final Map<String, List<_Seat>> _seats = {};

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

  _Seat _join(WebSocket socket, Map<String, Object?> message) {
    final room = _clip('${message['room'] ?? ''}', 80, 'lobby');
    final name = _clip('${message['name'] ?? ''}', 24, 'Guest');
    final seat = _Seat(socket, room, name);
    _seats.putIfAbsent(room, () => []).add(seat);
    _remember(seat, message);
    final log = _rooms[room] ?? const <_Line>[];
    _send(seat, {
      'type': 'welcome',
      'you': name,
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
        final prior = _rooms.putIfAbsent(seat.room, () => []);
        final line = _append(
          prior: prior,
          room: seat.room,
          kind: kind,
          name: seat.name,
          text: text,
        );
        prior.add(line);
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
          {'endpoint': seat.endpoint, 'addr': seat.addr},
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

class _Seat {
  _Seat(this.socket, this.room, this.name);

  final WebSocket socket;
  final String room;
  final String name;
  String endpoint = '';
  String addr = '';
}

class _Line {
  _Line({
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
}

_Line _append({
  required List<_Line> prior,
  required String room,
  required String kind,
  required String name,
  required String text,
}) {
  final prev = prior.isEmpty ? '' : prior.last.proof;
  final at = _stamp(DateTime.now().toUtc());
  final draft = _Line(
    seq: prior.length + 1,
    room: room,
    kind: kind,
    name: name,
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
    at: draft.at,
    text: draft.text,
    prev: draft.prev,
    proof: _proof(draft),
  );
}

String _proof(_Line line) {
  final body = 'leca-talk/1\n'
      'seq=${line.seq}\n'
      'room=${line.room}\n'
      'kind=${line.kind}\n'
      'name=${line.name}\n'
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
  final seq = json['seq'];
  if (seq is! int) return false;
  final line = _Line(
    seq: seq,
    room: '${json['room']}',
    kind: '${json['kind']}',
    name: '${json['name']}',
    at: '${json['at']}',
    text: '${json['text']}',
    prev: '${json['prev']}',
    proof: '',
  );
  return _proof(line) == json['proof'];
}

String _clip(String raw, int max, String fallback) {
  final cleaned = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (cleaned.isEmpty) return fallback;
  return cleaned.length <= max ? cleaned : cleaned.substring(0, max);
}
