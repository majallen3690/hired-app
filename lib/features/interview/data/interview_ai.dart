import 'package:firebase_ai/firebase_ai.dart';

import '../../../core/ai/structured.dart';
import '../../../core/config/ai_config.dart';
import '../domain/evaluation_models.dart';
import '../domain/interview_models.dart';

Schema _str({bool nullable = false}) => Schema.string(nullable: nullable);

/// The parsed resume reduced to the facts an interviewer would have on the desk.
String resumeDigest(Map<String, dynamic> resume) {
  String list(Object? v) => (v is List ? v.whereType<String>().toList() : const <String>[]).join('; ');
  final b = StringBuffer('Name: ${resume['name']}\nSkills: ${list(resume['skills'])}\n');
  final edu = list(resume['education']);
  if (edu.isNotEmpty) b.writeln('Education: $edu');
  final certs = list(resume['certifications']);
  if (certs.isNotEmpty) b.writeln('Certifications: $certs');
  for (final p in (resume['projects'] as List? ?? const [])) {
    final m = p as Map<String, dynamic>;
    b.writeln('Project "${m['name']}" (${list(m['tech'])}): ${list(m['bullets'])}');
  }
  for (final e in (resume['experience'] as List? ?? const [])) {
    final m = e as Map<String, dynamic>;
    b.writeln('Experience ${m['role']} at ${m['company']}: ${list(m['bullets'])}');
  }
  return b.toString().trim();
}

String _roundBrief(InterviewRound r) => switch (r) {
      InterviewRound.hr => 'HR round: motivation, strengths and weaknesses, teamwork, a conflict, why this company.',
      InterviewRound.technical =>
        'Technical round: dig into their own projects (design choices, trade-offs, what broke), then one fundamentals '
            'question such as data structures, databases, networking or system design at their level.',
      InterviewRound.managerial =>
        'Managerial round: ownership, prioritising under a deadline, handling a failure, leading a small team.',
    };

String _styleBrief(CompanyStyle s) => switch (s) {
      CompanyStyle.product => 'a product company: values depth, ownership and clean thinking',
      CompanyStyle.service => 'an IT services company: values fundamentals, adaptability and communication',
      CompanyStyle.startup => 'a startup: values speed, breadth and initiative',
    };

String _difficultyBrief(Difficulty d) => switch (d) {
      Difficulty.warmup => 'Start gentle and encouraging.',
      Difficulty.real => 'Start at the level of a normal campus interview.',
      Difficulty.tough => 'Start demanding: probe for numbers, trade-offs and what they would do differently.',
    };

/// The system prompt for the live interviewer. Grounded in the candidate's own resume so it asks about their projects.
String buildPersona(InterviewConfig c, Map<String, dynamic> resume, {String? companyBrief}) {
  final hinglish = c.language == InterviewLang.hinglish;
  return '''
You are Rohan Mehta, a senior engineer interviewing a final-year student in an Indian campus placement drive.
Interview them for "${c.role}"${c.company.trim().isEmpty ? '' : ' at ${c.company.trim()}'}, ${_styleBrief(c.style)}.
${_roundBrief(c.round)}
${_difficultyBrief(c.difficulty)}
${companyBrief == null ? '' : 'What you know about the company: $companyBrief\n'}
Language: ${hinglish ? 'speak Hinglish, a natural mix of Hindi and English in Roman script, like a friendly Indian interviewer. The candidate may answer in either.' : 'speak clear, natural Indian English.'}

The candidate's resume (ask about THIS, never invent facts about them):
${resumeDigest(resume)}

How to run the interview:
- Open with a one-sentence greeting, then ask your first question about a specific project or experience on their resume.
- Ask exactly ${c.questionCount} main questions, ONE at a time. Keep every turn to one or two short sentences: this is a voice call.
- If an answer is vague or has no specifics, ask ONE follow-up on that same question, then move on.
- If they interrupt or ask you to repeat, handle it naturally. If they ask for a hint, give a small one.
- Never give feedback, praise or scores out loud. A neutral "okay" or "got it" is enough.
- After EVERY answer, call logAnswerSignal with quality 1 to 5 and a one-line note, before you speak again.
- Adapt: after two strong answers in a row, ask something harder. After two weak ones, make it easier.
- After the answer to question ${c.questionCount}, thank them in one sentence, then call endInterview.
'''
      .trim();
}

List<Tool> interviewTools() => [
      Tool.functionDeclarations([
        FunctionDeclaration(
          'logAnswerSignal',
          'Record a quick quality score for the candidate\'s last answer. Call after every answer.',
          parameters: {
            'quality': Schema.integer(description: '1 (poor) to 5 (excellent)'),
            'note': Schema.string(description: 'One short line on why'),
          },
        ),
        FunctionDeclaration(
          'endInterview',
          'Call once, after you have thanked the candidate following the final question.',
          parameters: {'reason': Schema.string(description: 'Always "completed"')},
        ),
      ]),
    ];

/// "[00:12] Interviewer: ..." lines, the form the evaluator reads.
String transcriptText(List<TranscriptTurn> turns) {
  String clock(int ms) {
    final s = ms ~/ 1000;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  return [
    for (final t in turns)
      '[${clock(t.startMs)}] ${t.speaker == Speaker.interviewer ? 'Interviewer' : 'Candidate'}: ${t.text}',
  ].join('\n');
}

class InterviewAi {
  const InterviewAi();

  Schema get _dim => Schema.object(properties: {'score': Schema.integer(), 'evidence': _str(nullable: true)});

  /// Rates every answered question. The model returns ratings and quotes; scores are computed in Dart and every
  /// quote is checked against what the candidate really said.
  Future<InterviewEvaluation> evaluate({
    required InterviewConfig config,
    required Map<String, dynamic> resume,
    required List<TranscriptTurn> turns,
  }) async {
    final candidateText = turns.where((t) => t.speaker == Speaker.candidate).map((t) => t.text).join('\n');
    final result = await generateStructured<InterviewEvaluation>(
      model: AiConfig.textModel,
      system: 'You evaluate a mock campus-placement interview. Read the transcript and the candidate\'s resume. '
          'Include only main questions the candidate actually answered; fold follow-ups into their question. '
          'For each: rate structure (is it a clear story, ideally STAR), relevance, depth and clarity from 1 to 5, '
          'each with an evidence quote copied VERBATIM from the candidate\'s answer (null if there is nothing to quote). '
          'Mark which STAR parts the answer covered. "good" is one thing they did well; "fix" is the single most '
          'valuable change; "modelAnswer" is a 2 to 3 sentence outline using ONLY facts on their resume, with '
          '[placeholders] where a number or detail is unknown. Never invent achievements. Be honest, not harsh. '
          'headline is at most 8 words. topFixes is exactly 3 concrete, specific actions, most important first.',
      parts: [
        TextPart('ROUND: ${config.round.name}, ${config.title}\n\nRESUME:\n${resumeDigest(resume)}\n\n'
            'TRANSCRIPT:\n${transcriptText(turns)}'),
      ],
      schema: Schema.object(properties: {
        'headline': _str(),
        'questions': Schema.array(
          items: Schema.object(properties: {
            'question': _str(),
            'structure': _dim,
            'relevance': _dim,
            'depth': _dim,
            'clarity': _dim,
            'situation': Schema.boolean(),
            'task': Schema.boolean(),
            'action': Schema.boolean(),
            'result': Schema.boolean(),
            'good': _str(),
            'fix': _str(),
            'modelAnswer': _str(),
          }),
        ),
        'topFixes': Schema.array(items: _str()),
      }),
      parse: (j) {
        final e = InterviewEvaluation.fromJson(j);
        if (e.questions.isEmpty) throw const FormatException('no questions rated');
        return e;
      },
      temperature: 0,
    );
    return result.withVerifiedEvidence(candidateText);
  }

  /// Standard-mode fallback: the questions up front, grounded in the resume.
  Future<List<String>> planQuestions({required InterviewConfig config, required Map<String, dynamic> resume}) {
    return generateStructured<List<String>>(
      model: AiConfig.fastModel,
      system: 'Write exactly ${config.questionCount} interview questions for a campus placement. ${_roundBrief(config.round)} '
          '${_difficultyBrief(config.difficulty)} Ground at least the first three in specific projects or experience on '
          'the resume. One sentence each, answerable in about two minutes. '
          '${config.language == InterviewLang.hinglish ? 'Write in Hinglish (Hindi and English in Roman script).' : ''}',
      parts: [TextPart('ROLE: ${config.title}\n\nRESUME:\n${resumeDigest(resume)}')],
      schema: Schema.object(properties: {'questions': Schema.array(items: _str())}),
      parse: (j) {
        final qs = [for (final q in j['questions'] as List) q as String];
        if (qs.length < config.questionCount) throw const FormatException('too few questions');
        return qs.take(config.questionCount).toList();
      },
      temperature: 0.4,
    );
  }
}
