import 'dart:io';
import 'dart:typed_data';

import 'iroh_hub_io.dart';
import 'phone.dart';

/// The device link. Tests stay on the in-process switch.
PhoneLink openPhoneLink() {
  if (Platform.environment['FLUTTER_TEST'] == 'true') {
    return MemoryPhoneLink(PartyLine.shared, endpoint: '', addr: '');
  }
  return IrohPhoneLink();
}

class IrohPhoneLink implements PhoneLink {
  var _held = false;
  var _dataPath = false;
  void Function()? _stopListen;

  void _onLine(String from, String line) {
    final signal = phoneSignal(from, line);
    if (signal == null) return;
    _signal?.call(signal);
  }

  void Function(PhoneSignal signal)? _signal;

  @override
  bool get dataPath => _dataPath;

  @override
  Future<void> start({
    List<int>? secret,
    required void Function(String endpoint, String addr) onReady,
    required void Function(PhoneSignal signal) onSignal,
    required void Function(String from, Uint8List packet) onAudio,
  }) async {
    _signal = onSignal;
    final hub = IrohHub.instance
      ..onPhoneLine = _onLine
      ..onPhoneAudio = onAudio;
    try {
      await hub.acquire(secret: secret);
      _stopListen = hub.listen(onReady);
      _held = true;
      _dataPath = true;
    } on Object catch (_) {
      _dataPath = false;
    }
  }

  @override
  Future<void> stop() async {
    _stopListen?.call();
    _stopListen = null;
    _signal = null;
    final hub = IrohHub.instance
      ..onPhoneLine = null
      ..onPhoneAudio = null;
    _dataPath = false;
    if (!_held) return;
    _held = false;
    await hub.release();
  }

  @override
  Future<void> invite({
    required String endpoint,
    required String addr,
    required String call,
    required String name,
    required String ourAddr,
  }) async {
    if (!_dataPath) throw const PhoneUnreachable();
    final hub = IrohHub.instance;
    try {
      await hub.connectPhone(endpoint, addr);
    } on Object catch (_) {
      hub.dropPhone(endpoint);
      throw const PhoneUnreachable();
    }
    hub.sendPhone(
      endpoint,
      phoneLine(op: 'invite', call: call, name: name, addr: ourAddr),
    );
  }

  @override
  void reply({
    required String endpoint,
    required String op,
    required String call,
  }) {
    IrohHub.instance.sendPhone(endpoint, phoneLine(op: op, call: call));
  }

  @override
  void audio({required String endpoint, required Uint8List packet}) {
    IrohHub.instance.sendPhoneAudio(endpoint, packet);
  }

  @override
  void drop(String endpoint) {
    IrohHub.instance.dropPhone(endpoint);
  }
}
