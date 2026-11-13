import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../data/focus_engine.dart';
import '../../data/focus_models.dart';
import '../../data/focus_store.dart';

/// Ambient sounds, all generated on the device (no downloads, works offline).
class AmbientSound {
  const AmbientSound(this.id, this.label, this.blurb);
  final String id;
  final String label;
  final String blurb;

  static const all = [
    AmbientSound('rain', 'Rain', 'Steady rain with droplets'),
    AmbientSound('ocean', 'Ocean', 'Slow waves'),
    AmbientSound('fire', 'Fireplace', 'Low rumble and crackles'),
    AmbientSound('brown', 'Brown noise', 'Deep and soft'),
    AmbientSound('pink', 'Pink noise', 'Balanced, like wind'),
    AmbientSound('white', 'White noise', 'Bright, masks voices'),
  ];
}

const _rate = 22050;

/// Wraps 16-bit mono samples (-1..1) in a WAV file.
Uint8List _wav(Float32List samples) {
  final n = samples.length;
  final data = ByteData(44 + n * 2);
  void str(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  data.setUint32(4, 36 + n * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, _rate, Endian.little);
  data.setUint32(28, _rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    data.setInt16(44 + i * 2, (samples[i].clamp(-1.0, 1.0) * 32000).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}

/// Makes a loop of [id] that repeats without a seam (the tail is cross-faded into the head).
Uint8List generateAmbient(String id) {
  const seconds = 12;
  const fade = _rate; // one second
  const total = _rate * seconds + fade;
  final r = math.Random(id.hashCode);
  final out = Float32List(total);

  double white() => r.nextDouble() * 2 - 1;

  if (id == 'white') {
    for (var i = 0; i < total; i++) {
      out[i] = white() * 0.32;
    }
  } else if (id == 'pink') {
    var b0 = 0.0, b1 = 0.0, b2 = 0.0, b3 = 0.0, b4 = 0.0, b5 = 0.0, b6 = 0.0;
    for (var i = 0; i < total; i++) {
      final w = white();
      b0 = 0.99886 * b0 + w * 0.0555179;
      b1 = 0.99332 * b1 + w * 0.0750759;
      b2 = 0.96900 * b2 + w * 0.1538520;
      b3 = 0.86650 * b3 + w * 0.3104856;
      b4 = 0.55000 * b4 + w * 0.5329522;
      b5 = -0.7616 * b5 - w * 0.0168980;
      out[i] = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362) * 0.09;
      b6 = w * 0.115926;
    }
  } else if (id == 'rain') {
    var b0 = 0.0, b1 = 0.0, b2 = 0.0;
    for (var i = 0; i < total; i++) {
      final w = white();
      b0 = 0.99765 * b0 + w * 0.0990460;
      b1 = 0.96300 * b1 + w * 0.2965164;
      b2 = 0.57000 * b2 + w * 1.0526913;
      out[i] = (b0 + b1 + b2 + w * 0.1848) * 0.07;
    }
    var i = 0;
    while (i < total) {
      i += (r.nextDouble() * _rate / 35).toInt() + 5;
      final len = 20 + r.nextInt(90);
      final amp = 0.05 + r.nextDouble() * 0.18;
      var prev = 0.0;
      for (var k = 0; k < len && i + k < total; k++) {
        final w = white();
        final hp = w - prev; // bright, short tick
        prev = w;
        out[i + k] += hp * amp * math.exp(-k / (len / 4));
      }
    }
  } else {
    // brown, ocean and fire all start from brown noise.
    var last = 0.0;
    for (var i = 0; i < total; i++) {
      last = (last + 0.02 * white()) / 1.02;
      out[i] = last * 3.2;
    }
    if (id == 'ocean') {
      // Two slow swells per loop so the loop length matches the wave period.
      for (var i = 0; i < total; i++) {
        final t = i / (_rate * seconds);
        final swell = 0.35 + 0.65 * math.pow(math.sin(math.pi * 2 * t), 2).toDouble();
        out[i] *= swell * 1.3;
      }
    } else if (id == 'fire') {
      for (var i = 0; i < total; i++) {
        out[i] *= 0.6;
      }
      var i = 0;
      while (i < total) {
        i += (r.nextDouble() * _rate * 0.18).toInt() + 40;
        final len = 30 + r.nextInt(220);
        final amp = 0.15 + r.nextDouble() * (r.nextDouble() < 0.1 ? 0.75 : 0.35);
        for (var k = 0; k < len && i + k < total; k++) {
          out[i + k] += white() * amp * math.exp(-k / (len / 5));
        }
      }
    }
  }

  // Cross-fade the extra second at the end into the start, then drop it.
  const loop = total - fade;
  for (var k = 0; k < fade; k++) {
    final t = k / fade;
    out[k] = out[k] * t + out[loop + k] * (1 - t);
  }
  return _wav(Float32List.sublistView(out, 0, loop));
}

/// A soft two-note bell for the end of a phase. [up] rises for "focus done".
Uint8List generateChime({bool up = true}) {
  const len = _rate * 2;
  final out = Float32List(len);
  final notes = up ? [659.25, 987.77] : [987.77, 659.25];
  for (var n = 0; n < notes.length; n++) {
    final startAt = n * (_rate * 0.32).toInt();
    final f = notes[n];
    for (var i = startAt; i < len; i++) {
      final t = (i - startAt) / _rate;
      final env = math.exp(-t * 3.2) * math.min(1.0, t * 200);
      out[i] += env *
          (0.55 * math.sin(2 * math.pi * f * t) + 0.22 * math.sin(2 * math.pi * f * 2.01 * t) + 0.1 * math.sin(2 * math.pi * f * 3.98 * t)) *
          0.5;
    }
  }
  return _wav(out);
}

/// One second with a soft click at the start, looped while focusing.
Uint8List generateTick() {
  final out = Float32List(_rate);
  final r = math.Random(7);
  for (var i = 0; i < 400; i++) {
    out[i] = (r.nextDouble() * 2 - 1) * 0.25 * math.exp(-i / 60) + 0.2 * math.sin(2 * math.pi * 1800 * i / _rate) * math.exp(-i / 80);
  }
  return _wav(out);
}

Map<String, Uint8List> _generateAll(List<String> ids) => {for (final id in ids) id: generateAmbient(id)};

/// Plays the ambient mix, the chime and the tick, following the timer and settings.
class FocusAudio {
  FocusAudio(this.engine) {
    _sub = engine.events.listen(_onEvent);
    engine.addListener(_sync);
  }

  final FocusEngine engine;
  FocusStore get store => engine.store;
  StreamSubscription<FocusEvent>? _sub;

  final Map<String, AudioPlayer> _players = {};
  final Map<String, Uint8List> _buffers = {};
  final Set<String> _loading = {};
  AudioPlayer? _chime;
  AudioPlayer? _tick;
  bool _tickOn = false;
  Uint8List? _chimeUp;
  Uint8List? _chimeDown;
  Uint8List? _tickBytes;
  String _lastMix = '';
  bool _lastAudible = false;

  static final _context = AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: false,
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.playback, options: const {AVAudioSessionOptions.mixWithOthers}),
  );

  bool get _audible {
    if (!store.soundsFollowTimer) return true;
    return engine.running && engine.phase == FocusPhase.focus;
  }

  Future<AudioPlayer> _newPlayer({bool loop = true}) async {
    final p = AudioPlayer();
    try {
      await p.setAudioContext(_context);
    } catch (_) {}
    await p.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
    return p;
  }

  /// Applies the current mix. Cheap to call often; only acts on changes.
  void _sync() {
    final mix = store.soundMix;
    final audible = _audible;
    final key = '${mix.entries.map((e) => '${e.key}:${e.value.toStringAsFixed(2)}').join(',')}|$audible';
    if (key != '$_lastMix|$_lastAudible') {
      _lastMix = key.split('|').first;
      _lastAudible = audible;
      _applyMix(mix, audible);
    }
    final wantTick = store.tick && engine.running && engine.phase == FocusPhase.focus;
    if (wantTick != _tickOn) {
      _tickOn = wantTick;
      _setTick(wantTick);
    }
  }

  Future<void> _applyMix(Map<String, double> mix, bool audible) async {
    final missing = [for (final id in mix.keys) if (!_buffers.containsKey(id) && !_loading.contains(id)) id];
    if (missing.isNotEmpty) {
      _loading.addAll(missing);
      final made = await compute(_generateAll, missing);
      _buffers.addAll(made);
      _loading.removeAll(missing);
    }
    for (final id in _players.keys.toList()) {
      if (!mix.containsKey(id) || !audible) {
        try {
          await _players[id]!.pause();
        } catch (_) {}
      }
    }
    if (!audible) return;
    final current = store.soundMix;
    for (final e in current.entries) {
      final bytes = _buffers[e.key];
      if (bytes == null) continue;
      try {
        var p = _players[e.key];
        if (p == null) {
          p = await _newPlayer();
          _players[e.key] = p;
          await p.setVolume(e.value);
          await p.play(BytesSource(bytes));
        } else {
          await p.setVolume(e.value);
          if (p.state != PlayerState.playing) await p.resume();
        }
      } catch (err) {
        debugPrint('Ambient sound ${e.key} failed: $err');
      }
    }
  }

  Future<void> _setTick(bool on) async {
    try {
      if (on) {
        _tickBytes ??= generateTick();
        _tick ??= await _newPlayer();
        await _tick!.setVolume(0.35);
        await _tick!.play(BytesSource(_tickBytes!));
      } else {
        await _tick?.stop();
      }
    } catch (err) {
      debugPrint('Tick failed: $err');
    }
  }

  /// Plays the chime once (also used as a preview in settings).
  Future<void> chime({bool up = true}) async {
    try {
      _chimeUp ??= generateChime(up: true);
      _chimeDown ??= generateChime(up: false);
      _chime ??= await _newPlayer(loop: false);
      await _chime!.setVolume(store.chimeVolume);
      await _chime!.play(BytesSource(up ? _chimeUp! : _chimeDown!));
    } catch (err) {
      debugPrint('Chime failed: $err');
    }
  }

  void _onEvent(FocusEvent e) {
    final end = e.kind == FocusEventKind.focusDone || e.kind == FocusEventKind.breakDone;
    if (!end) return;
    if (store.chime) chime(up: e.kind == FocusEventKind.focusDone);
    if (store.vibrate) HapticFeedback.heavyImpact();
  }

  void dispose() {
    _sub?.cancel();
    engine.removeListener(_sync);
    for (final p in _players.values) {
      p.dispose();
    }
    _chime?.dispose();
    _tick?.dispose();
  }
}
