import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The front-screen room. Every signed-in person can chat and deal here.
const frontRoom = 'front';

/// How a person appears in [frontRoom].
const chatFaceAnon = 'anon';
const chatFaceName = 'name';
const chatFaceHide = 'hide';

/// Both circles have to cover the gap. A country-wide radius does not cut.
bool chatSees({
  required double km,
  required double radiusKm,
  required double theirRadiusKm,
  double countryKm = 101,
}) {
  final mine = radiusKm >= countryKm || km <= radiusKm;
  final theirs = theirRadiusKm >= countryKm || km <= theirRadiusKm;
  return mine && theirs;
}

/// The bargain for [frontRoom]. The agreed price is what checkout charges.
const frontFare = 'front';

/// The Leca room socket. Browsers join the swarm on this link.
const relayLink = 'relay';

/// Every iroh neighbor, as one link. iPhone, Mac, and Windows dial each other
/// here; a frame that arrived on [relayLink] is written here so the browser
/// reaches them.
const meshLink = 'mesh';

/// Someone else in the front-screen chat. [name] is empty when they
/// stay anonymous, and [km] is how far they are from this device.
class ChatNear {
  const ChatNear({required this.who, required this.km, this.name = ''});

  final String who;
  final int km;
  final String name;
}

/// One neighbor we can dial. [id] is the iroh endpoint. [addr] is its card.
class SwarmPeer {
  const SwarmPeer(this.id, this.addr);

  final String id;
  final String addr;
}

/// One swarm frame. Chat, voice, video, and price all use this shape.
class SwarmMessage {
  const SwarmMessage({
    required this.topic,
    required this.kind,
    required this.text,
    required this.from,
    this.id = '',
    this.name = '',
    this.who = '',
    this.peers = const [],
  });

  final String topic;
  final String id;
  final String kind;
  final String text;
  final String from;
  final String name;
  final String who;
  final List<SwarmPeer> peers;

  bool get chat =>
      kind == 'text' || kind == 'voice' || kind == 'video' || kind == 'price';

  String encode() {
    final body = <String, Object?>{
      'topic': topic,
      'kind': kind,
      'text': text,
      'from': from,
      if (id.isNotEmpty) 'id': id,
      if (name.isNotEmpty) 'name': name,
      if (who.isNotEmpty) 'who': who,
      if (peers.isNotEmpty)
        'peers': [
          for (final peer in peers) {'id': peer.id, 'addr': peer.addr},
        ],
    };
    return jsonEncode(body);
  }

  static SwarmMessage? decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final peers = <SwarmPeer>[];
      final listed = decoded['peers'];
      if (listed is List) {
        for (final item in listed) {
          if (item is! Map) continue;
          peers.add(SwarmPeer('${item['id'] ?? ''}', '${item['addr'] ?? ''}'));
        }
      }
      return SwarmMessage(
        topic: '${decoded['topic'] ?? ''}',
        id: '${decoded['id'] ?? ''}',
        kind: '${decoded['kind'] ?? ''}',
        text: '${decoded['text'] ?? ''}',
        from: '${decoded['from'] ?? ''}',
        name: '${decoded['name'] ?? ''}',
        who: '${decoded['who'] ?? ''}',
        peers: peers,
      );
    } on Object catch (_) {
      return null;
    }
  }
}

/// What a received frame asks the device to do.
class SwarmEffect {
  const SwarmEffect({this.deliver, this.dial = const []});

  final SwarmMessage? deliver;
  final List<SwarmPeer> dial;

  static const empty = SwarmEffect();
}

/// A gossip swarm. Each device writes a frame to every link it has, and
/// forwards a new frame to the links it did not arrive on.
///
/// Web has the relay. iPhone, Mac, and Windows have the relay and the iroh
/// mesh, so a browser frame is carried onto iroh and an iroh frame is
/// carried back to the browser.
class TalkSwarm {
  TalkSwarm({required this.self, required this.topic});

  final String self;
  final String topic;
  String name = '';
  String who = '';

  final Map<String, void Function(String frame)> _links = {};
  final Map<String, String> _peers = {};
  final List<String> _seen = [];
  var _seq = 0;

  static const _seenCap = 500;
  static const _peerCap = 32;
  static const _announce = 8;

  bool get hasLinks => _links.isNotEmpty;

  void link(String id, void Function(String frame) write) {
    if (id.isEmpty) return;
    _links[id] = write;
  }

  void unlink(String id) {
    _links.remove(id);
  }

  /// Remember peers from the room. Returns the ones we had not seen.
  List<SwarmPeer> introduce(List<SwarmPeer> peers) => _merge(peers);

  String hello() {
    return SwarmMessage(
      topic: topic,
      kind: 'hello',
      text: 'joined',
      from: self,
      name: name,
      who: who,
      peers: _card(),
    ).encode();
  }

  /// Publish a line on every link. Empty text publishes nothing.
  SwarmMessage? broadcast({
    required String kind,
    required String text,
    String? name,
    String? who,
  }) {
    final body = _words(text, 280);
    if (body.isEmpty || !_chat(kind)) return null;
    if (name != null) this.name = _words(name, 24);
    if (who != null) this.who = _words(who, 16);
    _seq += 1;
    final stamp = DateTime.now().toUtc().toIso8601String();
    final id = sha256
        .convert(
          utf8.encode(
            'leca-swarm/1\n$topic\n$self\n$kind\n${this.who}\n$stamp\n$_seq\n$body\n',
          ),
        )
        .toString()
        .substring(0, 32);
    final message = SwarmMessage(
      topic: topic,
      id: id,
      kind: kind,
      text: body,
      from: self,
      name: this.name,
      who: this.who,
    );
    _remember(id);
    final frame = message.encode();
    for (final write in _links.values) {
      write(frame);
    }
    return message;
  }

  SwarmEffect receive(String link, String raw) {
    final message = SwarmMessage.decode(raw);
    if (message == null || message.topic != topic) return SwarmEffect.empty;
    if (message.kind == 'hello' || message.kind == 'peers') {
      final learned = _merge(message.peers);
      _reply(link, message.peers);
      return SwarmEffect(dial: learned);
    }
    if (!message.chat || message.text.isEmpty || message.id.isEmpty) {
      return SwarmEffect.empty;
    }
    if (message.from == self || !_remember(message.id)) {
      return SwarmEffect.empty;
    }
    _forward(link, raw);
    return SwarmEffect(deliver: message);
  }

  void _reply(String link, List<SwarmPeer> theirs) {
    final write = _links[link];
    if (write == null) return;
    final known = {for (final peer in theirs) peer.id};
    final extra = <SwarmPeer>[];
    for (final entry in _peers.entries) {
      if (known.contains(entry.key)) continue;
      extra.add(SwarmPeer(entry.key, entry.value));
      if (extra.length >= _announce) break;
    }
    if (extra.isEmpty) return;
    write(
      SwarmMessage(
        topic: topic,
        kind: 'peers',
        text: 'peers',
        from: self,
        name: name,
        who: who,
        peers: extra,
      ).encode(),
    );
  }

  void _forward(String link, String frame) {
    for (final entry in _links.entries) {
      if (entry.key == link) continue;
      entry.value(frame);
    }
  }

  List<SwarmPeer> _merge(List<SwarmPeer> peers) {
    final learned = <SwarmPeer>[];
    for (final peer in peers) {
      if (!_peerOk(peer)) continue;
      if (_peers.containsKey(peer.id)) continue;
      if (_peers.length >= _peerCap) break;
      _peers[peer.id] = peer.addr;
      learned.add(peer);
    }
    return learned;
  }

  List<SwarmPeer> _card() {
    final out = <SwarmPeer>[];
    for (final entry in _peers.entries) {
      out.add(SwarmPeer(entry.key, entry.value));
      if (out.length >= _announce) break;
    }
    return out;
  }

  bool _peerOk(SwarmPeer peer) {
    if (peer.id.isEmpty || peer.addr.isEmpty) return false;
    if (peer.id == self) return false;
    if (peer.id.length > 80 || peer.addr.length > 4000) return false;
    return true;
  }

  bool _remember(String id) {
    if (id.isEmpty || _seen.contains(id)) return false;
    _seen.add(id);
    if (_seen.length > _seenCap) _seen.removeAt(0);
    return true;
  }
}

bool _chat(String kind) =>
    kind == 'text' || kind == 'voice' || kind == 'video' || kind == 'price';

String _words(String raw, int max) {
  final cleaned = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (cleaned.isEmpty) return '';
  return cleaned.length <= max ? cleaned : cleaned.substring(0, max);
}
