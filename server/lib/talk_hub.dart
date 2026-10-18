import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

/// The front-screen room. Names and distances apply only here.
const talkFrontRoom = 'front';

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
        } on Object catch (_) {
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
    } on Object catch (_) {}
  }

  _Seat? _join(WebSocket socket, Map<String, Object?> message) {
    final token = '${message['token'] ?? ''}';
    final room = _clip('${message['room'] ?? ''}', 80, 'lobby');
    final TalkIdentity? identity;
    var guest = false;
    if (token.isEmpty) {
      final guestId = _clip('${message['guest'] ?? ''}', 40, '');
      if (room != talkFrontRoom || !_guestOk(guestId)) {
        unawaited(socket.close());
        return null;
      }
      identity = (
        id: 'guest:$guestId',
        name: _clip('${message['name'] ?? ''}', 24, 'Guest'),
      );
      guest = true;
    } else {
      identity = _resolve(token);
      if (identity == null) {
        unawaited(socket.close());
        return null;
      }
    }
    final known =
        _rooms.containsKey(room) || (_file(room)?.existsSync() ?? false);
    if (!known && _rooms.length >= maxRooms) {
      unawaited(socket.close());
      return null;
    }
    final name = _clip(
      identity.name.trim().isEmpty ? 'Guest' : identity.name,
      24,
      'Guest',
    );
    final who = talkWho(identity.id);
    final seat = _Seat(socket, room, name, who)..guest = guest;
    _applyPlace(seat, message);
    _seats.putIfAbsent(room, () => []).add(seat);
    _remember(seat, message);
    final log = _log(room);
    _send(seat, {
      'type': 'welcome',
      'you': name,
      'who': who,
      'log': [for (final line in log) line.toJson()],
      'names': _names(room, seat),
      'people': _people(room, seat),
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
      case 'place':
        _applyPlace(seat, message);
        _presence(seat.room);
      case 'say':
        final kind = '${message['kind'] ?? 'text'}';
        final text = _clip('${message['text'] ?? ''}', 280, '');
        if (text.isEmpty) return;
        const kinds = {'text', 'voice', 'video', 'price'};
        if (!kinds.contains(kind)) return;
        if (kind == 'price') {
          // A bargain line needs a signed-in account behind it.
          if (seat.guest || seat.who.isEmpty || !_priceLine.hasMatch(text)) {
            return;
          }
        }
        if (seat.room == talkFrontRoom && seat.face == 'hide') return;
        final prior = _log(seat.room);
        if (prior.length >= maxLines) return;
        final line = _append(
          prior: prior,
          room: seat.room,
          kind: kind,
          name: seat.lineName,
          who: seat.who,
          text: text,
        );
        prior.add(line);
        _persist(seat.room, line);
        final swarmId = _clip('${message['id'] ?? ''}', 64, '');
        _broadcast(seat.room, {
          'type': 'entry',
          'entry': line.toJson(),
          if (swarmId.isNotEmpty) 'id': swarmId,
        }, from: seat);
      case 'swarm':
        final frame = '${message['frame'] ?? ''}';
        if (frame.isEmpty || frame.length > 12000) return;
        if (!frame.startsWith('{')) return;
        if (frame.contains('\n') || frame.contains('\r')) return;
        if (seat.room == talkFrontRoom && seat.face == 'hide') return;
        _broadcast(
          seat.room,
          {'type': 'swarm', 'frame': frame},
          except: seat,
          from: seat,
        );
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
    seat
      ..endpoint = endpoint
      ..addr = addr;
  }

  void _applyPlace(_Seat seat, Map<String, Object?> message) {
    final lat = _coord(message['lat'], -90, 90);
    final lng = _coord(message['lng'], -180, 180);
    if (lat != null && lng != null) {
      seat
        ..lat = lat
        ..lng = lng;
    }
    final radius = message['radius'];
    if (radius is num) {
      seat.radiusKm = radius.toDouble().clamp(1, talkCountryKm);
    }
    final face = '${message['face'] ?? ''}';
    if (face == 'anon' || face == 'name' || face == 'hide') seat.face = face;
  }

  void _presence(String room) {
    final seats = List<_Seat>.from(_seats[room] ?? const []);
    if (room != talkFrontRoom) {
      _broadcast(room, {
        'type': 'presence',
        'names': _names(room, null),
        'peers': _peers(room),
      });
      return;
    }
    for (final seat in seats) {
      _send(seat, {
        'type': 'presence',
        'names': _names(room, seat),
        'people': _people(room, seat),
        'peers': _peers(room, except: seat),
      });
    }
  }

  List<String> _names(String room, _Seat? viewer) {
    if (room != talkFrontRoom || viewer == null) {
      return [for (final seat in _seats[room] ?? const <_Seat>[]) seat.name];
    }
    return [
      for (final seat in _seats[room] ?? const <_Seat>[])
        if (seat != viewer && _sees(viewer, seat) && seat.face == 'name')
          seat.name,
    ];
  }

  List<Map<String, Object?>> _people(String room, _Seat viewer) {
    if (room != talkFrontRoom) return const [];
    return [
      for (final seat in _seats[room] ?? const <_Seat>[])
        if (seat != viewer && _sees(viewer, seat))
          {
            'who': seat.who,
            'km': _km(viewer, seat),
            if (seat.face == 'name' && seat.name.isNotEmpty) 'name': seat.name,
          },
    ];
  }

  bool _sees(_Seat viewer, _Seat other) {
    if (other.face == 'hide') return false;
    final fromLat = viewer.lat;
    final fromLng = viewer.lng;
    final toLat = other.lat;
    final toLng = other.lng;
    if (fromLat == null || fromLng == null || toLat == null || toLng == null) {
      return false;
    }
    return chatSees(
      km: talkKm(fromLat, fromLng, toLat, toLng),
      radiusKm: viewer.radiusKm,
      theirRadiusKm: other.radiusKm,
    );
  }

  int _km(_Seat viewer, _Seat other) {
    final km = talkKm(viewer.lat!, viewer.lng!, other.lat!, other.lng!);
    if (km < 0.5) return 0;
    return km.round();
  }

  List<Map<String, String>> _peers(String room, {_Seat? except}) {
    return [
      for (final seat in _seats[room] ?? const <_Seat>[])
        if (seat != except &&
            seat.endpoint.isNotEmpty &&
            seat.addr.isNotEmpty &&
            (except == null || room != talkFrontRoom || _sees(except, seat)))
          {
            'endpoint': seat.endpoint,
            'addr': seat.addr,
            'name': room == talkFrontRoom ? seat.lineName : seat.name,
          },
    ];
  }

  void _broadcast(
    String room,
    Map<String, Object?> message, {
    _Seat? except,
    _Seat? from,
  }) {
    for (final seat in List<_Seat>.from(_seats[room] ?? const [])) {
      if (seat == except) continue;
      if (from != null &&
          room == talkFrontRoom &&
          seat != from &&
          !_sees(seat, from)) {
        continue;
      }
      _send(seat, message);
    }
  }

  void _send(_Seat seat, Map<String, Object?> message) {
    try {
      seat.socket.add(jsonEncode(message));
    } on Object catch (_) {}
  }

  Map<String, Object?>? _decode(Object? raw) {
    try {
      final decoded = jsonDecode('$raw');
      if (decoded is! Map) return null;
      return decoded.map((key, value) => MapEntry('$key', value));
    } on Object catch (_) {
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

const talkCountryKm = 101.0;

/// Both circles have to cover the gap. A country-wide radius does not cut.
bool chatSees({
  required double km,
  required double radiusKm,
  required double theirRadiusKm,
  double countryKm = talkCountryKm,
}) {
  final mine = radiusKm >= countryKm || km <= radiusKm;
  final theirs = theirRadiusKm >= countryKm || km <= theirRadiusKm;
  return mine && theirs;
}

double talkKm(double lat1, double lng1, double lat2, double lng2) {
  const earthKm = 6371.0;
  double rad(double degrees) => degrees * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return earthKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

final _guestId = RegExp(r'^[A-Za-z0-9_-]{8,40}$');

bool _guestOk(String id) => _guestId.hasMatch(id);

double? _coord(Object? raw, double low, double high) {
  if (raw is! num) return null;
  final value = raw.toDouble();
  if (value < low || value > high) return null;
  return value;
}

class _Seat {
  _Seat(this.socket, this.room, this.name, this.who);

  final WebSocket socket;
  final String room;
  final String name;
  final String who;
  String endpoint = '';
  String addr = '';
  bool guest = false;
  double? lat;
  double? lng;
  double radiusKm = 10;
  String face = 'anon';

  /// What a front-room line may carry. A distance is filled in by the reader.
  String get lineName => room == talkFrontRoom && face != 'name' ? '' : name;
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
