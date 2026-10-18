import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:iroh_flutter/iroh_flutter.dart';

/// One iroh endpoint for the device. Talk and the phone are two ALPNs on it,
/// so a call and a chat do not bind the same key twice.
const talkAlpn = [108, 101, 99, 97, 45, 116, 97, 108, 107, 47, 49];
const phoneAlpn = [108, 101, 99, 97, 45, 112, 104, 111, 110, 101, 47, 49];

class IrohHub {
  IrohHub._();

  static final IrohHub instance = IrohHub._();

  final peers = <String, EndpointAddr>{};
  final _publishers = <void Function(String endpoint, String addr)>[];
  final _talkWrites = <String, SendStream>{};
  final _talkLinked = <String>{};
  final _phoneSends = <String, SendStream>{};
  final _phoneConns = <String, Connection>{};

  Endpoint? _endpoint;
  Router? _router;
  StreamSubscription<EndpointAddr>? _addrSub;
  Future<void> _queue = Future<void>.value();
  var _holders = 0;
  var _alive = false;

  String? endpointId;
  String? addrB64;

  void Function(String from, String kind, String text)? onTalk;
  void Function(String from, String frame)? onTalkFrame;
  void Function(String from, String line)? onPhoneLine;
  void Function(String from, Uint8List packet)? onPhoneAudio;

  Future<void> acquire({List<int>? secret}) {
    final run = _queue.then((_) async {
      _holders += 1;
      try {
        if (_endpoint == null) await _bind(secret);
      } on Object catch (_) {
        _holders -= 1;
        rethrow;
      }
    });
    _queue = run.then((_) {}, onError: (Object _) {});
    return run;
  }

  Future<void> release() {
    final run = _queue.then((_) async {
      if (_holders > 0) _holders -= 1;
      if (_holders > 0) return;
      await _shutdown();
    });
    _queue = run.then((_) {}, onError: (Object _) {});
    return run;
  }

  void Function() listen(void Function(String endpoint, String addr) publish) {
    _publishers.add(publish);
    final id = endpointId;
    final addr = addrB64;
    if (id != null && addr != null && id.isNotEmpty && addr.isNotEmpty) {
      publish(id, addr);
    }
    return () => _publishers.remove(publish);
  }

  void noteTalkPeers(Object? peers) {
    if (peers is! List) return;
    for (final peer in peers) {
      if (peer is! Map) continue;
      final endpoint = '${peer['endpoint'] ?? ''}';
      final addr = '${peer['addr'] ?? ''}';
      if (endpoint.isEmpty || addr.isEmpty) continue;
      try {
        this.peers[endpoint] = EndpointAddr.decode(base64Decode(addr));
      } on Object catch (_) {}
    }
    unawaited(_dialTalk());
  }

  void sendTalk(String kind, String text) {
    sendTalkFrame(jsonEncode({'kind': kind, 'text': text}));
  }

  /// One swarm frame to every talk neighbor, except [except] when set.
  void sendTalkFrame(String frame, {String? except}) {
    final line = utf8.encode(frame.endsWith('\n') ? frame : '$frame\n');
    for (final entry in Map<String, SendStream>.from(_talkWrites).entries) {
      if (entry.key == except) continue;
      unawaited(_write(entry.value, line));
    }
  }

  Future<void> connectPhone(String endpoint, String addr) async {
    if (_phoneSends.containsKey(endpoint)) return;
    final local = _endpoint;
    if (local == null || !_alive) throw StateError('down');
    final remote = EndpointAddr.decode(base64Decode(addr));
    peers[endpoint] = remote;
    final conn = await local.connect(remote, phoneAlpn);
    final opened = await conn.openBi();
    _phoneSends[endpoint] = opened.$1;
    _phoneConns[endpoint] = conn;
    unawaited(_readPhone(endpoint, opened.$2));
    unawaited(_readAudio(conn));
  }

  void sendPhone(String endpoint, String line) {
    final send = _phoneSends[endpoint];
    if (send == null) return;
    unawaited(_write(send, utf8.encode('$line\n')));
  }

  void sendPhoneAudio(String endpoint, Uint8List packet) {
    final conn = _phoneConns[endpoint];
    if (conn == null) return;
    try {
      conn.sendDatagram(packet);
    } on Object catch (_) {}
  }

  void dropPhone(String endpoint) {
    _phoneSends.remove(endpoint);
    final conn = _phoneConns.remove(endpoint);
    if (conn == null) return;
    try {
      conn.close(reason: utf8.encode('bye'));
    } on Object catch (_) {}
  }

  Future<void> _bind(List<int>? secret) async {
    await Iroh.init();
    final secretKey = secret != null && secret.length == 32
        ? SecretKey.fromBytes(secret)
        : null;
    final endpoint = await Endpoint.bindWithAddressLookup(
      secretKey: secretKey,
      alpns: const [talkAlpn, phoneAlpn],
      relayMode: RelayMode.n0Default,
      resolve: (id) => peers[id.toZ32()],
    );
    _endpoint = endpoint;
    _alive = true;
    final builder = await endpoint.router();
    await builder.accept(talkAlpn, (conn) {
      unawaited(_serveTalk(conn));
    });
    await builder.accept(phoneAlpn, (conn) {
      unawaited(_servePhone(conn));
    });
    _router = await builder.spawn();
    _emit(endpoint.addr);
    _addrSub = endpoint.watchAddr().listen(_emit, onError: (_) {});
  }

  Future<void> _shutdown() async {
    _alive = false;
    await _addrSub?.cancel();
    _addrSub = null;
    final router = _router;
    final endpoint = _endpoint;
    _router = null;
    _endpoint = null;
    endpointId = null;
    addrB64 = null;
    peers.clear();
    _talkWrites.clear();
    _talkLinked.clear();
    _phoneSends.clear();
    _phoneConns.clear();
    try {
      await router?.shutdown();
    } on Object catch (_) {}
    try {
      await endpoint?.close();
    } on Object catch (_) {}
  }

  void _emit(EndpointAddr addr) {
    String id;
    String card;
    try {
      id = addr.id.toZ32();
      card = base64Encode(addr.encode());
    } on Object catch (_) {
      return;
    }
    endpointId = id;
    addrB64 = card;
    for (final publish in List<void Function(String, String)>.from(
      _publishers,
    )) {
      publish(id, card);
    }
  }

  Future<void> _serveTalk(Connection conn) async {
    try {
      final from = conn.remoteId.toZ32();
      final opened = await conn.acceptBi();
      _talkWrites[from] = opened.$1;
      await _readTalk(from, opened.$2);
    } on Object catch (_) {}
  }

  Future<void> _servePhone(Connection conn) async {
    final from = conn.remoteId.toZ32();
    _phoneConns[from] = conn;
    unawaited(_readAudio(conn));
    try {
      final opened = await conn.acceptBi();
      _phoneSends[from] = opened.$1;
      await _readPhone(from, opened.$2);
    } on Object catch (_) {}
  }

  Future<void> _dialTalk() async {
    final endpoint = _endpoint;
    if (endpoint == null || !_alive) return;
    final mine = endpoint.id.toZ32();
    for (final entry in Map<String, EndpointAddr>.from(peers).entries) {
      if (entry.key == mine || _talkLinked.contains(entry.key)) continue;
      _talkLinked.add(entry.key);
      try {
        final conn = await endpoint.connect(entry.value, talkAlpn);
        final opened = await conn.openBi();
        _talkWrites[entry.key] = opened.$1;
        await opened.$1.writeAll(
          utf8.encode('{"kind":"hello","text":"joined"}\n'),
        );
        unawaited(_readTalk(entry.key, opened.$2));
      } on Object catch (_) {
        _talkLinked.remove(entry.key);
      }
    }
  }

  Future<void> _readTalk(String from, RecvStream recv) async {
    await _lines(recv, (line) {
      onTalkFrame?.call(from, line);
      try {
        final decoded = jsonDecode(line);
        if (decoded is! Map) return;
        final kind = '${decoded['kind'] ?? ''}';
        final text = '${decoded['text'] ?? ''}';
        if (kind.isEmpty || text.isEmpty || kind == 'hello') return;
        onTalk?.call(from, kind, text);
      } on Object catch (_) {}
    });
  }

  Future<void> _readPhone(String from, RecvStream recv) async {
    await _lines(recv, (line) => onPhoneLine?.call(from, line));
  }

  Future<void> _readAudio(Connection conn) async {
    final from = conn.remoteId.toZ32();
    while (_alive) {
      try {
        final packet = await conn.readDatagram();
        if (!_alive) return;
        onPhoneAudio?.call(from, packet);
      } on Object catch (_) {
        return;
      }
    }
  }

  Future<void> _lines(
    RecvStream recv,
    void Function(String line) onLine,
  ) async {
    try {
      final pending = <int>[];
      while (_alive) {
        final chunk = await recv.read(4096);
        if (chunk == null || !_alive) return;
        pending.addAll(chunk);
        var start = 0;
        for (var i = 0; i < pending.length; i++) {
          if (pending[i] != 0x0a) continue;
          final line = utf8.decode(pending.sublist(start, i));
          start = i + 1;
          if (line.isNotEmpty) onLine(line);
        }
        if (start > 0) pending.removeRange(0, start);
      }
    } on Object catch (_) {}
  }

  Future<void> _write(SendStream send, List<int> bytes) async {
    try {
      await send.writeAll(bytes);
    } on Object catch (_) {}
  }
}
