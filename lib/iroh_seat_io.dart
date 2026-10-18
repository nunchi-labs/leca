import 'iroh_hub_io.dart';
import 'iroh_seat.dart' show IrohSeat;

/// Direct iroh link for a room. The phone holds the same endpoint.
class NativeIrohSeat extends IrohSeat {
  var _held = false;
  void Function()? _stopListen;

  @override
  Future<void> start({
    required void Function(String endpoint, String addr) publish,
    void Function(String from, String kind, String text)? onDirect,
    void Function(String from, String frame)? onFrame,
    List<int>? secret,
  }) async {
    final hub = IrohHub.instance
      ..onTalk = onDirect
      ..onTalkFrame = onFrame;
    try {
      await hub.acquire(secret: secret);
      _stopListen = hub.listen(publish);
      _held = true;
    } on Object catch (_) {}
  }

  @override
  void notePeers(Object? peers) {
    IrohHub.instance.noteTalkPeers(peers);
  }

  @override
  void send(String kind, String text) {
    IrohHub.instance.sendTalk(kind, text);
  }

  @override
  void sendFrame(String frame, {String? except}) {
    IrohHub.instance.sendTalkFrame(frame, except: except);
  }

  @override
  Future<void> close() async {
    if (!_held) return;
    _held = false;
    _stopListen?.call();
    _stopListen = null;
    final hub = IrohHub.instance
      ..onTalk = null
      ..onTalkFrame = null;
    await hub.release();
  }
}

IrohSeat openIroh() => NativeIrohSeat();
