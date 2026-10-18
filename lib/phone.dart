import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// A data call. The number is an iroh endpoint, and the voice is G.711
/// audio on that link. A carrier circuit is not part of the call.
const phoneFrame = 160;

const _z32 = 'ybndrfg8ejkmcpqxot1uwisza345h769';

/// z-base-32, the alphabet iroh uses for an endpoint id.
final phoneEndpoint = RegExp('^[$z32Chars]{52}\$');

const z32Chars = _z32;

String z32Encode(List<int> bytes) {
  if (bytes.isEmpty) return '';
  final out = StringBuffer();
  var buffer = 0;
  var bits = 0;
  for (final byte in bytes) {
    buffer = (buffer << 8) | (byte & 0xFF);
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      out.write(_z32[(buffer >> bits) & 31]);
    }
  }
  if (bits > 0) out.write(_z32[(buffer << (5 - bits)) & 31]);
  return out.toString();
}

/// G.711 μ-law. One byte is one sample at 8 kHz, the codec a handset uses,
/// carried here as data.
int ulawEncode(int sample) {
  const bias = 0x84;
  const clip = 32635;
  var pcm = sample;
  var sign = 0;
  if (pcm < 0) {
    sign = 0x80;
    pcm = -pcm;
    if (pcm < 0) pcm = clip;
  }
  if (pcm > clip) pcm = clip;
  pcm += bias;
  var exponent = 7;
  var mask = 0x4000;
  while (exponent > 0 && (pcm & mask) == 0) {
    exponent -= 1;
    mask >>= 1;
  }
  final mantissa = (pcm >> (exponent + 3)) & 0x0F;
  return (~(sign | (exponent << 4) | mantissa)) & 0xFF;
}

int ulawDecode(int ulaw) {
  const bias = 0x84;
  final byte = (~ulaw) & 0xFF;
  final sign = byte & 0x80;
  final exponent = (byte >> 4) & 0x07;
  final mantissa = byte & 0x0F;
  var sample = ((mantissa << 3) + bias) << exponent;
  sample -= bias;
  if (sign != 0) sample = -sample;
  return sample;
}

Uint8List pcm16ToUlaw(Uint8List pcm) {
  final samples = pcm.length ~/ 2;
  final out = Uint8List(samples);
  final data = ByteData.sublistView(pcm);
  for (var i = 0; i < samples; i++) {
    out[i] = ulawEncode(data.getInt16(i * 2, Endian.little));
  }
  return out;
}

Uint8List ulawToPcm16(Uint8List ulaw) {
  final out = Uint8List(ulaw.length * 2);
  final data = ByteData.sublistView(out);
  for (var i = 0; i < ulaw.length; i++) {
    data.setInt16(i * 2, ulawDecode(ulaw[i]), Endian.little);
  }
  return out;
}

/// One 20 ms voice frame on the wire: magic, sequence, 160 μ-law bytes.
Uint8List packAudio(int seq, Uint8List ulaw) {
  final out = Uint8List(3 + ulaw.length);
  out[0] = 0xA1;
  out[1] = (seq >> 8) & 0xFF;
  out[2] = seq & 0xFF;
  out.setRange(3, out.length, ulaw);
  return out;
}

(int, Uint8List)? unpackAudio(Uint8List packet) {
  if (packet.length != 3 + phoneFrame || packet[0] != 0xA1) return null;
  final seq = (packet[1] << 8) | packet[2];
  return (seq, Uint8List.sublistView(packet, 3));
}

String clipPhoneName(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[\r\n]'), ' ').trim();
  if (cleaned.length <= 24) return cleaned;
  return cleaned.substring(0, 24);
}

String phoneShort(String endpoint) {
  if (endpoint.length <= 11) return endpoint;
  return '${endpoint.substring(0, 4)}…${endpoint.substring(endpoint.length - 4)}';
}

String phoneClock(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  final minutes = (safe ~/ 60).toString().padLeft(2, '0');
  final rest = (safe % 60).toString().padLeft(2, '0');
  return '$minutes:$rest';
}

String phoneCard({required String endpoint, required String addr}) {
  if (endpoint.isEmpty) return '';
  if (addr.isEmpty) return 'leca1 $endpoint';
  return 'leca1 $endpoint $addr';
}

/// Who to ring. [endpoint] is the iroh id. [addr] is the postcard address
/// the link dials. A name is what the handset shows.
class PhoneAddress {
  const PhoneAddress({
    required this.endpoint,
    required this.addr,
    this.name = '',
  });

  final String endpoint;
  final String addr;
  final String name;

  static PhoneAddress? parse(String raw) {
    final parts = raw.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return null;
    final start = parts.first == 'leca1' ? 1 : 0;
    if (start >= parts.length) return null;
    final endpoint = parts[start];
    if (!phoneEndpoint.hasMatch(endpoint)) return null;
    final addr = start + 1 < parts.length ? parts[start + 1] : '';
    if (addr.length > 4000 || addr.contains(RegExp(r'\s'))) return null;
    return PhoneAddress(endpoint: endpoint, addr: addr);
  }
}

class PhoneContact {
  const PhoneContact({
    required this.endpoint,
    required this.addr,
    required this.name,
  });

  final String endpoint;
  final String addr;
  final String name;

  Map<String, Object?> toJson() => {
    'endpoint': endpoint,
    'addr': addr,
    'name': name,
  };

  static PhoneContact? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final endpoint = '${raw['endpoint'] ?? ''}';
    if (!phoneEndpoint.hasMatch(endpoint)) return null;
    final addr = '${raw['addr'] ?? ''}';
    if (addr.length > 4000) return null;
    return PhoneContact(
      endpoint: endpoint,
      addr: addr,
      name: clipPhoneName('${raw['name'] ?? ''}'),
    );
  }
}

enum CallWay { incoming, outgoing, missed }

class CallRecord {
  const CallRecord({
    required this.endpoint,
    required this.addr,
    required this.name,
    required this.way,
    required this.seconds,
    required this.at,
  });

  final String endpoint;
  final String addr;
  final String name;
  final CallWay way;
  final int seconds;
  final DateTime at;

  Map<String, Object?> toJson() => {
    'endpoint': endpoint,
    'addr': addr,
    'name': name,
    'way': way.name,
    'seconds': seconds,
    'at': at.toUtc().toIso8601String(),
  };

  static CallRecord? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final endpoint = '${raw['endpoint'] ?? ''}';
    if (!phoneEndpoint.hasMatch(endpoint)) return null;
    final at = DateTime.tryParse('${raw['at'] ?? ''}');
    final seconds = raw['seconds'];
    final way = CallWay.values.where((item) => item.name == raw['way']);
    if (at == null || seconds is! int || seconds < 0 || way.isEmpty) {
      return null;
    }
    final addr = '${raw['addr'] ?? ''}';
    if (addr.length > 4000) return null;
    return CallRecord(
      endpoint: endpoint,
      addr: addr,
      name: clipPhoneName('${raw['name'] ?? ''}'),
      way: way.first,
      seconds: seconds,
      at: at.toUtc(),
    );
  }
}

bool phoneHit(PhoneContact contact, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return false;
  if (contact.endpoint == query.trim()) return true;
  final name = contact.name.toLowerCase();
  return name == q || (q.length >= 2 && name.contains(q));
}

/// A pasted card dials immediately. A name uses saved contacts, then [lookup].
Future<List<PhoneAddress>> resolvePhone({
  required String raw,
  required List<PhoneContact> contacts,
  required Future<List<PhoneAddress>> Function(String query) lookup,
}) async {
  final text = raw.trim();
  if (text.isEmpty) return const [];
  final parsed = PhoneAddress.parse(text);
  if (parsed != null && parsed.addr.isNotEmpty) return [parsed];
  final query = parsed?.endpoint ?? text;
  final local = [
    for (final contact in contacts)
      if (contact.addr.isNotEmpty && phoneHit(contact, query))
        PhoneAddress(
          endpoint: contact.endpoint,
          addr: contact.addr,
          name: contact.name,
        ),
  ];
  if (parsed != null) {
    for (final item in local) {
      if (item.endpoint == parsed.endpoint) return [item];
    }
    return lookup(query);
  }
  if (local.isNotEmpty) return local;
  return lookup(query);
}

/// Rows from `GET /v1/phone/find`.
List<PhoneAddress> phoneMatches(Object? raw) {
  if (raw is! List) return const [];
  final out = <PhoneAddress>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final endpoint = '${item['endpoint'] ?? ''}';
    final addr = '${item['addr'] ?? ''}';
    if (!phoneEndpoint.hasMatch(endpoint) ||
        addr.isEmpty ||
        addr.length > 4000) {
      continue;
    }
    out.add(
      PhoneAddress(
        endpoint: endpoint,
        addr: addr,
        name: clipPhoneName('${item['name'] ?? ''}'),
      ),
    );
  }
  return out;
}

class PhoneSignal {
  const PhoneSignal({
    required this.from,
    required this.op,
    required this.call,
    this.name = '',
    this.addr = '',
  });

  final String from;
  final String op;
  final String call;
  final String name;
  final String addr;
}

const phoneOps = {'invite', 'accept', 'decline', 'hangup', 'busy'};

String phoneLine({
  required String op,
  required String call,
  String name = '',
  String addr = '',
}) {
  return jsonEncode({
    'op': op,
    'call': call,
    if (name.isNotEmpty) 'name': name,
    if (addr.isNotEmpty) 'addr': addr,
  });
}

PhoneSignal? phoneSignal(String from, String line) {
  try {
    final decoded = jsonDecode(line);
    if (decoded is! Map) return null;
    final op = '${decoded['op'] ?? ''}';
    final call = '${decoded['call'] ?? ''}';
    if (!phoneOps.contains(op) || !RegExp(r'^[0-9a-f]{8}$').hasMatch(call)) {
      return null;
    }
    final addr = '${decoded['addr'] ?? ''}'.trim();
    if (addr.length > 4000) return null;
    return PhoneSignal(
      from: from,
      op: op,
      call: call,
      name: clipPhoneName('${decoded['name'] ?? ''}'),
      addr: addr,
    );
  } on Object catch (_) {
    return null;
  }
}

enum CallPhase { idle, dialing, ringing, live }

enum PhoneFault {
  none,
  busy,
  unreachable,
  declined,
  self,
  offline,
  gear,
  timeout,
}

enum Wire { starting, up, absent }

/// The path a call travels. The iroh link is the one a device uses.
abstract class PhoneLink {
  bool get dataPath;

  Future<void> start({
    List<int>? secret,
    required void Function(String endpoint, String addr) onReady,
    required void Function(PhoneSignal signal) onSignal,
    required void Function(String from, Uint8List packet) onAudio,
  });

  Future<void> stop();

  Future<void> invite({
    required String endpoint,
    required String addr,
    required String call,
    required String name,
    required String ourAddr,
  });

  void reply({
    required String endpoint,
    required String op,
    required String call,
  });

  void audio({required String endpoint, required Uint8List packet});

  void drop(String endpoint);
}

/// Microphone and speaker. A test gear records what it was asked to play.
abstract class PhoneGear {
  Future<void> up();

  Future<void> down();

  /// `in` rings, `out` is ringback, empty stops the tone.
  Future<void> ring({required String kind});

  Stream<Uint8List> get mic;

  void hear(Uint8List ulaw);
}

class SilentGear implements PhoneGear {
  final _mic = StreamController<Uint8List>.broadcast();

  @override
  Stream<Uint8List> get mic => _mic.stream;

  @override
  Future<void> up() async {}

  @override
  Future<void> down() async {}

  @override
  Future<void> ring({required String kind}) async {}

  @override
  void hear(Uint8List ulaw) {}

  Future<void> close() async {
    if (!_mic.isClosed) await _mic.close();
  }
}

/// Feeds scripted μ-law frames and keeps what the handset played.
class ScriptGear implements PhoneGear {
  final _mic = StreamController<Uint8List>.broadcast();
  final heard = <Uint8List>[];

  @override
  Stream<Uint8List> get mic => _mic.stream;

  @override
  Future<void> up() async {}

  @override
  Future<void> down() async {}

  @override
  Future<void> ring({required String kind}) async {}

  @override
  void hear(Uint8List ulaw) {
    heard.add(Uint8List.fromList(ulaw));
  }

  void say(Uint8List ulaw) {
    if (!_mic.isClosed) _mic.add(ulaw);
  }

  Future<void> close() async {
    if (!_mic.isClosed) await _mic.close();
  }
}

class PhoneUnreachable implements Exception {
  const PhoneUnreachable();
}

/// In-process switch so two handsets can call without a network.
class PartyLine {
  static final shared = PartyLine();

  final members = <MemoryPhoneLink>[];

  void join(MemoryPhoneLink link) {
    if (!members.contains(link)) members.add(link);
  }

  void leave(MemoryPhoneLink link) {
    members.remove(link);
  }

  MemoryPhoneLink? find(String endpoint) {
    for (final member in members) {
      if (member.endpoint == endpoint) return member;
    }
    return null;
  }
}

class MemoryPhoneLink implements PhoneLink {
  MemoryPhoneLink(this.party, {required this.endpoint, this.addr = 'mem'});

  final PartyLine party;
  final String endpoint;
  final String addr;

  void Function(PhoneSignal signal)? _onSignal;
  void Function(String from, Uint8List packet)? _onAudio;
  var _dataPath = false;

  @override
  bool get dataPath => _dataPath;

  @override
  Future<void> start({
    List<int>? secret,
    required void Function(String endpoint, String addr) onReady,
    required void Function(PhoneSignal signal) onSignal,
    required void Function(String from, Uint8List packet) onAudio,
  }) async {
    _onSignal = onSignal;
    _onAudio = onAudio;
    if (endpoint.isNotEmpty) party.join(this);
    _dataPath = true;
    onReady(endpoint, addr);
  }

  @override
  Future<void> stop() async {
    party.leave(this);
    _onSignal = null;
    _onAudio = null;
    _dataPath = false;
  }

  @override
  Future<void> invite({
    required String endpoint,
    required String addr,
    required String call,
    required String name,
    required String ourAddr,
  }) async {
    final peer = party.find(endpoint);
    if (peer == null) throw const PhoneUnreachable();
    _emit(
      peer,
      PhoneSignal(
        from: this.endpoint,
        op: 'invite',
        call: call,
        name: name,
        addr: ourAddr,
      ),
    );
  }

  @override
  void reply({
    required String endpoint,
    required String op,
    required String call,
  }) {
    final peer = party.find(endpoint);
    if (peer == null) return;
    _emit(peer, PhoneSignal(from: this.endpoint, op: op, call: call));
  }

  void _emit(MemoryPhoneLink peer, PhoneSignal signal) {
    final parsed = phoneSignal(
      signal.from,
      phoneLine(
        op: signal.op,
        call: callIdOf(signal.call),
        name: signal.name,
        addr: signal.addr,
      ),
    );
    if (parsed == null) return;
    peer._onSignal?.call(parsed);
  }

  @override
  void audio({required String endpoint, required Uint8List packet}) {
    party.find(endpoint)?._onAudio?.call(this.endpoint, packet);
  }

  @override
  void drop(String endpoint) {}
}

/// Call ids on the wire are 8 hex chars. A longer id is clipped into that.
String callIdOf(String call) {
  final hex = call.replaceAll(RegExp(r'[^0-9a-f]'), '');
  if (hex.length >= 8) return hex.substring(0, 8);
  return hex.padLeft(8, '0');
}

/// One call at a time. Signaling is a few words; voice is μ-law frames.
class Handset extends ChangeNotifier {
  Handset({
    required this.link,
    required this.gear,
    this.ringFor = const Duration(seconds: 45),
    this.clock = _utcNow,
    this.onRecord,
    this.onLive,
    this.onListed,
  });

  final PhoneLink link;
  final PhoneGear gear;
  final Duration ringFor;
  final DateTime Function() clock;
  final void Function(CallRecord record)? onRecord;
  final void Function(PhoneContact contact)? onLive;
  final void Function(String endpoint, String addr)? onListed;

  CallPhase phase = CallPhase.idle;
  PhoneFault fault = PhoneFault.none;
  Wire wire = Wire.starting;
  String selfEndpoint = '';
  String selfAddr = '';
  String peerEndpoint = '';
  String peerAddr = '';
  String peerName = '';
  String callId = '';
  CallWay direction = CallWay.outgoing;
  bool muted = false;
  bool gearLive = false;
  int seconds = 0;

  Timer? _ringTimer;
  Timer? _clockTimer;
  StreamSubscription<Uint8List>? _micSub;
  var _leg = 0;
  var _ending = false;
  var _seq = 0;
  int? _lastSeq;

  String get card => phoneCard(endpoint: selfEndpoint, addr: selfAddr);

  String get shownPeer =>
      peerName.isEmpty ? phoneShort(peerEndpoint) : peerName;

  Future<void> open({List<int>? secret, String fallback = ''}) async {
    selfEndpoint = fallback;
    wire = Wire.starting;
    notifyListeners();
    await link.start(
      secret: secret,
      onReady: (endpoint, addr) {
        if (endpoint.isNotEmpty) selfEndpoint = endpoint;
        if (addr.isNotEmpty) selfAddr = addr;
        wire = Wire.up;
        notifyListeners();
        if (selfEndpoint.isNotEmpty && selfAddr.isNotEmpty) {
          onListed?.call(selfEndpoint, selfAddr);
        }
      },
      onSignal: _onSignal,
      onAudio: _onAudio,
    );
    wire = link.dataPath ? Wire.up : Wire.absent;
    notifyListeners();
  }

  Future<void> close() async {
    _leg += 1;
    hangup();
    await _micSub?.cancel();
    _micSub = null;
    await gear.ring(kind: '');
    await gear.down();
    await link.stop();
    wire = Wire.absent;
    notifyListeners();
  }

  Future<void> dial(PhoneAddress to, {required String myName}) async {
    if (phase != CallPhase.idle) {
      fault = PhoneFault.busy;
      notifyListeners();
      return;
    }
    if (to.endpoint.isEmpty || to.endpoint == selfEndpoint) {
      fault = PhoneFault.self;
      notifyListeners();
      return;
    }
    if (wire != Wire.up || !link.dataPath) {
      fault = PhoneFault.offline;
      notifyListeners();
      return;
    }
    if (to.addr.isEmpty) {
      fault = PhoneFault.unreachable;
      notifyListeners();
      return;
    }
    final leg = ++_leg;
    fault = PhoneFault.none;
    peerEndpoint = to.endpoint;
    peerAddr = to.addr;
    peerName = to.name;
    callId = _freshId();
    direction = CallWay.outgoing;
    _enter(CallPhase.dialing);
    try {
      await link.invite(
        endpoint: to.endpoint,
        addr: to.addr,
        call: callId,
        name: clipPhoneName(myName),
        ourAddr: selfAddr,
      );
    } on Object catch (_) {
      if (leg != _leg || phase != CallPhase.dialing) return;
      _finish(fault: PhoneFault.unreachable, way: CallWay.outgoing);
      return;
    }
    if (leg != _leg) link.drop(to.endpoint);
  }

  void accept() {
    if (phase != CallPhase.ringing) return;
    link.reply(endpoint: peerEndpoint, op: 'accept', call: callId);
    _goLive();
  }

  void decline() => hangup();

  void hangup() {
    if (phase == CallPhase.idle || _ending) return;
    final way = switch (phase) {
      CallPhase.ringing => CallWay.missed,
      CallPhase.live => direction,
      CallPhase.dialing || CallPhase.idle => CallWay.outgoing,
    };
    final op = phase == CallPhase.ringing ? 'decline' : 'hangup';
    link.reply(endpoint: peerEndpoint, op: op, call: callId);
    _finish(way: way);
  }

  void toggleMute() {
    muted = !muted;
    notifyListeners();
  }

  void _onSignal(PhoneSignal signal) {
    switch (signal.op) {
      case 'invite':
        _invited(signal);
      case 'accept':
        if (phase == CallPhase.dialing && signal.call == callId) _goLive();
      case 'decline':
        if (phase == CallPhase.dialing && signal.call == callId) {
          _finish(fault: PhoneFault.declined, way: CallWay.outgoing);
        }
      case 'busy':
        if (phase == CallPhase.dialing && signal.call == callId) {
          _finish(fault: PhoneFault.busy, way: CallWay.outgoing);
        }
      case 'hangup':
        if (phase != CallPhase.idle && signal.call == callId) {
          _finish(way: phase == CallPhase.ringing ? CallWay.missed : direction);
        }
    }
  }

  void _invited(PhoneSignal signal) {
    if (phase != CallPhase.idle) {
      link.reply(endpoint: signal.from, op: 'busy', call: signal.call);
      return;
    }
    fault = PhoneFault.none;
    peerEndpoint = signal.from;
    peerAddr = signal.addr;
    peerName = signal.name;
    callId = signal.call;
    direction = CallWay.incoming;
    _enter(CallPhase.ringing);
  }

  void _enter(CallPhase next) {
    phase = next;
    final kind = next == CallPhase.ringing ? 'in' : 'out';
    unawaited(gear.ring(kind: kind));
    _ringTimer?.cancel();
    _ringTimer = Timer(ringFor, () {
      if (phase != CallPhase.dialing && phase != CallPhase.ringing) return;
      link.reply(endpoint: peerEndpoint, op: 'hangup', call: callId);
      _finish(
        fault: PhoneFault.timeout,
        way: phase == CallPhase.ringing ? CallWay.missed : CallWay.outgoing,
      );
    });
    notifyListeners();
  }

  void _goLive() {
    if (phase == CallPhase.live) return;
    _ringTimer?.cancel();
    _seq = 0;
    _lastSeq = null;
    seconds = 0;
    gearLive = false;
    fault = PhoneFault.none;
    phase = CallPhase.live;
    unawaited(gear.ring(kind: ''));
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (phase != CallPhase.live) return;
      seconds += 1;
      notifyListeners();
    });
    _micSub ??= gear.mic.listen(_onMic, onError: (_) {});
    unawaited(_openGear());
    if (peerEndpoint.isNotEmpty) {
      onLive?.call(
        PhoneContact(endpoint: peerEndpoint, addr: peerAddr, name: peerName),
      );
    }
    notifyListeners();
  }

  Future<void> _openGear() async {
    try {
      await gear.up();
      if (phase != CallPhase.live) {
        await gear.down();
        return;
      }
      gearLive = true;
      notifyListeners();
    } on Object catch (_) {
      if (phase != CallPhase.live) return;
      gearLive = false;
      fault = PhoneFault.gear;
      notifyListeners();
    }
  }

  void _onMic(Uint8List ulaw) {
    if (muted || phase != CallPhase.live || ulaw.length != phoneFrame) return;
    final seq = _seq & 0xFFFF;
    _seq += 1;
    link.audio(endpoint: peerEndpoint, packet: packAudio(seq, ulaw));
  }

  void _onAudio(String from, Uint8List packet) {
    if (phase != CallPhase.live || from != peerEndpoint) return;
    final frame = unpackAudio(packet);
    if (frame == null) return;
    final seq = frame.$1;
    final last = _lastSeq;
    if (last != null) {
      final ahead = (seq - last) & 0xFFFF;
      if (ahead == 0 || ahead > 0x8000) return;
    }
    _lastSeq = seq;
    gear.hear(frame.$2);
  }

  void _finish({PhoneFault fault = PhoneFault.none, required CallWay way}) {
    if (phase == CallPhase.idle || _ending) return;
    _ending = true;
    _leg += 1;
    _ringTimer?.cancel();
    _clockTimer?.cancel();
    _clockTimer = null;
    final record = CallRecord(
      endpoint: peerEndpoint,
      addr: peerAddr,
      name: peerName.isEmpty ? phoneShort(peerEndpoint) : peerName,
      way: way,
      seconds: phase == CallPhase.live ? seconds : 0,
      at: clock(),
    );
    final peer = peerEndpoint;
    phase = CallPhase.idle;
    this.fault = fault;
    gearLive = false;
    seconds = 0;
    muted = false;
    unawaited(gear.ring(kind: ''));
    unawaited(gear.down());
    final sub = _micSub;
    _micSub = null;
    if (sub != null) unawaited(sub.cancel());
    link.drop(peer);
    _ending = false;
    notifyListeners();
    if (record.endpoint.isNotEmpty) onRecord?.call(record);
  }

  String _freshId() {
    final mixed =
        (clock().microsecondsSinceEpoch ^ (_leg * 0x9E3779B1)) & 0xFFFFFFFF;
    return mixed.toRadixString(16).padLeft(8, '0');
  }

  @override
  void dispose() {
    _ringTimer?.cancel();
    _clockTimer?.cancel();
    unawaited(_micSub?.cancel() ?? Future<void>.value());
    super.dispose();
  }
}

DateTime _utcNow() => DateTime.now().toUtc();

class PhoneScope extends InheritedNotifier<Handset> {
  const PhoneScope({required Handset handset, required super.child, super.key})
    : super(notifier: handset);

  static Handset of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PhoneScope>();
    final handset = scope?.notifier;
    if (handset == null) throw StateError('PhoneScope missing');
    return handset;
  }
}
