import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../../interview/audio/pcm_mixer.dart';
import '../../interview/domain/speech_metrics.dart';

class IntroCapture {
  const IntroCapture({required this.pcm, required this.amplitude, required this.durationMs});
  final Uint8List pcm;
  final List<AmplitudeSample> amplitude;
  final int durationMs;

  Uint8List get wav => wavBytes(pcmFromBytes(pcm), micRate);
}

/// Records the microphone as 16 kHz mono PCM and keeps the level meter, which is what pauses and pace are measured
/// against. The raw signal is kept untouched: no gain or noise processing that would flatten the pauses.
class IntroRecorder {
  AudioRecorder? _mic;
  StreamSubscription<Uint8List>? _dataSub;
  StreamSubscription<Amplitude>? _ampSub;
  final _pcm = BytesBuilder(copy: false);
  final _amplitude = <AmplitudeSample>[];
  final _levels = StreamController<double>.broadcast();
  final _clock = Stopwatch();

  /// 0 to 1, about five times a second.
  Stream<double> get levels => _levels.stream;
  int get elapsedMs => _clock.elapsedMilliseconds;

  /// False when the permission was refused or the microphone could not start.
  Future<bool> start() async {
    try {
      final mic = AudioRecorder();
      if (!await mic.hasPermission()) {
        await mic.dispose();
        return false;
      }
      _mic = mic;
      final stream = await mic.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: micRate,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
        androidConfig: AndroidRecordConfig(audioSource: AndroidAudioSource.mic),
      ));
      _clock.start();
      _dataSub = stream.listen((data) {
        if (data.isNotEmpty) _pcm.add(data);
      });
      _ampSub = mic.onAmplitudeChanged(const Duration(milliseconds: 200)).listen((a) {
        _amplitude.add(AmplitudeSample(elapsedMs, a.current));
        _levels.add(((a.current + 60) / 60).clamp(0.0, 1.0));
      });
      return true;
    } catch (e) {
      debugPrint('Intro microphone failed: $e');
      await dispose();
      return false;
    }
  }

  Future<IntroCapture> stop() async {
    _clock.stop();
    await _ampSub?.cancel();
    try {
      await _mic?.stop();
    } catch (e) {
      debugPrint('Stopping the microphone: $e');
    }
    await _dataSub?.cancel();
    final capture = IntroCapture(
      pcm: _pcm.takeBytes(),
      amplitude: List.of(_amplitude),
      durationMs: elapsedMs,
    );
    await dispose();
    return capture;
  }

  /// Throws the recording away.
  Future<void> cancel() async {
    _clock.stop();
    await dispose();
  }

  Future<void> dispose() async {
    await _ampSub?.cancel();
    await _dataSub?.cancel();
    _ampSub = null;
    _dataSub = null;
    final mic = _mic;
    _mic = null;
    if (mic != null) {
      try {
        await mic.dispose();
      } catch (_) {}
    }
    if (!_levels.isClosed) await _levels.close();
  }
}
