import 'package:flutter_test/flutter_test.dart';
import 'package:hired/core/scoring/evidence.dart';
import 'package:hired/features/interview/domain/evaluation_models.dart' show Dimension;
import 'package:hired/features/interview/domain/speech_metrics.dart';
import 'package:hired/features/intro/domain/intro_analysis.dart';
import 'package:hired/features/intro/domain/intro_models.dart';

/// One level reading every 200 ms, like the microphone meter.
List<AmplitudeSample> levels(List<(int, int, double)> runs) => [
      for (final (from, to, db) in runs)
        for (var ms = from; ms < to; ms += 200) AmplitudeSample(ms, db),
    ];

const spoken =
    'Hi I am Ishita a final year computer science student at PES University. I built a campus attendance app '
    'that students use every day and I want to build reliable payments systems at Razorpay.';

Dimension d(int score, [String? evidence]) => Dimension(score: score, evidence: evidence);

PartCheck part(bool covered, [String? evidence]) => PartCheck(covered: covered, evidence: evidence, note: 'n');

IntroEvaluation eval({
  int clarity = 4,
  int structure = 4,
  int confidence = 4,
  bool who = true,
  bool what = true,
  bool why = true,
  String? quote,
}) =>
    IntroEvaluation(
      headline: 'Warm and clear',
      clarity: d(clarity, quote),
      structure: d(structure, quote),
      confidence: d(confidence, quote),
      who: part(who, who ? 'I am Ishita' : null),
      what: part(what, what ? 'campus attendance app' : null),
      why: part(why, why ? 'at Razorpay' : null),
      good: 'g',
      fix: 'f',
      stronger: 's',
    );

IntroRecord record(
  IntroEvaluation e, {
  IntroDelivery? delivery,
  DateTime? at,
  IntroMode mode = IntroMode.spoken,
}) =>
    IntroRecord(
      id: 'x',
      startedAt: at ?? DateTime.utc(2026, 11, 2),
      durationMs: 50000,
      mode: mode,
      transcript: spoken,
      target: 'SDE-1',
      delivery: delivery,
      evaluation: e,
    );

IntroDelivery delivery({int fillers = 2, int words = 100, double? wpm = 140, int? score = 80}) => IntroDelivery(
      words: words,
      speakingMs: 45000,
      wpm: wpm,
      fillerCount: fillers,
      topFillers: const {},
      longestPause: null,
      longPauses: 0,
      steadinessDb: 5,
      score: score,
    );

void main() {
  group('evidence check', () {
    test('accepts a real quote and rejects an invented one', () {
      expect(quoteIsGrounded('campus attendance app', spoken), isTrue);
      expect(quoteIsGrounded('I won the national hackathon', spoken), isFalse);
      expect(quoteIsGrounded(null, spoken), isFalse);
      expect(quoteIsGrounded('  ', spoken), isFalse);
    });
  });

  group('finding speech', () {
    test('a silent recording has no speech', () {
      expect(detectSpeech(levels([(0, 10000, -80)])), isNull);
    });

    test('under a second of voice is not speech', () {
      expect(detectSpeech(levels([(0, 5000, -70), (5000, 5600, -25), (5600, 10000, -70)])), isNull);
    });

    test('finds where the voice starts and ends', () {
      final span = detectSpeech(levels([(0, 1000, -70), (1000, 9000, -25), (9000, 12000, -70)]))!;
      expect(span.startMs, 1000);
      expect(span.endMs, 8800);
    });

    test('a quiet microphone still works because the threshold is relative', () {
      final span = detectSpeech(levels([(0, 2000, -62), (2000, 9000, -44), (9000, 11000, -62)]))!;
      expect(span.startMs, 2000);
      expect(span.endMs, 8800);
    });
  });

  group('delivery', () {
    final steady = levels([(0, 1000, -70), (1000, 9000, -25), (9000, 11000, -70)]);

    test('no speech in the audio gives no delivery at all', () {
      expect(measureDelivery(transcript: spoken, durationMs: 10000, amplitude: levels([(0, 10000, -80)])), isNull);
    });

    test('pace is words over the time actually talking, not the dead air around it', () {
      final m = measureDelivery(transcript: spoken, durationMs: 11000, amplitude: steady)!;
      final words = wordCount(spoken);
      expect(m.words, words);
      expect(m.wpm, closeTo(words * 60000 / m.speakingMs, 0.001));
      expect(m.speakingMs, 7800);
    });

    test('counts fillers and ranks them', () {
      final m = measureDelivery(
        transcript: '$spoken Um so basically I like building things, you know, um',
        durationMs: 11000,
        amplitude: steady,
      )!;
      expect(m.fillerCount, 4);
      expect(m.topFillers['um'], 2);
    });

    test('a short think is reported but costs nothing', () {
      final m = measureDelivery(
        transcript: spoken,
        durationMs: 12000,
        amplitude: levels([(0, 500, -70), (500, 4000, -25), (4000, 5800, -70), (5800, 11000, -25)]),
      )!;
      expect(m.longestPause, isNotNull);
      expect(m.longestPause!.lengthMs, inInclusiveRange(1400, 1800));
      expect(m.longPauses, 0);
    });

    test('a three second silence is a costly pause', () {
      final m = measureDelivery(
        transcript: spoken,
        durationMs: 14000,
        amplitude: levels([(0, 500, -70), (500, 4000, -25), (4000, 7400, -70), (7400, 12000, -25)]),
      )!;
      expect(m.longPauses, 1);
      expect(m.longestPause!.lengthMs, greaterThanOrEqualTo(costlyPauseMs));
    });

    test('too few words gives no delivery score', () {
      final m = measureDelivery(transcript: 'Hello there', durationMs: 5000, amplitude: steady)!;
      expect(m.score, isNull);
    });

    test('a flat, even voice reads as steady and a jumpy one does not', () {
      final flat = detectSpeech(steady)!;
      expect(steadinessLabel(volumeSpread(steady, flat)), 'steady');
      final jumpy = levels([
        for (var i = 0; i < 20; i++) (i * 400, i * 400 + 400, i.isEven ? -15.0 : -37.0),
      ]);
      expect(steadinessLabel(volumeSpread(jumpy, detectSpeech(jumpy)!)), 'uneven');
    });

    test('a transcript far faster than anyone talks was not in the audio', () {
      expect(transcriptMatchesAudio(120, 45000), isTrue);
      expect(transcriptMatchesAudio(400, 20000), isFalse);
      expect(transcriptMatchesAudio(50, 0), isFalse);
    });

    test('delivery survives a JSON round trip', () {
      final m = measureDelivery(transcript: spoken, durationMs: 11000, amplitude: steady)!;
      final back = IntroDelivery.fromJson(m.toJson());
      expect(back.words, m.words);
      expect(back.wpm, m.wpm);
      expect(back.score, m.score);
    });
  });

  group('content score', () {
    test('is the mean of three 1 to 5 ratings on a 100 scale', () {
      expect(eval(clarity: 5, structure: 5, confidence: 5).contentScore, 100);
      expect(eval(clarity: 4, structure: 4, confidence: 4).contentScore, 80);
    });

    test('structure cannot beat what the who, what, why check supports', () {
      expect(eval(structure: 5, why: false).structureScore, 4);
      expect(eval(structure: 5, why: false, what: false).structureScore, 3);
      expect(eval(structure: 5, who: false, why: false, what: false).structureScore, 2);
    });

    test('a quote that is not in the words is dropped and caps the rating at 3', () {
      final e = eval(clarity: 5, quote: 'I won the national hackathon').withVerifiedEvidence(spoken);
      expect(e.clarity.score, 3);
      expect(e.clarity.evidence, isNull);
    });

    test('a real quote keeps its rating', () {
      final e = eval(clarity: 5, quote: 'campus attendance app').withVerifiedEvidence(spoken);
      expect(e.clarity.score, 5);
      expect(e.clarity.evidence, 'campus attendance app');
    });

    test('a part with an invented quote is not counted as covered', () {
      final bad = IntroEvaluation(
        headline: 'h',
        clarity: d(4),
        structure: d(5, 'campus attendance app'),
        confidence: d(4),
        who: part(true, 'I am Ishita'),
        what: part(true, 'campus attendance app'),
        why: part(true, 'because I love the Razorpay mission statement of financial freedom'),
        good: 'g',
        fix: 'f',
        stronger: 's',
      ).withVerifiedEvidence(spoken);
      expect(bad.why.covered, isFalse);
      expect(bad.coveredParts, 2);
      expect(bad.structureScore, 4);
    });
  });

  group('intro score', () {
    test('a typed intro is content only', () {
      expect(introScore(80, null), 80);
    });

    test('a spoken intro blends in the measured delivery', () {
      expect(introScore(80, 60), (0.65 * 80 + 0.35 * 60).round());
    });

    test('only a spoken, scored intro counts as speaking', () {
      expect(record(eval(), delivery: delivery()).countsAsSpeaking, isTrue);
      expect(record(eval(), mode: IntroMode.typed).countsAsSpeaking, isFalse);
      expect(
        IntroRecord(
          id: 'y',
          startedAt: DateTime.utc(2026, 11, 2),
          durationMs: 1000,
          mode: IntroMode.spoken,
          transcript: spoken,
          target: '',
        ).countsAsSpeaking,
        isFalse,
      );
    });

    test('a record survives a JSON round trip', () {
      final r = record(eval(), delivery: delivery());
      final back = IntroRecord.fromJson(r.toJson());
      expect(back.score, r.score);
      expect(back.evaluation!.who.evidence, 'I am Ishita');
      expect(back.delivery!.fillerCount, 2);
      expect(back.mode, IntroMode.spoken);
    });
  });

  group('compared with last time', () {
    test('names what improved, best first', () {
      final before = record(eval(why: false, clarity: 3), delivery: delivery(fillers: 8, wpm: 110));
      final after = record(eval(clarity: 4), delivery: delivery(fillers: 1, wpm: 140));
      final changes = compareIntros(before, after);
      final texts = changes.map((c) => c.text).toList();
      expect(texts, contains('Now says why this role'));
      expect(texts, contains('Fillers down from 8 to 1'));
      expect(texts.any((t) => t.startsWith('Pace is now in the sweet spot')), isTrue);
      expect(texts, contains('Clarity up from 3 to 4'));
      expect(changes.every((c) => c.better), isTrue);
    });

    test('also says what got worse', () {
      final before = record(eval(), delivery: delivery(fillers: 1));
      final after = record(eval(what: false), delivery: delivery(fillers: 7));
      final changes = compareIntros(before, after);
      expect(changes.map((c) => c.text), containsAll(['Lost what you have built', 'Fillers up from 1 to 7']));
      expect(changes.every((c) => !c.better), isTrue);
    });

    test('improvements come before regressions and there are at most four', () {
      final before = record(eval(why: false, clarity: 2, confidence: 4), delivery: delivery(fillers: 9));
      final after = record(eval(what: false, clarity: 5, confidence: 2), delivery: delivery(fillers: 1));
      final changes = compareIntros(before, after);
      expect(changes.length, lessThanOrEqualTo(4));
      final firstWorse = changes.indexWhere((c) => !c.better);
      if (firstWorse >= 0) expect(changes.skip(firstWorse).every((c) => !c.better), isTrue);
    });

    test('an identical try changes nothing', () {
      final a = record(eval(), delivery: delivery());
      expect(compareIntros(a, a), isEmpty);
    });

    test('a typed intro has no fillers or pace to compare', () {
      final before = record(eval(why: false), mode: IntroMode.typed);
      final after = record(eval(), delivery: delivery(fillers: 0));
      expect(compareIntros(before, after).map((c) => c.text), ['Now says why this role']);
    });
  });

  group('spoken length', () {
    test('130 words take about a minute', () {
      final text = List.filled(130, 'word').join(' ');
      expect(spokenSeconds(text), 56);
    });
  });
}
