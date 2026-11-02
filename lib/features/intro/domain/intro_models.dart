import '../../../core/scoring/evidence.dart';
import '../../interview/domain/evaluation_models.dart' show Dimension;
import '../../interview/domain/interview_models.dart' show Pause;

/// spoken = recorded from the microphone; typed = the fallback when there is no mic. A typed intro has no voice to
/// measure, so it is scored on content only and never counts towards the speaking score.
enum IntroMode { spoken, typed }

enum IntroPart { who, what, why }

class PartCheck {
  const PartCheck({required this.covered, this.evidence, required this.note});

  final bool covered;

  /// The line from the intro that shows this part, null when it is missing.
  final String? evidence;
  final String note;

  Map<String, dynamic> toJson() => {'covered': covered, 'evidence': evidence, 'note': note};

  factory PartCheck.fromJson(Map<String, dynamic> j) =>
      PartCheck(covered: j['covered'] as bool, evidence: j['evidence'] as String?, note: (j['note'] as String?) ?? '');
}

/// Content ratings from the model. Every number shown is computed here, and every quote is checked against the words.
class IntroEvaluation {
  const IntroEvaluation({
    required this.headline,
    required this.clarity,
    required this.structure,
    required this.confidence,
    required this.who,
    required this.what,
    required this.why,
    required this.good,
    required this.fix,
    required this.stronger,
  });

  final String headline;
  final Dimension clarity;
  final Dimension structure;
  final Dimension confidence;
  final PartCheck who;
  final PartCheck what;
  final PartCheck why;
  final String good;
  final String fix;

  /// A tighter rewrite using only facts the speaker gave, with [placeholders] where a detail is unknown.
  final String stronger;

  PartCheck part(IntroPart p) => switch (p) {
        IntroPart.who => who,
        IntroPart.what => what,
        IntroPart.why => why,
      };

  int get coveredParts => IntroPart.values.where((p) => part(p).covered).length;

  /// Structure cannot be rated higher than the who, what, why check supports: one part allows 3, two allow 4.
  int get structureScore => structure.score < 2 + coveredParts ? structure.score : 2 + coveredParts;

  int get contentScore => (((clarity.score + structureScore + confidence.score) / 3) * 20).round();

  /// A part counts as covered only if its quote is in the transcript. A rating whose quote is not real is capped at 3.
  IntroEvaluation withVerifiedEvidence(String transcript) {
    Dimension dim(Dimension d) =>
        quoteIsGrounded(d.evidence, transcript) ? d : Dimension(score: d.score > 3 ? 3 : d.score, evidence: null);

    PartCheck check(PartCheck p) {
      if (!p.covered) return PartCheck(covered: false, note: p.note);
      return quoteIsGrounded(p.evidence, transcript)
          ? p
          : PartCheck(covered: false, note: 'This part could not be found in your words.');
    }

    return IntroEvaluation(
      headline: headline,
      clarity: dim(clarity),
      structure: dim(structure),
      confidence: dim(confidence),
      who: check(who),
      what: check(what),
      why: check(why),
      good: good,
      fix: fix,
      stronger: stronger,
    );
  }

  Map<String, dynamic> toJson() => {
        'headline': headline,
        'clarity': clarity.toJson(),
        'structure': structure.toJson(),
        'confidence': confidence.toJson(),
        'who': who.toJson(),
        'what': what.toJson(),
        'why': why.toJson(),
        'good': good,
        'fix': fix,
        'stronger': stronger,
      };

  factory IntroEvaluation.fromJson(Map<String, dynamic> j) => IntroEvaluation(
        headline: j['headline'] as String,
        clarity: Dimension.fromJson(j['clarity'] as Map<String, dynamic>),
        structure: Dimension.fromJson(j['structure'] as Map<String, dynamic>),
        confidence: Dimension.fromJson(j['confidence'] as Map<String, dynamic>),
        who: PartCheck.fromJson(j['who'] as Map<String, dynamic>),
        what: PartCheck.fromJson(j['what'] as Map<String, dynamic>),
        why: PartCheck.fromJson(j['why'] as Map<String, dynamic>),
        good: j['good'] as String,
        fix: j['fix'] as String,
        stronger: j['stronger'] as String,
      );
}

/// Everything measured from the voice. Nothing here comes from a model's opinion.
class IntroDelivery {
  const IntroDelivery({
    required this.words,
    required this.speakingMs,
    required this.wpm,
    required this.fillerCount,
    required this.topFillers,
    required this.longestPause,
    required this.longPauses,
    required this.steadinessDb,
    required this.score,
  });

  final int words;
  final int speakingMs;
  final double? wpm;
  final int fillerCount;
  final Map<String, int> topFillers;

  /// The longest silence of at least a second while speaking; null when there was none.
  final Pause? longestPause;

  /// Silences long enough to cost points (2.5 seconds or more).
  final int longPauses;

  /// Spread of the voice level in dB; lower is steadier. Null when too little voice was heard.
  final double? steadinessDb;

  /// Measured delivery score; null when there was too little speech to judge.
  final int? score;

  double get fillersPer100Words => words == 0 ? 0 : fillerCount * 100 / words;

  Map<String, dynamic> toJson() => {
        'words': words,
        'speakingMs': speakingMs,
        'wpm': wpm,
        'fillerCount': fillerCount,
        'topFillers': topFillers,
        'longestPause': longestPause?.toJson(),
        'longPauses': longPauses,
        'steadinessDb': steadinessDb,
        'score': score,
      };

  factory IntroDelivery.fromJson(Map<String, dynamic> j) => IntroDelivery(
        words: j['words'] as int,
        speakingMs: j['speakingMs'] as int,
        wpm: (j['wpm'] as num?)?.toDouble(),
        fillerCount: j['fillerCount'] as int,
        topFillers: {for (final e in (j['topFillers'] as Map).entries) e.key as String: e.value as int},
        longestPause: j['longestPause'] == null ? null : Pause.fromJson(j['longestPause'] as Map<String, dynamic>),
        longPauses: j['longPauses'] as int,
        steadinessDb: (j['steadinessDb'] as num?)?.toDouble(),
        score: j['score'] as int?,
      );
}

/// Spoken intros weigh delivery in the score; typed ones are content only.
const contentWeight = 0.65;

int introScore(int content, int? delivery) =>
    delivery == null ? content : (contentWeight * content + (1 - contentWeight) * delivery).round();

class IntroRecord {
  const IntroRecord({
    required this.id,
    required this.startedAt,
    required this.durationMs,
    required this.mode,
    required this.transcript,
    required this.target,
    this.delivery,
    this.evaluation,
    this.audioFile,
    this.failed,
  });

  final String id;
  final DateTime startedAt;
  final int durationMs;
  final IntroMode mode;
  final String transcript;

  /// The role (and company) the intro was written for, so the "why" can be judged against it. May be empty.
  final String target;
  final IntroDelivery? delivery;
  final IntroEvaluation? evaluation;

  /// File name inside the intros folder; null for a typed intro.
  final String? audioFile;

  /// Set when scoring failed, so the result can offer a retry instead of nothing.
  final String? failed;

  int? get score => evaluation == null ? null : introScore(evaluation!.contentScore, delivery?.score);

  /// Only a spoken intro measures speaking, so only it feeds the speaking score and the progress chart.
  bool get countsAsSpeaking => mode == IntroMode.spoken && score != null;

  IntroRecord copyWith({IntroEvaluation? evaluation, String? failed, bool clearFailed = false}) => IntroRecord(
        id: id,
        startedAt: startedAt,
        durationMs: durationMs,
        mode: mode,
        transcript: transcript,
        target: target,
        delivery: delivery,
        evaluation: evaluation ?? this.evaluation,
        audioFile: audioFile,
        failed: clearFailed ? null : (failed ?? this.failed),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'durationMs': durationMs,
        'mode': mode.name,
        'transcript': transcript,
        'target': target,
        'delivery': delivery?.toJson(),
        'evaluation': evaluation?.toJson(),
        'audioFile': audioFile,
        'failed': failed,
      };

  factory IntroRecord.fromJson(Map<String, dynamic> j) => IntroRecord(
        id: j['id'] as String,
        startedAt: DateTime.parse(j['startedAt'] as String),
        durationMs: j['durationMs'] as int,
        mode: IntroMode.values.firstWhere((m) => m.name == j['mode'], orElse: () => IntroMode.spoken),
        transcript: j['transcript'] as String,
        target: (j['target'] as String?) ?? '',
        delivery: j['delivery'] == null ? null : IntroDelivery.fromJson(j['delivery'] as Map<String, dynamic>),
        evaluation: j['evaluation'] == null ? null : IntroEvaluation.fromJson(j['evaluation'] as Map<String, dynamic>),
        audioFile: j['audioFile'] as String?,
        failed: j['failed'] as String?,
      );
}
