import '../../../core/scoring/evidence.dart';
import 'interview_models.dart';

/// One 1 to 5 rating plus the line from the candidate's answer that justifies it.
class Dimension {
  const Dimension({required this.score, this.evidence});
  final int score;
  final String? evidence;

  Map<String, dynamic> toJson() => {'score': score, 'evidence': evidence};

  factory Dimension.fromJson(Map<String, dynamic> j) =>
      Dimension(score: ((j['score'] as num).round()).clamp(1, 5), evidence: j['evidence'] as String?);
}

class QuestionEval {
  const QuestionEval({
    required this.question,
    required this.structure,
    required this.relevance,
    required this.depth,
    required this.clarity,
    required this.situation,
    required this.task,
    required this.action,
    required this.result,
    required this.good,
    required this.fix,
    required this.modelAnswer,
  });

  final String question;
  final Dimension structure;
  final Dimension relevance;
  final Dimension depth;
  final Dimension clarity;

  /// STAR completeness: did the answer cover each part.
  final bool situation;
  final bool task;
  final bool action;
  final bool result;

  final String good;
  final String fix;
  final String modelAnswer;

  List<(String, Dimension)> get dimensions =>
      [('Structure', structure), ('Relevance', relevance), ('Depth', depth), ('Clarity', clarity)];

  double get score => dimensions.fold<double>(0, (s, d) => s + d.$2.score) / 4;

  Map<String, dynamic> toJson() => {
        'question': question,
        'structure': structure.toJson(),
        'relevance': relevance.toJson(),
        'depth': depth.toJson(),
        'clarity': clarity.toJson(),
        'situation': situation,
        'task': task,
        'action': action,
        'result': result,
        'good': good,
        'fix': fix,
        'modelAnswer': modelAnswer,
      };

  factory QuestionEval.fromJson(Map<String, dynamic> j) => QuestionEval(
        question: j['question'] as String,
        structure: Dimension.fromJson(j['structure'] as Map<String, dynamic>),
        relevance: Dimension.fromJson(j['relevance'] as Map<String, dynamic>),
        depth: Dimension.fromJson(j['depth'] as Map<String, dynamic>),
        clarity: Dimension.fromJson(j['clarity'] as Map<String, dynamic>),
        situation: j['situation'] as bool,
        task: j['task'] as bool,
        action: j['action'] as bool,
        result: j['result'] as bool,
        good: j['good'] as String,
        fix: j['fix'] as String,
        modelAnswer: j['modelAnswer'] as String,
      );
}

/// The model supplies per-answer ratings and quotes. Every number shown is computed here from them.
class InterviewEvaluation {
  const InterviewEvaluation({required this.headline, required this.questions, required this.topFixes});

  final String headline;
  final List<QuestionEval> questions;
  final List<String> topFixes;

  /// 0 to 100: mean of all answers' four ratings, scaled from 1..5.
  int get interviewScore {
    if (questions.isEmpty) return 0;
    final mean = questions.fold<double>(0, (s, q) => s + q.score) / questions.length;
    return (mean * 20).round();
  }

  /// A rating whose quote is not really in the candidate's words is capped at 3 and loses the quote,
  /// so no score rests on something the candidate never said.
  InterviewEvaluation withVerifiedEvidence(String candidateText) {
    Dimension fix(Dimension d) =>
        quoteIsGrounded(d.evidence, candidateText) ? d : Dimension(score: d.score > 3 ? 3 : d.score, evidence: null);

    return InterviewEvaluation(
      headline: headline,
      topFixes: topFixes,
      questions: [
        for (final q in questions)
          QuestionEval(
            question: q.question,
            structure: fix(q.structure),
            relevance: fix(q.relevance),
            depth: fix(q.depth),
            clarity: fix(q.clarity),
            situation: q.situation,
            task: q.task,
            action: q.action,
            result: q.result,
            good: q.good,
            fix: q.fix,
            modelAnswer: q.modelAnswer,
          ),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
        'headline': headline,
        'questions': [for (final q in questions) q.toJson()],
        'topFixes': topFixes,
      };

  factory InterviewEvaluation.fromJson(Map<String, dynamic> j) => InterviewEvaluation(
        headline: j['headline'] as String,
        questions: [for (final q in j['questions'] as List) QuestionEval.fromJson(q as Map<String, dynamic>)],
        topFixes: [for (final f in j['topFixes'] as List) f as String],
      );
}

/// Everything saved for one finished session, enough to reopen its report and Coach Replay.
class SessionRecord {
  const SessionRecord({
    required this.id,
    required this.startedAt,
    required this.durationMs,
    required this.config,
    required this.mode,
    required this.turns,
    required this.signals,
    required this.pauses,
    this.evaluation,
    this.audioFile,
    this.communication,
    this.failedEvaluation,
  });

  final String id;
  final DateTime startedAt;
  final int durationMs;
  final InterviewConfig config;
  final SessionMode mode;
  final List<TranscriptTurn> turns;
  final List<AnswerSignal> signals;
  final List<Pause> pauses;
  final InterviewEvaluation? evaluation;

  /// File name inside the sessions folder; null when nothing was recorded (standard mode).
  final String? audioFile;

  /// Measured communication score; null when there was too little speech to judge.
  final int? communication;

  /// Set when the evaluation call failed, so the report can offer a retry instead of nothing.
  final String? failedEvaluation;

  SessionRecord copyWith({InterviewEvaluation? evaluation, int? communication, String? failedEvaluation}) => SessionRecord(
        id: id,
        startedAt: startedAt,
        durationMs: durationMs,
        config: config,
        mode: mode,
        turns: turns,
        signals: signals,
        pauses: pauses,
        evaluation: evaluation ?? this.evaluation,
        audioFile: audioFile,
        communication: communication ?? this.communication,
        failedEvaluation: failedEvaluation,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'durationMs': durationMs,
        'config': config.toJson(),
        'mode': mode.name,
        'turns': [for (final t in turns) t.toJson()],
        'signals': [for (final s in signals) s.toJson()],
        'pauses': [for (final p in pauses) p.toJson()],
        'evaluation': evaluation?.toJson(),
        'audioFile': audioFile,
        'communication': communication,
        'failedEvaluation': failedEvaluation,
      };

  factory SessionRecord.fromJson(Map<String, dynamic> j) => SessionRecord(
        id: j['id'] as String,
        startedAt: DateTime.parse(j['startedAt'] as String),
        durationMs: j['durationMs'] as int,
        config: InterviewConfig.fromJson(j['config'] as Map<String, dynamic>),
        mode: SessionMode.values.firstWhere((m) => m.name == j['mode'], orElse: () => SessionMode.live),
        turns: [for (final t in j['turns'] as List) TranscriptTurn.fromJson(t as Map<String, dynamic>)],
        signals: [for (final s in j['signals'] as List) AnswerSignal.fromJson(s as Map<String, dynamic>)],
        pauses: [for (final p in j['pauses'] as List) Pause.fromJson(p as Map<String, dynamic>)],
        evaluation: j['evaluation'] == null ? null : InterviewEvaluation.fromJson(j['evaluation'] as Map<String, dynamic>),
        audioFile: j['audioFile'] as String?,
        communication: j['communication'] as int?,
        failedEvaluation: j['failedEvaluation'] as String?,
      );
}
