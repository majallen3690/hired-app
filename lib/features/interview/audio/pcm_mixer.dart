import 'dart:math' as math;
import 'dart:typed_data';

const modelRate = 24000;
const micRate = 16000;

/// A run of 16-bit mono PCM placed on the session clock.
class PcmClip {
  const PcmClip({required this.startMs, required this.samples, required this.sampleRate});
  final int startMs;
  final Int16List samples;
  final int sampleRate;

  int get durationMs => (samples.length * 1000 / sampleRate).round();
  int get endMs => startMs + durationMs;

  PcmClip trimmedTo(int endMs) {
    final keep = ((endMs - startMs) * sampleRate / 1000).floor().clamp(0, samples.length);
    return PcmClip(startMs: startMs, samples: Int16List.sublistView(samples, 0, keep), sampleRate: sampleRate);
  }
}

Int16List pcmFromBytes(Uint8List bytes) {
  final even = bytes.length - (bytes.length % 2);
  final copy = Uint8List.fromList(bytes.sublist(0, even));
  return copy.buffer.asInt16List();
}

/// Collects both sides of a session. The interviewer's audio arrives faster than real time, so each chunk is
/// scheduled to start when the previous one finishes playing, which is when the user actually hears it.
class SessionAudioRecorder {
  final List<PcmClip> _clips = [];
  int _modelCursorMs = 0;

  List<PcmClip> get clips => List.unmodifiable(_clips);

  /// Where the interviewer's audio queue currently ends on the session clock.
  int get modelCursorMs => _modelCursorMs;

  void addCandidate(int nowMs, Uint8List bytes) {
    if (bytes.isEmpty) return;
    _clips.add(PcmClip(startMs: nowMs, samples: pcmFromBytes(bytes), sampleRate: micRate));
  }

  /// Returns the session time at which this chunk will be heard.
  int addModel(int nowMs, Uint8List bytes) {
    final start = math.max(nowMs, _modelCursorMs);
    final clip = PcmClip(startMs: start, samples: pcmFromBytes(bytes), sampleRate: modelRate);
    _clips.add(clip);
    _modelCursorMs = clip.endMs;
    return start;
  }

  /// The user spoke over the interviewer: what was queued but not yet played is never heard.
  void interrupt(int nowMs) {
    if (_modelCursorMs <= nowMs) return;
    for (var i = _clips.length - 1; i >= 0; i--) {
      final c = _clips[i];
      if (c.sampleRate != modelRate || c.endMs <= nowMs) continue;
      if (c.startMs >= nowMs) {
        _clips.removeAt(i);
      } else {
        _clips[i] = c.trimmedTo(nowMs);
      }
    }
    _modelCursorMs = nowMs;
  }
}

/// Mixes every clip onto one timeline, resampling to [outRate], and returns a complete WAV file.
Uint8List mixToWav(List<PcmClip> clips, {int outRate = modelRate, int minMs = 0}) {
  var total = (minMs * outRate / 1000).ceil();
  for (final c in clips) {
    final end = (c.startMs * outRate / 1000).round() + (c.samples.length * outRate / c.sampleRate).floor();
    total = math.max(total, end);
  }
  final out = Int16List(total);
  for (final c in clips) {
    if (c.samples.isEmpty) continue;
    final offset = (c.startMs * outRate / 1000).round();
    final length = (c.samples.length * outRate / c.sampleRate).floor();
    final step = c.sampleRate / outRate;
    for (var i = 0; i < length; i++) {
      final pos = i * step;
      final i0 = pos.floor();
      final i1 = math.min(i0 + 1, c.samples.length - 1);
      final frac = pos - i0;
      final v = c.samples[i0] + (c.samples[i1] - c.samples[i0]) * frac;
      final at = offset + i;
      if (at >= out.length) break;
      out[at] = (out[at] + v.round()).clamp(-32768, 32767);
    }
  }
  return wavBytes(out, outRate);
}

Uint8List wavBytes(Int16List samples, int sampleRate) {
  final dataLen = samples.length * 2;
  final b = ByteData(44 + dataLen);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      b.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  b.setUint32(4, 36 + dataLen, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little); // PCM
  b.setUint16(22, 1, Endian.little); // mono
  b.setUint32(24, sampleRate, Endian.little);
  b.setUint32(28, sampleRate * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  b.setUint32(40, dataLen, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    b.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  return b.buffer.asUint8List();
}
