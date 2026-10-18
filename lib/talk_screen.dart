import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'auth.dart';
import 'iroh_seat.dart' if (dart.library.io) 'iroh_seat_io.dart';
import 'l10n/app_localizations.dart';
import 'market.dart';
import 'negotiate.dart';
import 'records.dart';
import 'state.dart';
import 'talk.dart';

/// Chat for everyone on a trip. Addresses stay on the connection.
///
/// With a [fareKey] the price sits beside the chat. A driver can ask for
/// more, a customer can offer less, and the other side allows it. Each ask
/// and allow is a line in the same proof chain as the words.
class TalkScreen extends StatefulWidget {
  const TalkScreen({
    super.key,
    required this.room,
    required this.title,
    this.header,
    this.fareKey,
    this.appUsd = 0,
  });

  final String room;
  final String title;
  final Widget? header;
  final String? fareKey;
  final double appUsd;

  @override
  State<TalkScreen> createState() => _TalkScreenState();
}

class _TalkScreenState extends State<TalkScreen> {
  final _text = TextEditingController();
  final _seat = openIroh();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  bool _live = false;
  bool _voice = false;
  bool _video = false;
  List<String> _names = [];
  final Map<String, String> _peerNames = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _channel?.sink.close();
    _seat.close();
    _text.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (!mounted || !AuthConfig.apiLive) return;
    final base = Uri.parse(AuthConfig.apiBase);
    final uri = base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '/v1/room',
    );
    final session = LecaScope.of(context).session;
    final name = session?.displayName ?? 'Guest';
    final channel = WebSocketChannel.connect(uri);
    _channel = channel;
    _sub = channel.stream.listen(_onData, onError: (_) {}, onDone: () {});
    try {
      await channel.ready;
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() => _live = true);
    channel.sink.add(
      jsonEncode({
        'type': 'join',
        'room': widget.room,
        'name': name,
        'token': ?session?.token,
      }),
    );
    List<int>? secret;
    try {
      secret = (await LecaScope.of(context).ensureDeviceKey()).seed;
    } catch (_) {}
    if (!mounted) return;
    await _seat.start(
      secret: secret,
      onDirect: _onDirect,
      publish: (endpoint, addr) {
        channel.sink.add(
          jsonEncode({'type': 'addr', 'endpoint': endpoint, 'addr': addr}),
        );
      },
    );
  }

  void _onDirect(String from, String kind, String text) {
    if (!mounted || text.isEmpty) return;
    final state = LecaScope.of(context);
    final thread = state.thread(widget.room);
    if (thread.isNotEmpty &&
        thread.last.kind == kind &&
        thread.last.text == text) {
      return;
    }
    final known = _peerNames[from] ?? '';
    state.sendMessage(
      placeId: widget.room,
      text: text,
      asBusiness: false,
      kind: kind,
      name: known.isEmpty ? from : known,
    );
    if (kind == 'price') {
      _applyPrice(
        state,
        TalkLine(
          seq: 0,
          room: widget.room,
          kind: kind,
          name: known.isEmpty ? from : known,
          who: '',
          at: '',
          text: text,
          prev: '',
          proof: '',
        ),
      );
    }
  }

  void _onData(Object? raw) {
    final decoded = jsonDecode('$raw');
    if (decoded is! Map || !mounted) return;
    final state = LecaScope.of(context);
    switch (decoded['type']) {
      case 'welcome':
        final log = decoded['log'];
        if (log is List) {
          for (final item in log) {
            final line = TalkLine.fromJson(item);
            if (line == null) continue;
            final fresh = !state
                .thread(widget.room)
                .any((m) => m.seq == line.seq && m.proof == line.proof);
            state.appendTalk(line);
            if (fresh) _applyPrice(state, line);
          }
        }
        _rememberPeers(decoded['peers']);
        setState(() => _names = _strings(decoded['names']));
      case 'entry':
        final line = TalkLine.fromJson(decoded['entry']);
        if (line != null) {
          state.appendTalk(line);
          _applyPrice(state, line);
        }
        _rememberPeers(decoded['peers']);
      case 'presence':
        _rememberPeers(decoded['peers']);
        setState(() => _names = _strings(decoded['names']));
    }
  }

  void _rememberPeers(Object? peers) {
    _seat.notePeers(peers);
    if (peers is! List) return;
    for (final peer in peers) {
      if (peer is! Map) continue;
      final endpoint = '${peer['endpoint'] ?? ''}';
      final name = '${peer['name'] ?? ''}'.trim();
      if (endpoint.isEmpty || name.isEmpty) continue;
      _peerNames[endpoint] = name;
    }
  }

  List<String> _strings(Object? raw) {
    if (raw is! List) return [];
    return [for (final item in raw) '$item'];
  }

  /// A price line from another account moves the bargain on this device
  /// too. Lines are matched by account handle, never by display name.
  void _applyPrice(LecaState state, TalkLine line) {
    final key = widget.fareKey;
    if (key == null || line.kind != 'price') return;
    if (line.who.isNotEmpty && line.who == state.who) return;
    if (line.who.isEmpty && line.name == (state.session?.displayName ?? '')) {
      return;
    }
    final offer = PriceLine.parse(line.text);
    if (offer == null) return;
    switch (offer.verb) {
      case 'ask':
        state.proposeFare(key, widget.appUsd, offer.usd, proposer: offer.side);
      case 'allow':
        final pending = state.askFor(key)?.pending;
        if (pending != null && (pending.usd - offer.usd).abs() < 0.009) {
          state.allowFare(key);
        }
      case 'end':
        state.endFare(key);
    }
  }

  void _price(LecaState state, String verb, double usd, String side) {
    final text = PriceLine(verb, usd, side).encode();
    if (_live) {
      _channel?.sink.add(
        jsonEncode({'type': 'say', 'kind': 'price', 'text': text}),
      );
      _seat.send('price', text);
    } else {
      state.sendMessage(
        placeId: widget.room,
        text: text,
        asBusiness: false,
        kind: 'price',
      );
    }
  }

  void _send(
    LecaState state, {
    required bool asBusiness,
    String kind = 'text',
  }) {
    var body = _text.text;
    if (kind == 'voice') {
      _voice = !_voice;
      body = _voice ? 'open' : 'close';
      setState(() {});
    } else if (kind == 'video') {
      _video = !_video;
      body = _video ? 'open' : 'close';
      setState(() {});
    }
    if (kind == 'text' && body.trim().isEmpty) return;
    if (_live) {
      _channel?.sink.add(
        jsonEncode({'type': 'say', 'kind': kind, 'text': body.trim()}),
      );
      _seat.send(kind, body.trim());
    } else {
      state.sendMessage(
        placeId: widget.room,
        text: body,
        asBusiness: asBusiness,
        kind: kind,
      );
    }
    if (kind == 'text') _text.clear();
  }

  String _bubble(AppLocalizations l10n, ChatMessage message) {
    switch (message.kind) {
      case 'text':
        return '${message.name}: ${message.text}';
      case 'price':
        final offer = PriceLine.parse(message.text);
        if (offer == null) return '${message.name}: ${message.text}';
        final who = offer.side == 'driver' ? l10n.whoDriver : l10n.whoCustomer;
        final money = moneyUsd(offer.usd);
        return switch (offer.verb) {
          'allow' => '${message.name}: ${l10n.priceAllowed(money)}',
          'end' => '${message.name}: ${l10n.endFare}',
          _ => '${message.name}: ${l10n.proposedBy(who, money)}',
        };
      default:
        return '${message.name}: ${message.kind}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = LecaScope.of(context);
    final thread = state.thread(widget.room);
    final owned = state.owns(widget.room);
    ChatMessage? call;
    for (final message in thread.reversed) {
      if (message.kind != 'voice' && message.kind != 'video') continue;
      if (message.text == 'open') call = message;
      break;
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.header != null) widget.header!,
                      if (widget.fareKey != null) ...[
                        Text(
                          '${fareLabel(l10n, state.askFor(widget.fareKey!))}  ${moneyUsd(state.payable(widget.fareKey!, widget.appUsd))}',
                          key: const Key('talk_price'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(l10n.priceInChat),
                        FareNegotiate(
                          fareKey: widget.fareKey!,
                          appUsd: widget.appUsd,
                          onProposed: (usd, side) =>
                              _price(state, 'ask', usd, side),
                          onAllowed: (usd) =>
                              _price(state, 'allow', usd, state.fareSide),
                          onEnded: () =>
                              _price(state, 'end', 0, state.fareSide),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(l10n.talkIroh),
                      if (state.talkOk(widget.room) && thread.isNotEmpty)
                        Text(l10n.talkProof, key: const Key('talk_proof')),
                      if (_names.isNotEmpty) Text(_names.join(' · ')),
                      if (call != null)
                        Text(
                          l10n.talkInCall(call.name, call.kind),
                          key: const Key('talk_call'),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: thread.isEmpty
                    ? Center(child: Text(l10n.emptyChat))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (final message in thread)
                            Align(
                              alignment: message.asBusiness
                                  ? Alignment.centerLeft
                                  : Alignment.centerRight,
                              child: Card(
                                color: message.asBusiness
                                    ? Colors.white
                                    : const Color(0xFFB42318),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    _bubble(l10n, message),
                                    style: TextStyle(
                                      color: message.asBusiness
                                          ? const Color(0xFF1A1410)
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        decoration: InputDecoration(
                          hintText: l10n.chatHint,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      key: const Key('send_chat'),
                      onPressed: () => _send(state, asBusiness: false),
                      child: Text(l10n.sendMessage),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    OutlinedButton(
                      key: const Key('talk_voice'),
                      onPressed: () =>
                          _send(state, asBusiness: false, kind: 'voice'),
                      child: Text(l10n.talkVoice),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      key: const Key('talk_video'),
                      onPressed: () =>
                          _send(state, asBusiness: false, kind: 'video'),
                      child: Text(l10n.talkVideo),
                    ),
                    if (owned) ...[
                      const Spacer(),
                      OutlinedButton(
                        key: const Key('reply_chat'),
                        onPressed: () => _send(state, asBusiness: true),
                        child: Text(l10n.replyAsBusiness),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
