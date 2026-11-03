import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hired/core/audio/wav_amplitude.dart';
import 'package:hired/features/interview/domain/speech_metrics.dart';

/// 16 kHz mono 16-bit WAV: [segments] of (milliseconds, amplitude 0..1) as a 440 Hz tone, 0 meaning silence.
Uint8List wav(List<(int, double)> segments) {
  const rate = 16000;
  final samples = <int>[];
  for (final (ms, amp) in segments) {
    for (var i = 0; i < rate * ms ~/ 1000; i++) {
      samples.add((amp * 32767 * math.sin(2 * math.pi * 440 * i / rate)).round());
    }
  }
  final data = ByteData(44 + samples.length * 2);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      data.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  test('reports the length of the audio', () {
    expect(wavDurationMs(wav([(1500, 0.5)])), 1500);
  });

  test('a full-scale-ish tone reads near -3 dBFS and digital silence reads the floor', () {
    final a = wavAmplitude(wav([(500, 1.0), (500, 0)]));
    expect(a, hasLength(10));
    expect(a.first.db, closeTo(-3, 0.5));
    expect(a.last.db, -100);
  });

  test('samples are timed from the start of the recording', () {
    final a = wavAmplitude(wav([(1000, 0.5)]));
    expect(a.first.ms, 50);
    expect(a[9].ms, 950);
  });

  test('a silence inside speech is found as a long pause by the same code a live session uses', () {
    final a = wavAmplitude(wav([(2000, 0.5), (4600, 0), (2000, 0.5)]));
    final pauses = findLongPauses(a, [(startMs: 0, endMs: 8600)]);
    expect(pauses, hasLength(1));
    expect(pauses.single.lengthMs, inInclusiveRange(4300, 4700));
    expect(pauses.single.startMs, inInclusiveRange(1900, 2200));
  });

  test('rejects anything that is not a 16-bit WAV', () {
    expect(() => wavAmplitude(Uint8List(100)), throwsFormatException);
  });
}
