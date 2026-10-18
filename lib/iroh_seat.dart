/// Web and tests keep this empty. iPhone, Mac, and Windows fill it with iroh.
class IrohSeat {
  Future<void> start({
    required void Function(String endpoint, String addr) publish,
    void Function(String from, String kind, String text)? onDirect,
    void Function(String from, String frame)? onFrame,
    List<int>? secret,
  }) async {}

  void notePeers(Object? peers) {}

  void send(String kind, String text) {}

  /// A swarm frame for every iroh neighbor.
  void sendFrame(String frame, {String? except}) {}

  Future<void> close() async {}
}

IrohSeat openIroh() => IrohSeat();
