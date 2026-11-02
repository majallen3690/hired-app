enum CompanyStyle { product, service, startup }

enum InterviewRound { hr, technical, managerial }

enum Difficulty { warmup, real, tough }

enum InterviewLang { english, hinglish }

enum Speaker { interviewer, candidate }

/// live = Gemini Live voice session; standard = question by question fallback.
enum SessionMode { live, standard }

T _byName<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.firstWhere((v) => v.name == name, orElse: () => fallback);

class InterviewConfig {
  const InterviewConfig({
    required this.role,
    this.company = '',
    this.style = CompanyStyle.product,
    this.round = InterviewRound.technical,
    this.difficulty = Difficulty.real,
    this.language = InterviewLang.english,
    this.questionCount = 5,
  });

  final String role;
  final String company;
  final CompanyStyle style;
  final InterviewRound round;
  final Difficulty difficulty;
  final InterviewLang language;
  final int questionCount;

  String get title => company.trim().isEmpty ? role : '$role at ${company.trim()}';

  InterviewConfig copyWith({
    String? role,
    String? company,
    CompanyStyle? style,
    InterviewRound? round,
    Difficulty? difficulty,
    InterviewLang? language,
  }) =>
      InterviewConfig(
        role: role ?? this.role,
        company: company ?? this.company,
        style: style ?? this.style,
        round: round ?? this.round,
        difficulty: difficulty ?? this.difficulty,
        language: language ?? this.language,
        questionCount: questionCount,
      );

  Map<String, dynamic> toJson() => {
        'role': role,
        'company': company,
        'style': style.name,
        'round': round.name,
        'difficulty': difficulty.name,
        'language': language.name,
        'questionCount': questionCount,
      };

  factory InterviewConfig.fromJson(Map<String, dynamic> j) => InterviewConfig(
        role: j['role'] as String,
        company: (j['company'] as String?) ?? '',
        style: _byName(CompanyStyle.values, j['style'], CompanyStyle.product),
        round: _byName(InterviewRound.values, j['round'], InterviewRound.technical),
        difficulty: _byName(Difficulty.values, j['difficulty'], Difficulty.real),
        language: _byName(InterviewLang.values, j['language'], InterviewLang.english),
        questionCount: (j['questionCount'] as int?) ?? 5,
      );
}

/// One continuous stretch of speech by one side, on the session clock (milliseconds from start).
class TranscriptTurn {
  const TranscriptTurn({
    required this.speaker,
    required this.text,
    required this.startMs,
    required this.endMs,
    this.typed = false,
  });

  final Speaker speaker;
  final String text;
  final int startMs;
  final int endMs;

  /// Typed instead of spoken: it has no speaking time, so it is left out of pace and filler measurements.
  final bool typed;

  int get durationMs => endMs - startMs;

  TranscriptTurn copyWith({String? text, int? endMs}) => TranscriptTurn(
      speaker: speaker, text: text ?? this.text, startMs: startMs, endMs: endMs ?? this.endMs, typed: typed);

  Map<String, dynamic> toJson() =>
      {'speaker': speaker.name, 'text': text, 'startMs': startMs, 'endMs': endMs, 'typed': typed};

  factory TranscriptTurn.fromJson(Map<String, dynamic> j) => TranscriptTurn(
        speaker: _byName(Speaker.values, j['speaker'], Speaker.candidate),
        text: j['text'] as String,
        startMs: j['startMs'] as int,
        endMs: j['endMs'] as int,
        typed: (j['typed'] as bool?) ?? false,
      );
}

/// The interviewer's quick judgement of one answer, logged through the `logAnswerSignal` tool call.
class AnswerSignal {
  const AnswerSignal({required this.atMs, required this.quality, required this.note});
  final int atMs;
  final int quality;
  final String note;

  Map<String, dynamic> toJson() => {'atMs': atMs, 'quality': quality, 'note': note};

  factory AnswerSignal.fromJson(Map<String, dynamic> j) =>
      AnswerSignal(atMs: j['atMs'] as int, quality: j['quality'] as int, note: (j['note'] as String?) ?? '');
}

/// A stretch of silence while the candidate had the floor.
class Pause {
  const Pause({required this.startMs, required this.endMs});
  final int startMs;
  final int endMs;
  int get lengthMs => endMs - startMs;

  Map<String, dynamic> toJson() => {'startMs': startMs, 'endMs': endMs};
  factory Pause.fromJson(Map<String, dynamic> j) => Pause(startMs: j['startMs'] as int, endMs: j['endMs'] as int);
}
