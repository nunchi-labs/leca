import 'dart:async';
import 'dart:convert';

import 'package:iroh_flutter/iroh_flutter.dart';

import 'iroh_seat.dart' show IrohSeat;

/// Direct iroh link. The device key is the endpoint id other nodes dial.
class NativeIrohSeat extends IrohSeat {
  Endpoint? _endpoint;
  final Map<String, EndpointAddr> _peers = {};
  final Set<String> _linked = {};
  final List<SendStream> _sends = [];
  var _closed = false;
  void Function(String from, String kind, String text)? _onDirect;

  @override
  Future<void> start({
    required void Function(String endpoint, String addr) publish,
    void Function(String from, String kind, String text)? onDirect,
    List<int>? secret,
  }) async {
    _onDirect = onDirect;
    try {
      await Iroh.init();
      const alpn = [108, 101, 99, 97, 45, 116, 97, 108, 107, 47, 49];
      final secretKey = secret != null && secret.length == 32
          ? SecretKey.fromBytes(secret)
          : null;
      final endpoint = await Endpoint.bindWithAddressLookup(
        secretKey: secretKey,
        alpns: const [alpn],
        relayMode: RelayMode.n0Default,
        resolve: (id) => _peers[id.toZ32()],
      );
      _endpoint = endpoint;
      final addr = endpoint.addr;
      publish(addr.id.toZ32(), base64Encode(addr.encode()));
      unawaited(_accept(endpoint));
    } on Object catch (_) {}
  }

  Future<void> _accept(Endpoint endpoint) async {
    while (!_closed) {
      try {
        final conn = await endpoint.accept();
        if (conn == null || _closed) return;
        unawaited(_read(conn));
      } on Object catch (_) {
        return;
      }
    }
  }

  Future<void> _read(Connection conn) async {
    try {
      final from = conn.remoteId.toZ32();
      final opened = await conn.acceptBi();
      final pending = <int>[];
      while (!_closed) {
        final chunk = await opened.$2.read(4096);
        if (chunk == null) break;
        pending.addAll(chunk);
        var start = 0;
        for (var i = 0; i < pending.length; i++) {
          if (pending[i] != 0x0a) continue;
          final line = utf8.decode(pending.sublist(start, i));
          start = i + 1;
          _deliver(from, line);
        }
        if (start > 0) pending.removeRange(0, start);
      }
    } on Object catch (_) {}
  }

  void _deliver(String from, String line) {
    if (line.isEmpty) return;
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) return;
      final kind = '${decoded['kind'] ?? ''}';
      final text = '${decoded['text'] ?? ''}';
      if (kind.isEmpty || text.isEmpty || kind == 'hello') return;
      _onDirect?.call(from, kind, text);
    } on Object catch (_) {}
  }

  @override
  void notePeers(Object? peers) {
    if (peers is! List) return;
    for (final peer in peers) {
      if (peer is! Map) continue;
      final endpoint = '${peer['endpoint'] ?? ''}';
      final addr = '${peer['addr'] ?? ''}';
      if (endpoint.isEmpty || addr.isEmpty) continue;
      try {
        _peers[endpoint] = EndpointAddr.decode(base64Decode(addr));
      } on Object catch (_) {}
    }
    unawaited(_dial());
  }

  Future<void> _dial() async {
    final endpoint = _endpoint;
    if (endpoint == null || _closed) return;
    final mine = endpoint.id.toZ32();
    for (final entry in Map<String, EndpointAddr>.from(_peers).entries) {
      if (entry.key == mine || _linked.contains(entry.key)) continue;
      _linked.add(entry.key);
      try {
        final conn = await endpoint.connect(
          entry.value,
          utf8.encode('leca-talk/1'),
        );
        final opened = await conn.openBi();
        _sends.add(opened.$1);
        await opened.$1.writeAll(
          utf8.encode('{"kind":"hello","text":"joined"}\n'),
        );
      } on Object catch (_) {
        _linked.remove(entry.key);
      }
    }
  }

  @override
  void send(String kind, String text) {
    final line = utf8.encode('${jsonEncode({'kind': kind, 'text': text})}\n');
    for (final send in List<SendStream>.from(_sends)) {
      unawaited(send.writeAll(line));
    }
  }

  @override
  Future<void> close() async {
    _closed = true;
    final endpoint = _endpoint;
    _endpoint = null;
    try {
      await endpoint?.close();
    } on Object catch (_) {}
  }
}

IrohSeat openIroh() => NativeIrohSeat();
