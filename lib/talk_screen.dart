import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'auth.dart';
import 'iroh_seat.dart' if (dart.library.io) 'iroh_seat_io.dart';
import 'l10n/app_localizations.dart';
import 'market.dart';
import 'negotiate.dart';
import 'phone.dart';
import 'records.dart';
import 'state.dart';
import 'swarm.dart';
import 'talk.dart';
import 'tip.dart';

/// One session. Words and prices ride the iroh swarm.
///
/// Web joins on the room relay. iPhone, Mac, and Windows also dial each
/// other, and a frame is forwarded onto whichever link it did not arrive on.
/// With a [fareKey] the price sits beside the chat. [onCheckout] pays the
/// price both sides allowed.
class TalkScreen extends StatefulWidget {
  const TalkScreen({
    super.key,
    required this.room,
    required this.title,
    this.header,
    this.fareKey,
    this.appUsd = 0,
    this.onCheckout,
    this.onMarket,
    this.onSignIn,
    this.onAccount,
  });

  final String room;
  final String title;
  final Widget? header;
  final String? fareKey;
  final double appUsd;
  final VoidCallback? onCheckout;
  final VoidCallback? onMarket;
  final VoidCallback? onSignIn;
  final VoidCallback? onAccount;

  @override
  State<TalkScreen> createState() => _TalkScreenState();
}

class _TalkScreenState extends State<TalkScreen> {
  final _text = TextEditingController();
  final _seat = openIroh();
  final _shown = <String>{};
  TalkSwarm? _swarm;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  bool _live = false;
  bool _voice = false;
  bool _video = false;
  List<String> _names = [];
  List<ChatNear> _people = [];
  final Map<String, String> _peerNames = {};
  final Map<String, String> _peerAddr = {};

  TalkSwarm _mesh(LecaState state) {
    final existing = _swarm;
    if (existing != null) return existing;
    final created =
        TalkSwarm(
            self: state.who.isEmpty ? 'local' : state.who,
            topic: widget.room,
          )
          ..name = state.session?.displayName ?? 'Guest'
          ..who = state.who;
    _swarm = created;
    return created;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel() ?? Future<void>.value());
    unawaited(_channel?.sink.close() ?? Future<void>.value());
    unawaited(_seat.close());
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
    } on Object catch (_) {
      return;
    }
    if (!mounted) return;
    final state = LecaScope.of(context);
    final mesh = _mesh(state)
      ..link(meshLink, _seat.sendFrame)
      ..link(relayLink, (frame) {
        channel.sink.add(jsonEncode({'type': 'swarm', 'frame': frame}));
      });
    setState(() => _live = true);
    channel.sink.add(jsonEncode(_joinBody(state, name, session?.token)));
    channel.sink.add(jsonEncode({'type': 'swarm', 'frame': mesh.hello()}));
    List<int>? secret;
    try {
      secret = (await state.ensureDeviceKey()).seed;
    } on Object catch (_) {}
    if (!mounted) return;
    await _seat.start(
      secret: secret,
      onFrame: (_, frame) {
        if (!mounted) return;
        _onSwarm(LecaScope.of(context), frame, meshLink);
      },
      publish: (endpoint, addr) {
        channel.sink.add(
          jsonEncode({'type': 'addr', 'endpoint': endpoint, 'addr': addr}),
        );
      },
    );
  }

  void _onSwarm(LecaState state, String frame, String link) {
    final effect = _mesh(state).receive(link, frame);
    final message = effect.deliver;
    if (message != null) _show(state, message);
    if (effect.dial.isEmpty) return;
    _seat.notePeers([
      for (final peer in effect.dial) {'endpoint': peer.id, 'addr': peer.addr},
    ]);
  }

  void _show(LecaState state, SwarmMessage message) {
    if (message.id.isNotEmpty && !_shown.add(message.id)) return;
    final who = message.who.isNotEmpty ? message.who : message.from;
    if (!_admits(state, who)) return;
    final thread = state.thread(widget.room);
    if (message.id.isEmpty &&
        thread.isNotEmpty &&
        thread.last.kind == message.kind &&
        thread.last.text == message.text) {
      return;
    }
    if (message.kind == 'price') {
      _applyOffer(state, message.text, message.who, message.name);
    }
    state.sendMessage(
      placeId: widget.room,
      text: message.text,
      asBusiness: message.who.isEmpty && message.name == 'Shop',
      kind: message.kind,
      name: message.name,
      who: message.who,
    );
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
        _takePeople(decoded['people']);
        setState(() => _names = _strings(decoded['names']));
      case 'entry':
        final swarmId = '${decoded['id'] ?? ''}';
        if (swarmId.isEmpty || _shown.add(swarmId)) {
          final line = TalkLine.fromJson(decoded['entry']);
          if (line != null && _admits(state, line.who)) {
            state.appendTalk(line);
            _applyPrice(state, line);
          }
        }
        _rememberPeers(decoded['peers']);
      case 'swarm':
        final frame = '${decoded['frame'] ?? ''}';
        if (frame.isNotEmpty) _onSwarm(state, frame, relayLink);
      case 'presence':
        _rememberPeers(decoded['peers']);
        _takePeople(decoded['people']);
        setState(() => _names = _strings(decoded['names']));
    }
  }

  Map<String, Object?> _joinBody(LecaState state, String name, String? token) {
    final fix = state.origin;
    return {
      'type': 'join',
      'room': widget.room,
      'name': name,
      if (token != null && token.isNotEmpty) 'token': token,
      if (token == null || token.isEmpty) 'guest': state.guestId,
      'lat': fix.latitude,
      'lng': fix.longitude,
      'radius': state.chatRadiusKm,
      'face': state.chatFace,
    };
  }

  void _publishPlace(LecaState state) {
    if (!_live) return;
    final fix = state.origin;
    _channel?.sink.add(
      jsonEncode({
        'type': 'place',
        'lat': fix.latitude,
        'lng': fix.longitude,
        'radius': state.chatRadiusKm,
        'face': state.chatFace,
      }),
    );
  }

  void _takePeople(Object? raw) {
    if (raw is! List) return;
    final next = <ChatNear>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final km = item['km'];
      if (km is! num) continue;
      next.add(
        ChatNear(
          who: '${item['who'] ?? ''}',
          name: '${item['name'] ?? ''}',
          km: km.round(),
        ),
      );
    }
    setState(() => _people = next);
  }

  bool _admits(LecaState state, String who) {
    if (widget.room != frontRoom) return true;
    if (who.isEmpty || who == state.who) return true;
    if (_people.isEmpty) return true;
    return _people.any((person) => person.who == who);
  }

  void _rememberPeers(Object? peers) {
    _seat.notePeers(peers);
    final mesh = _swarm;
    if (mesh != null && peers is List) {
      final learned = mesh.introduce([
        for (final peer in peers)
          if (peer is Map)
            SwarmPeer('${peer['endpoint'] ?? ''}', '${peer['addr'] ?? ''}'),
      ]);
      if (learned.isNotEmpty && _live) {
        _channel?.sink.add(
          jsonEncode({'type': 'swarm', 'frame': mesh.hello()}),
        );
      }
    }
    if (peers is! List) return;
    for (final peer in peers) {
      if (peer is! Map) continue;
      final endpoint = '${peer['endpoint'] ?? ''}';
      final name = '${peer['name'] ?? ''}'.trim();
      final addr = '${peer['addr'] ?? ''}';
      if (endpoint.isEmpty) continue;
      if (name.isNotEmpty) _peerNames[endpoint] = name;
      if (addr.isNotEmpty) _peerAddr[endpoint] = addr;
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
    _applyOffer(state, line.text, line.who, line.name);
  }

  void _applyOffer(LecaState state, String text, String who, String name) {
    final key = widget.fareKey;
    if (key == null) return;
    if (who.isNotEmpty && who == state.who) return;
    if (who.isEmpty && name == (state.session?.displayName ?? '')) return;
    final offer = PriceLine.parse(text);
    if (offer == null) return;
    switch (offer.verb) {
      case 'ask':
        final pending = state.askFor(key)?.pending;
        if (pending != null &&
            pending.side == offer.side &&
            (pending.usd - offer.usd).abs() < 0.009) {
          return;
        }
        state.proposeFare(key, widget.appUsd, offer.usd, proposer: offer.side);
      case 'allow':
        final pending = state.askFor(key)?.pending;
        if (pending != null && (pending.usd - offer.usd).abs() < 0.009) {
          state.allowFare(key);
        }
      case 'end':
        final ask = state.askFor(key);
        if (ask == null || ask.ended) return;
        state.endFare(key);
    }
  }

  void _callPeer() {
    String? endpoint;
    for (final entry in _peerAddr.entries) {
      endpoint = entry.key;
      break;
    }
    if (endpoint == null) return;
    final handset = PhoneScope.of(context);
    final state = LecaScope.of(context);
    unawaited(
      handset.dial(
        PhoneAddress(
          endpoint: endpoint,
          addr: _peerAddr[endpoint] ?? '',
          name: _peerNames[endpoint] ?? '',
        ),
        myName: state.session?.displayName ?? '',
      ),
    );
  }

  void _price(LecaState state, String verb, double usd, String side) {
    _emit(
      state,
      kind: 'price',
      text: PriceLine(verb, usd, side).encode(),
      asBusiness: false,
    );
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
    _emit(
      state,
      kind: kind,
      text: kind == 'text' ? body.trim() : body,
      asBusiness: asBusiness,
    );
    if (kind == 'text') _text.clear();
  }

  void _emit(
    LecaState state, {
    required String kind,
    required String text,
    required bool asBusiness,
  }) {
    if (widget.room == frontRoom && state.chatFace == chatFaceHide) return;
    final mesh = _mesh(state);
    final message = mesh.broadcast(
      kind: kind,
      text: text,
      name: _publicName(state, asBusiness),
      who: asBusiness ? '' : state.who,
    );
    if (message == null) return;
    if (_live) {
      _channel?.sink.add(
        jsonEncode({
          'type': 'say',
          'kind': message.kind,
          'text': message.text,
          'id': message.id,
        }),
      );
      return;
    }
    if (mesh.hasLinks) {
      _show(state, message);
      return;
    }
    state.sendMessage(
      placeId: widget.room,
      text: message.text,
      asBusiness: asBusiness,
      kind: message.kind,
      name: message.name,
      who: message.who,
    );
  }

  String _publicName(LecaState state, bool asBusiness) {
    if (asBusiness) return 'Shop';
    if (widget.room == frontRoom && state.chatFace != chatFaceName) return '';
    return state.session?.displayName ?? 'Guest';
  }

  bool _mine(LecaState state, ChatMessage message) {
    if (message.asBusiness) return false;
    if (message.who.isNotEmpty && state.who.isNotEmpty) {
      return message.who == state.who;
    }
    final name = state.session?.displayName ?? '';
    return name.isNotEmpty && message.name == name;
  }

  String _away(AppLocalizations l10n, int km) {
    if (km <= 0) return l10n.chatAwayNear;
    return l10n.chatAway(km);
  }

  String _speaker(AppLocalizations l10n, LecaState state, ChatMessage message) {
    if (widget.room != frontRoom) return message.name;
    if (_mine(state, message)) {
      final mine = state.session?.displayName ?? '';
      return mine.isEmpty ? message.name : mine;
    }
    for (final person in _people) {
      if (person.who != message.who) continue;
      if (person.name.isNotEmpty) return person.name;
      return _away(l10n, person.km);
    }
    return message.name;
  }

  String _bubble(AppLocalizations l10n, LecaState state, ChatMessage message) {
    final name = _speaker(l10n, state, message);
    switch (message.kind) {
      case 'text':
        return '$name: ${message.text}';
      case 'price':
        final offer = PriceLine.parse(message.text);
        if (offer == null) return '$name: ${message.text}';
        final who = offer.side == 'driver' ? l10n.whoDriver : l10n.whoCustomer;
        final money = moneyUsd(offer.usd);
        return switch (offer.verb) {
          'allow' => '$name: ${l10n.priceAllowed(money)}',
          'end' => '$name: ${l10n.endFare}',
          _ => '$name: ${l10n.proposedBy(who, money)}',
        };
      default:
        return '$name: ${message.kind}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = LecaScope.of(context);
    final thread = [
      for (final message in state.thread(widget.room))
        if (_admits(state, message.who)) message,
    ];
    final owned = state.owns(widget.room);
    final front = widget.room == frontRoom;
    ChatMessage? call;
    for (final message in thread.reversed) {
      if (message.kind != 'voice' && message.kind != 'video') continue;
      if (message.text == 'open') call = message;
      break;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: widget.onMarket == null
            ? null
            : [
                IconButton(
                  key: const Key('open_market'),
                  tooltip: l10n.searchHint,
                  onPressed: widget.onMarket,
                  icon: const Icon(Icons.storefront_outlined),
                ),
                if (state.session == null)
                  IconButton(
                    key: const Key('open_sign_in'),
                    tooltip: l10n.accountTitle,
                    onPressed: widget.onSignIn,
                    icon: const Icon(Icons.login),
                  )
                else
                  IconButton(
                    key: const Key('chat_account'),
                    tooltip: l10n.accountTitle,
                    onPressed: widget.onAccount,
                    icon: Icon(
                      state.driving
                          ? Icons.directions_car
                          : Icons.person_outline,
                    ),
                  ),
              ],
      ),
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
                        if (state.acceptsTip) ...[
                          const SizedBox(height: 8),
                          const TipChoices(),
                        ],
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
                        if (widget.onCheckout != null &&
                            state.askFor(widget.fareKey!)?.agreedUsd != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: FilledButton(
                              key: const Key('front_pay'),
                              onPressed: widget.onCheckout,
                              child: Text(l10n.checkout),
                            ),
                          ),
                        const SizedBox(height: 8),
                      ],
                      Text(l10n.talkIroh),
                      if (front) ...[
                        const SizedBox(height: 8),
                        Text(l10n.chatRadius),
                        Row(
                          children: [
                            Text(
                              state.chatRadiusKm >= LecaState.countryWide
                                  ? l10n.radiusCountry
                                  : l10n.radiusLabel(
                                      state.chatRadiusKm.round(),
                                    ),
                              key: const Key('chat_radius'),
                            ),
                            Expanded(
                              child: Slider(
                                value: state.chatRadiusKm,
                                min: 1,
                                max: LecaState.countryWide,
                                divisions: LecaState.countryWide.toInt() - 1,
                                label:
                                    state.chatRadiusKm >= LecaState.countryWide
                                    ? l10n.radiusCountry
                                    : l10n.radiusLabel(
                                        state.chatRadiusKm.round(),
                                      ),
                                onChanged: (km) {
                                  state.setChatRadius(km);
                                  _publishPlace(state);
                                },
                              ),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 6,
                          children: [
                            ChoiceChip(
                              key: const Key('chat_face_anon'),
                              label: Text(l10n.chatFaceAnon),
                              selected: state.chatFace == chatFaceAnon,
                              onSelected: (_) {
                                state.setChatFace(chatFaceAnon);
                                _publishPlace(state);
                              },
                            ),
                            ChoiceChip(
                              key: const Key('chat_face_name'),
                              label: Text(l10n.chatFaceName),
                              selected: state.chatFace == chatFaceName,
                              onSelected: (_) {
                                state.setChatFace(chatFaceName);
                                _publishPlace(state);
                              },
                            ),
                            ChoiceChip(
                              key: const Key('chat_face_hide'),
                              label: Text(l10n.chatFaceHide),
                              selected: state.chatFace == chatFaceHide,
                              onSelected: (_) {
                                state.setChatFace(chatFaceHide);
                                _publishPlace(state);
                              },
                            ),
                          ],
                        ),
                        if (state.chatFace == chatFaceHide)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              l10n.chatHiddenBody,
                              key: const Key('chat_hidden'),
                            ),
                          ),
                      ],
                      if (state.talkOk(widget.room) && thread.isNotEmpty)
                        Text(l10n.talkProof, key: const Key('talk_proof')),
                      if (front && _people.isNotEmpty)
                        Text(
                          _people
                              .map(
                                (person) => person.name.isEmpty
                                    ? _away(l10n, person.km)
                                    : person.name,
                              )
                              .join(' · '),
                          key: const Key('chat_people'),
                        )
                      else if (_names.isNotEmpty)
                        Text(_names.join(' · ')),
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
                              alignment: _mine(state, message)
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Card(
                                color: _mine(state, message)
                                    ? const Color(0xFFB42318)
                                    : Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    _bubble(l10n, state, message),
                                    style: TextStyle(
                                      color: _mine(state, message)
                                          ? Colors.white
                                          : const Color(0xFF1A1410),
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
                      onPressed: front && state.chatFace == chatFaceHide
                          ? null
                          : () => _send(state, asBusiness: false),
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
                      key: const Key('talk_dial'),
                      onPressed: _peerAddr.isEmpty ? null : _callPeer,
                      child: Text(l10n.talkCall),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      key: const Key('talk_voice'),
                      onPressed: front && state.chatFace == chatFaceHide
                          ? null
                          : () =>
                                _send(state, asBusiness: false, kind: 'voice'),
                      child: Text(l10n.talkVoice),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      key: const Key('talk_video'),
                      onPressed: front && state.chatFace == chatFaceHide
                          ? null
                          : () =>
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
