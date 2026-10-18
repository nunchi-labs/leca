import 'dart:typed_data';

import 'phone.dart';

/// Web has no iroh link. The number can be shown; the call runs in the app.
PhoneLink openPhoneLink() => LocalPhoneLink();

class LocalPhoneLink implements PhoneLink {
  @override
  bool get dataPath => false;

  @override
  Future<void> start({
    List<int>? secret,
    required void Function(String endpoint, String addr) onReady,
    required void Function(PhoneSignal signal) onSignal,
    required void Function(String from, Uint8List packet) onAudio,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> invite({
    required String endpoint,
    required String addr,
    required String call,
    required String name,
    required String ourAddr,
  }) async {
    throw const PhoneUnreachable();
  }

  @override
  void reply({
    required String endpoint,
    required String op,
    required String call,
  }) {}

  @override
  void audio({required String endpoint, required Uint8List packet}) {}

  @override
  void drop(String endpoint) {}
}
