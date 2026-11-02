import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';

import '../../../core/ai/structured.dart';
import '../../../core/config/ai_config.dart';
import '../../interview/data/interview_ai.dart' show resumeDigest;
import '../../resume/domain/match_models.dart' show inventsNumbers;
import '../domain/intro_models.dart';

Schema _str({bool nullable = false}) => Schema.string(nullable: nullable);

class IntroAi {
  const IntroAi();

  /// Speech to text. Fillers are kept on purpose: they are what the filler count is measured from.
  Future<String> transcribe(Uint8List wav) {
    return generateStructured<String>(
      model: AiConfig.textModel,
      system: 'You transcribe a short recording of a student introducing themselves. Write exactly what was said, '
          'word for word, in the language spoken (Hindi in Roman script if they spoke Hindi). Keep every filler '
          'word and false start such as um, uh, like, you know, basically, actually, matlab. Do not correct '
          'grammar, do not summarise and do not add words that were not spoken. If there is no speech, return an '
          'empty string.',
      parts: [InlineDataPart('audio/wav', wav), TextPart('Transcribe this recording.')],
      schema: Schema.object(properties: {'transcript': _str()}),
      parse: (j) => (j['transcript'] as String).trim(),
      temperature: 0,
    );
  }

  Schema get _dim => Schema.object(properties: {'score': Schema.integer(), 'evidence': _str(nullable: true)});

  Schema get _part => Schema.object(properties: {
        'covered': Schema.boolean(),
        'evidence': _str(nullable: true),
        'note': _str(),
      });

  /// Rates the words of the intro. The model returns ratings and quotes; scores are computed in Dart and every quote
  /// is checked against the transcript.
  Future<IntroEvaluation> evaluate({
    required String transcript,
    required String target,
    Map<String, dynamic>? resume,
  }) async {
    final digest = resume == null ? '' : resumeDigest(resume);
    // Anything in these may be repeated in the stronger version; any other number is invented.
    final knownFacts = '$transcript\n$digest\n$target';
    final result = await generateStructured<IntroEvaluation>(
      model: AiConfig.textModel,
      system: 'You coach a final-year Indian engineering student on their 60-second self-introduction for campus '
          'placement interviews. Judge ONLY the words in the transcript. '
          'Rate clarity (is it easy to follow and specific), structure (does it flow who, what, why) and confidence '
          '(direct, owned language rather than hedging like "I think maybe" or "just") from 1 to 5, each with an '
          'evidence quote copied VERBATIM from the transcript, or null if there is nothing to quote. '
          'Then check three parts. WHO: name plus year, college or branch. WHAT: a concrete thing they built, studied '
          'or did. WHY: a reason for this role, company or field. For each, covered is true only if the transcript '
          'says it, with a verbatim quote; otherwise covered is false, evidence is null and note says what is missing. '
          'good is one thing they did well. fix is the single most valuable change. headline is at most 8 words. '
          'stronger is a rewrite of at most 130 words, first person, in spoken English, using ONLY facts from the '
          'transcript, the resume or the target below. Put [X] or [a short placeholder] where a number or detail is '
          'unknown. Never invent an employer, college, project, technology or number. If WHY is missing and a target '
          'is given, add a why sentence that uses the target; if there is no target, write [why you want this role]. '
          'Be honest, not harsh.',
      parts: [
        TextPart('TARGET ROLE: ${target.isEmpty ? 'not given' : target}\n\n'
            '${digest.isEmpty ? '' : 'RESUME:\n$digest\n\n'}TRANSCRIPT:\n$transcript'),
      ],
      schema: Schema.object(properties: {
        'headline': _str(),
        'clarity': _dim,
        'structure': _dim,
        'confidence': _dim,
        'who': _part,
        'what': _part,
        'why': _part,
        'good': _str(),
        'fix': _str(),
        'stronger': _str(),
      }),
      parse: (j) {
        final e = IntroEvaluation.fromJson(j);
        if (e.stronger.trim().isEmpty) throw const FormatException('no stronger version');
        if (inventsNumbers(knownFacts, e.stronger)) throw const FormatException('invented a number');
        return e;
      },
      temperature: 0,
    );
    return result.withVerifiedEvidence(transcript);
  }
}
