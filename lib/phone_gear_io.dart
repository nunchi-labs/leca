import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:record/record.dart';

import 'phone.dart';

/// The device microphone and speaker. Tests use the silent gear.
PhoneGear openPhoneGear() {
  if (Platform.environment['FLUTTER_TEST'] == 'true') return SilentGear();
  return HandsetGear();
}

/// G.711 in, PCM out. Echo cancel and voice-communication mode are the
/// handset path on Android; a headset uses the system route.
class HandsetGear implements PhoneGear {
  final _mic = StreamController<Uint8List>.broadcast();
  final _samples = <int>[];
  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _sub;
  AudioSource? _speaker;
  SoundHandle? _voice;
  Future<AudioSource>? _opening;
  Timer? _ring;
  String _ringKind = '';
  var _ticks = 0;
  var _phase = 0;
  var _step = 1;
  var _seen = 0;
  var _gen = 0;

  @override
  Stream<Uint8List> get mic => _mic.stream;

  @override
  Future<void> up() async {
    await _ensureSpeaker();
    final source = _speaker;
    if (source != null) {
      try {
        SoLoud.instance.resetBufferStream(source);
      } on Object catch (_) {}
    }
    await _micUp();
  }

  @override
  Future<void> down() async {
    _gen += 1;
    _ringKind = '';
    _ring?.cancel();
    _ring = null;
    await _sub?.cancel();
    _sub = null;
    final recorder = _recorder;
    _recorder = null;
    if (recorder != null) {
      try {
        await recorder.stop();
      } on Object catch (_) {}
      try {
        await recorder.dispose();
      } on Object catch (_) {}
    }
    _samples.clear();
    _seen = 0;
    final voice = _voice;
    final source = _speaker;
    _voice = null;
    _speaker = null;
    if (voice != null) {
      try {
        await SoLoud.instance.stop(voice);
      } on Object catch (_) {}
    }
    if (source != null) {
      try {
        await SoLoud.instance.disposeSource(source);
      } on Object catch (_) {}
    }
    if (SoLoud.instance.isInitialized) {
      try {
        await SoLoud.instance.deinitAsync();
      } on Object catch (_) {}
    }
  }

  @override
  Future<void> ring({required String kind}) async {
    _ringKind = kind;
    _ring?.cancel();
    _ring = null;
    _ticks = 0;
    if (kind.isEmpty) return;
    try {
      await _ensureSpeaker();
    } on Object catch (_) {
      return;
    }
    if (_ringKind != kind) return;
    _ring = Timer.periodic(const Duration(milliseconds: 20), _tickRing);
  }

  @override
  void hear(Uint8List ulaw) {
    if (ulaw.length != phoneFrame) return;
    _play(ulawToPcm16(ulaw));
  }

  Future<void> _micUp() async {
    final recorder = AudioRecorder();
    _recorder = recorder;
    final allowed = await recorder.hasPermission();
    if (!allowed) throw StateError('mic');
    await recorder.setOnConfigChanged((config) {
      if (config.sampleRate >= 8000) {
        _step = (config.sampleRate / 8000).round().clamp(1, 12);
      }
    });
    final stream = await recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 8000,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        autoGain: true,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceCommunication,
          audioManagerMode: AudioManagerMode.modeInCommunication,
          manageBluetooth: false,
        ),
        iosConfig: IosRecordConfig(
          categoryOptions: [
            IosAudioCategoryOption.allowBluetooth,
            IosAudioCategoryOption.allowBluetoothA2DP,
          ],
        ),
      ),
    );
    _sub = stream.listen(_takePcm, onError: (_) {});
  }

  void _takePcm(Uint8List chunk) {
    if (chunk.length < 2) return;
    final data = ByteData.sublistView(chunk);
    final count = chunk.length ~/ 2;
    for (var i = 0; i < count; i++) {
      _seen += 1;
      if (_seen % _step != 0) continue;
      _samples.add(data.getInt16(i * 2, Endian.little));
      if (_samples.length < phoneFrame) continue;
      final frame = Uint8List(phoneFrame);
      for (var s = 0; s < phoneFrame; s++) {
        frame[s] = ulawEncode(_samples[s]);
      }
      _samples.removeRange(0, phoneFrame);
      if (!_mic.isClosed) _mic.add(frame);
    }
  }

  Future<AudioSource> _ensureSpeaker() {
    final existing = _speaker;
    if (existing != null) return Future<AudioSource>.value(existing);
    final pending = _opening;
    if (pending != null) return pending;
    final gen = _gen;
    final opening = _openSpeaker(gen);
    _opening = opening;
    return opening.whenComplete(() {
      if (identical(_opening, opening)) _opening = null;
    });
  }

  Future<AudioSource> _openSpeaker(int gen) async {
    final soloud = SoLoud.instance;
    if (!soloud.isInitialized) {
      await soloud.init(
        sampleRate: 48000,
        channels: Channels.mono,
        bufferSize: 512,
        lowLatency: true,
      );
    }
    if (gen != _gen) throw StateError('closed');
    final source = soloud.setBufferStream(
      bufferingType: BufferingType.released,
      bufferingTimeNeeds: 0.06,
      sampleRate: 8000,
      channels: Channels.mono,
      format: BufferType.s16le,
      maxBufferSizeBytes: 8 * 1024 * 1024,
    );
    final voice = soloud.play(source);
    if (gen != _gen) {
      await soloud.stop(voice);
      await soloud.disposeSource(source);
      throw StateError('closed');
    }
    _speaker = source;
    _voice = voice;
    return source;
  }

  void _tickRing(Timer timer) {
    final kind = _ringKind;
    if (kind.isEmpty) return;
    final on = kind == 'in' ? _ringOn(_ticks) : _backOn(_ticks);
    _ticks += 1;
    if (kind == 'in' && _ticks >= 150) _ticks = 0;
    if (kind == 'out' && _ticks >= 200) _ticks = 0;
    if (!on) return;
    _play(_tone(hz: kind == 'in' ? 425 : 440, phase: _phase));
    _phase += phoneFrame;
  }

  void _play(Uint8List pcm) {
    final source = _speaker;
    if (source == null) return;
    try {
      SoLoud.instance.addAudioDataStream(source, pcm);
    } on Object catch (_) {}
  }
}

bool _ringOn(int tick) {
  final t = tick % 150;
  return t < 20 || (t >= 30 && t < 50);
}

bool _backOn(int tick) => tick % 200 < 50;

Uint8List _tone({required int hz, required int phase}) {
  final out = Uint8List(phoneFrame * 2);
  final data = ByteData.sublistView(out);
  for (var i = 0; i < phoneFrame; i++) {
    final theta = 2 * math.pi * hz * ((phase + i) / 8000);
    final sample = (math.sin(theta) * 9000).round().clamp(-32767, 32767);
    data.setInt16(i * 2, sample, Endian.little);
  }
  return out;
}
