import 'interview_models.dart';

/// Longest phrases first so "you know" is one filler, not two.
const fillerPhrases = <String>[
  'you know',
  'kind of',
  'sort of',
  'i mean',
  'basically',
  'literally',
  'actually',
  'matlab',
  'yaani',
  'umm',
  'uhh',
  'um',
  'uh',
  'erm',
  'er',
];

final _fillerPattern = RegExp(
  '\\b(${fillerPhrases.map(RegExp.escape).join('|')})\\b',
  caseSensitive: false,
);

class FillerHit {
  const FillerHit(this.word, this.start, this.end);
  final String word;
  final int start;
  final int end;
}

List<FillerHit> findFillers(String text) => [
      for (final m in _fillerPattern.allMatches(text)) FillerHit(m.group(1)!.toLowerCase(), m.start, m.end),
    ];

int wordCount(String text) => text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;

/// Words per minute, or null when the sample is too short to mean anything.
double? paceWpm(int words, int durationMs) {
  if (words < 8 || durationMs < 3000) return null;
  return words * 60000 / durationMs;
}

class SpeechSummary {
  const SpeechSummary({
    required this.words,
    required this.speakingMs,
    required this.wpm,
    required this.fillerCount,
    required this.topFillers,
    required this.longPauses,
  });

  final int words;
  final int speakingMs;
  final double? wpm;
  final int fillerCount;

  /// filler word to count, most used first.
  final Map<String, int> topFillers;
  final int longPauses;

  double get fillersPer100Words => words == 0 ? 0 : fillerCount * 100 / words;

  /// Below this the sample is too small to judge, so no communication score is given.
  bool get enoughSpeech => words >= 20;
}

SpeechSummary summariseSpeech(List<TranscriptTurn> turns, {List<Pause> pauses = const []}) {
  var words = 0, speaking = 0, fillers = 0;
  final counts = <String, int>{};
  for (final t in turns.where((t) => t.speaker == Speaker.candidate && !t.typed)) {
    words += wordCount(t.text);
    speaking += t.durationMs;
    for (final h in findFillers(t.text)) {
      fillers++;
      counts[h.word] = (counts[h.word] ?? 0) + 1;
    }
  }
  final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return SpeechSummary(
    words: words,
    speakingMs: speaking,
    wpm: paceWpm(words, speaking),
    fillerCount: fillers,
    topFillers: {for (final e in sorted) e.key: e.value},
    longPauses: pauses.length,
  );
}

const idealPaceMin = 120.0;
const idealPaceMax = 160.0;

/// Measured, never model-judged: pace inside 120 to 160 wpm, few fillers, few long pauses.
/// Null when there is too little speech to judge.
int? communicationScore(SpeechSummary s) {
  if (!s.enoughSpeech) return null;
  var score = 100.0;
  final wpm = s.wpm;
  if (wpm != null) {
    final off = wpm < idealPaceMin ? idealPaceMin - wpm : (wpm > idealPaceMax ? wpm - idealPaceMax : 0.0);
    score -= (off * 0.75).clamp(0, 30);
  }
  score -= (s.fillersPer100Words * 6).clamp(0, 40);
  score -= (s.longPauses * 5).clamp(0, 20);
  return score.round().clamp(0, 100);
}

class AmplitudeSample {
  const AmplitudeSample(this.ms, this.db);
  final int ms;
  final double db;
}

/// Silences of at least [minMs] that fall inside the windows where the candidate had the floor.
/// A short think before answering is normal, so only long ones count.
List<Pause> findLongPauses(
  List<AmplitudeSample> samples,
  List<({int startMs, int endMs})> candidateWindows, {
  double thresholdDb = -42,
  int minMs = 4000,
}) {
  final pauses = <Pause>[];
  for (final w in candidateWindows) {
    int? quietFrom;
    int lastQuiet = 0;
    void close() {
      if (quietFrom != null && lastQuiet - quietFrom! >= minMs) {
        pauses.add(Pause(startMs: quietFrom!, endMs: lastQuiet));
      }
      quietFrom = null;
    }

    for (final s in samples.where((s) => s.ms >= w.startMs && s.ms <= w.endMs)) {
      if (s.db < thresholdDb) {
        quietFrom ??= s.ms;
        lastQuiet = s.ms;
      } else {
        close();
      }
    }
    close();
  }
  return pauses;
}

/// The windows between an interviewer turn ending and the next one starting, where the candidate really spoke.
/// A stretch where they typed instead is not a pause: the microphone is quiet because they are typing.
List<({int startMs, int endMs})> candidateWindows(List<TranscriptTurn> turns, int sessionEndMs) {
  final windows = <({int startMs, int endMs})>[];
  for (var i = 0; i < turns.length; i++) {
    if (turns[i].speaker != Speaker.interviewer) continue;
    final next = turns.skip(i + 1).where((t) => t.speaker == Speaker.interviewer).firstOrNull;
    final start = turns[i].endMs;
    final end = next?.startMs ?? sessionEndMs;
    // The transcript trails the speech, so a spoken turn can be dated slightly before the window opens.
    final spoke = turns.any((t) =>
        t.speaker == Speaker.candidate && !t.typed && t.startMs >= start - 3000 && t.startMs <= end);
    if (spoke) windows.add((startMs: start, endMs: end));
  }
  return windows;
}

enum MarkerKind { question, filler, pause }

class Marker {
  const Marker({required this.kind, required this.atMs, required this.label, required this.note, this.evidence});
  final MarkerKind kind;
  final int atMs;
  final String label;

  /// The coach note shown when the marker is tapped.
  final String note;

  /// The words or measurement the marker is based on.
  final String? evidence;
}

/// Everything the Coach Replay timeline shows, derived only from the transcript and measured pauses.
List<Marker> buildMarkers(List<TranscriptTurn> turns, List<Pause> pauses) {
  final markers = <Marker>[];
  var q = 0;
  for (final t in turns) {
    if (t.speaker == Speaker.interviewer) {
      q++;
      markers.add(Marker(
        kind: MarkerKind.question,
        atMs: t.startMs,
        label: 'Q$q',
        note: 'The interviewer asked this.',
        evidence: t.text,
      ));
      continue;
    }
    if (t.typed) continue;
    final len = t.text.length;
    for (final h in findFillers(t.text)) {
      final at = t.startMs + (len == 0 ? 0 : (t.durationMs * h.start / len).round());
      markers.add(Marker(
        kind: MarkerKind.filler,
        atMs: at,
        label: h.word,
        note: 'You said "${h.word}". Pause silently instead; a short silence sounds more confident.',
        evidence: t.text.substring((h.start - 24).clamp(0, len), (h.end + 24).clamp(0, len)).trim(),
      ));
    }
  }
  for (final p in pauses) {
    markers.add(Marker(
      kind: MarkerKind.pause,
      atMs: p.startMs,
      label: '${(p.lengthMs / 1000).round()}s pause',
      note: 'A ${(p.lengthMs / 1000).toStringAsFixed(1)} second silence while it was your turn. '
          'Try saying "let me think for a moment" so it sounds planned.',
      evidence: 'Measured from the microphone level.',
    ));
  }
  markers.sort((a, b) => a.atMs.compareTo(b.atMs));
  return markers;
}
