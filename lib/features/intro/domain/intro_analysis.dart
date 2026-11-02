import 'dart:math' as math;

import '../../interview/domain/interview_models.dart';
import '../../interview/domain/speech_metrics.dart';
import 'intro_models.dart';

/// The length of the intro the app asks for.
const introSeconds = 60;

/// Fewer words than this and there is nothing to judge.
const minIntroWords = 20;

/// A silence this long while speaking is worth showing; one this long costs points.
const noticeablePauseMs = 1000;
const costlyPauseMs = 2500;

/// The stretch of the recording where the person was actually talking.
class SpeechSpan {
  const SpeechSpan({required this.startMs, required this.endMs, required this.voicedMs, required this.thresholdDb});
  final int startMs;
  final int endMs;

  /// Total time the voice was above the threshold.
  final int voicedMs;

  /// Levels below this count as quiet. Relative to how loud this person spoke, so a quiet microphone still works.
  final double thresholdDb;

  int get lengthMs => endMs - startMs;
}

int _sampleStep(List<AmplitudeSample> s) {
  if (s.length < 2) return 200;
  final gaps = <int>[for (var i = 1; i < s.length; i++) s[i].ms - s[i - 1].ms]..sort();
  return math.max(1, gaps[gaps.length ~/ 2]);
}

/// Finds where speech starts and ends, or null when the recording is silent or has under a second of voice.
SpeechSpan? detectSpeech(List<AmplitudeSample> samples) {
  if (samples.length < 5) return null;
  final levels = [for (final s in samples) s.db]..sort();
  final loud = levels[((levels.length - 1) * 0.9).round()];
  // Nothing in the recording is louder than a whisper: the mic heard silence.
  if (loud < -50) return null;
  final threshold = (loud - 22).clamp(-50.0, -36.0);
  final voiced = samples.where((s) => s.db >= threshold).toList();
  if (voiced.length < 5) return null;
  return SpeechSpan(
    startMs: voiced.first.ms,
    endMs: voiced.last.ms,
    voicedMs: voiced.length * _sampleStep(samples),
    thresholdDb: threshold,
  );
}

/// Spread of the voice level while talking, in dB. Null with too little voice to say.
double? volumeSpread(List<AmplitudeSample> samples, SpeechSpan span) {
  final v = [for (final s in samples) if (s.db >= span.thresholdDb) s.db];
  if (v.length < 5) return null;
  final mean = v.reduce((a, b) => a + b) / v.length;
  final variance = v.fold<double>(0, (a, b) => a + (b - mean) * (b - mean)) / v.length;
  return math.sqrt(variance);
}

String steadinessLabel(double? spreadDb) {
  if (spreadDb == null) return 'Not enough voice to tell';
  if (spreadDb < 6) return 'steady';
  if (spreadDb < 10) return 'a little uneven';
  return 'uneven';
}

/// Words said per second of actual speech cannot be this high: a transcript that fast was not in the audio.
const implausibleWpm = 300.0;

bool transcriptMatchesAudio(int words, int speakingMs) {
  if (speakingMs <= 0) return false;
  return words * 60000 / speakingMs <= implausibleWpm;
}

/// Delivery measured from the transcript and the microphone level. Null when the recording held no speech at all.
IntroDelivery? measureDelivery({
  required String transcript,
  required int durationMs,
  required List<AmplitudeSample> amplitude,
}) {
  final span = detectSpeech(amplitude);
  if (span == null) return null;

  final quiet = findLongPauses(
    amplitude,
    [(startMs: span.startMs, endMs: span.endMs)],
    thresholdDb: span.thresholdDb,
    minMs: noticeablePauseMs,
  );
  final longest = quiet.isEmpty ? null : quiet.reduce((a, b) => a.lengthMs >= b.lengthMs ? a : b);
  final costly = quiet.where((p) => p.lengthMs >= costlyPauseMs).toList();

  // Pace is measured over the time the person was talking, not the dead air before and after.
  final turn = TranscriptTurn(
    speaker: Speaker.candidate,
    text: transcript,
    startMs: span.startMs,
    endMs: math.max(span.endMs, span.startMs + 1),
  );
  final speech = summariseSpeech([turn], pauses: costly);
  return IntroDelivery(
    words: speech.words,
    speakingMs: speech.speakingMs,
    wpm: speech.wpm,
    fillerCount: speech.fillerCount,
    topFillers: speech.topFillers,
    longestPause: longest,
    longPauses: costly.length,
    steadinessDb: volumeSpread(amplitude, span),
    score: communicationScore(speech),
  );
}

/// How long a text takes to say at a comfortable pace.
int spokenSeconds(String text, {double wpm = 140}) => (wordCount(text) * 60 / wpm).round();

class IntroChange {
  const IntroChange(this.text, {required this.better});
  final String text;
  final bool better;
}

bool _paceOk(double? wpm) => wpm != null && wpm >= idealPaceMin && wpm <= idealPaceMax;

const _partLabels = {
  IntroPart.who: 'who you are',
  IntroPart.what: 'what you have built',
  IntroPart.why: 'why this role',
};

/// What changed since the last try, derived only from the two saved results. Improvements first, at most four.
List<IntroChange> compareIntros(IntroRecord before, IntroRecord after) {
  final b = before.evaluation;
  final a = after.evaluation;
  if (b == null || a == null) return const [];
  final out = <IntroChange>[];

  for (final p in IntroPart.values) {
    final was = b.part(p).covered;
    final now = a.part(p).covered;
    if (!was && now) out.add(IntroChange('Now says ${_partLabels[p]}', better: true));
    if (was && !now) out.add(IntroChange('Lost ${_partLabels[p]}', better: false));
  }

  final bd = before.delivery;
  final ad = after.delivery;
  if (bd != null && ad != null) {
    final drop = bd.fillersPer100Words - ad.fillersPer100Words;
    if (drop >= 1) out.add(IntroChange('Fillers down from ${bd.fillerCount} to ${ad.fillerCount}', better: true));
    if (drop <= -1) out.add(IntroChange('Fillers up from ${bd.fillerCount} to ${ad.fillerCount}', better: false));
    if (!_paceOk(bd.wpm) && _paceOk(ad.wpm)) {
      out.add(IntroChange('Pace is now in the sweet spot (${ad.wpm!.round()} wpm)', better: true));
    }
    if (_paceOk(bd.wpm) && ad.wpm != null && !_paceOk(ad.wpm)) {
      out.add(IntroChange('Pace slipped to ${ad.wpm!.round()} wpm', better: false));
    }
  }

  void rating(String label, int was, int now) {
    if (now - was >= 1) out.add(IntroChange('$label up from $was to $now', better: true));
    if (was - now >= 1) out.add(IntroChange('$label down from $was to $now', better: false));
  }

  rating('Clarity', b.clarity.score, a.clarity.score);
  rating('Confidence', b.confidence.score, a.confidence.score);

  out.sort((x, y) => (y.better ? 1 : 0).compareTo(x.better ? 1 : 0));
  return out.take(4).toList();
}
