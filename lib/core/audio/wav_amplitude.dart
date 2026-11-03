import 'dart:math' as math;
import 'dart:typed_data';

import '../../features/interview/domain/speech_metrics.dart';

/// Loudness of each [stepMs] slice of a 16-bit PCM WAV, in dBFS: the same kind of reading the microphone gives while
/// recording, so the pause and delivery measurements can run on a saved recording.
List<AmplitudeSample> wavAmplitude(Uint8List wav, {int stepMs = 100}) {
  final data = ByteData.sublistView(wav);
  if (wav.length < 44 || String.fromCharCodes(wav.sublist(0, 4)) != 'RIFF') {
    throw const FormatException('not a WAV file');
  }
  final channels = data.getUint16(22, Endian.little);
  final rate = data.getUint32(24, Endian.little);
  final bits = data.getUint16(34, Endian.little);
  if (bits != 16) throw FormatException('expected 16-bit audio, got $bits');

  var at = 12;
  var start = -1, length = 0;
  while (at + 8 <= wav.length) {
    final id = String.fromCharCodes(wav.sublist(at, at + 4));
    final size = data.getUint32(at + 4, Endian.little);
    if (id == 'data') {
      start = at + 8;
      length = math.min(size, wav.length - start);
      break;
    }
    at += 8 + size + (size.isOdd ? 1 : 0);
  }
  if (start < 0) throw const FormatException('no audio data in WAV');

  final frame = 2 * channels;
  final framesPerStep = rate * stepMs ~/ 1000;
  final frames = length ~/ frame;
  final out = <AmplitudeSample>[];
  for (var f = 0; f + framesPerStep <= frames; f += framesPerStep) {
    var sum = 0.0;
    for (var i = 0; i < framesPerStep; i++) {
      // Channels are averaged; the app records mono.
      var s = 0;
      for (var c = 0; c < channels; c++) {
        s += data.getInt16(start + (f + i) * frame + c * 2, Endian.little);
      }
      final v = s / channels / 32768;
      sum += v * v;
    }
    final rms = math.sqrt(sum / framesPerStep);
    final db = rms <= 0 ? -100.0 : math.max(-100.0, 20 * math.log(rms) / math.ln10);
    out.add(AmplitudeSample(f * 1000 ~/ rate + stepMs ~/ 2, db));
  }
  return out;
}

/// Length of a 16-bit PCM WAV in milliseconds.
int wavDurationMs(Uint8List wav) {
  final data = ByteData.sublistView(wav);
  final channels = data.getUint16(22, Endian.little);
  final rate = data.getUint32(24, Endian.little);
  var at = 12;
  while (at + 8 <= wav.length) {
    final id = String.fromCharCodes(wav.sublist(at, at + 4));
    final size = data.getUint32(at + 4, Endian.little);
    if (id == 'data') return math.min(size, wav.length - at - 8) * 1000 ~/ (rate * 2 * channels);
    at += 8 + size + (size.isOdd ? 1 : 0);
  }
  throw const FormatException('no audio data in WAV');
}
