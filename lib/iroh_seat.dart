/// Web and tests use the Leca room. Phones and computers add iroh beside it.
class IrohSeat {
  Future<void> start({
    required void Function(String endpoint, String addr) publish,
    void Function(String from, String kind, String text)? onDirect,
    List<int>? secret,
  }) async {}

  void notePeers(Object? peers) {}

  void send(String kind, String text) {}

  Future<void> close() async {}
}

IrohSeat openIroh() => IrohSeat();
