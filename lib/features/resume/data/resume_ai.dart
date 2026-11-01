import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';

import '../../../core/ai/structured.dart';
import '../../../core/config/ai_config.dart';
import '../domain/match_models.dart';

Schema _str({bool nullable = false}) => Schema.string(nullable: nullable);

class ResumeAi {
  const ResumeAi();

  /// Reads the PDF directly (no Storage bucket needed) and returns the structured resume as JSON.
  Future<Map<String, dynamic>> parse(Uint8List pdf) {
    if (pdf.length > AiConfig.maxResumeBytes) throw AiException('That PDF is larger than 8 MB.');
    return generateStructured<Map<String, dynamic>>(
      model: AiConfig.textModel,
      system: 'Extract the resume into the schema exactly as written. Copy bullets verbatim. '
          'Use null for anything absent. Never infer or invent.',
      parts: [InlineDataPart('application/pdf', pdf), TextPart('Parse this resume.')],
      schema: Schema.object(
        properties: {
          'name': _str(),
          'skills': Schema.array(items: _str()),
          'education': Schema.array(items: _str()),
          'certifications': Schema.array(items: _str()),
          'experience': Schema.array(
            items: Schema.object(properties: {
              'company': _str(),
              'role': _str(),
              'bullets': Schema.array(items: _str()),
            }),
          ),
          'projects': Schema.array(
            items: Schema.object(properties: {
              'name': _str(),
              'tech': Schema.array(items: _str()),
              'bullets': Schema.array(items: _str()),
            }),
          ),
        },
      ),
      parse: (j) {
        if ((j['name'] as String).isEmpty) throw const FormatException('no name');
        return j;
      },
      temperature: 0,
    );
  }

  /// Every string in the parsed resume, flattened, for checking that cited evidence really is there.
  static String _resumeText(Object? node) => switch (node) {
        String s => s,
        List l => l.map(_resumeText).join('\n'),
        Map m => m.values.map(_resumeText).join('\n'),
        _ => '',
      };

  Future<MatchResult> match(Map<String, dynamic> resume, String jd) {
    return generateStructured<MatchResult>(
      model: AiConfig.textModel,
      system: 'You grade a resume against a job description. List every distinct skill or requirement the JD asks for '
          '(8 to 16 items, required vs preferred). For each: matched is true only if the resume states it or an exact '
          'synonym; relevance is 0 to 1 for how well the resume as a whole answers it even without the word; evidence '
          'is ONE verbatim line copied from the resume, or null if there is none. Never invent evidence. '
          'Rubric scores are 0 to 100: relevance to the role, impact (are results quantified), ATS formatting. '
          'Give 3 to 5 section notes with evidence, and the 5 highest-value fixes, most important first.',
      parts: [TextPart('RESUME JSON:\n${jsonEncode(resume)}\n\nJOB DESCRIPTION:\n$jd')],
      schema: Schema.object(
        properties: {
          'role': _str(),
          'requirements': Schema.array(
            items: Schema.object(
              properties: {
                'skill': _str(),
                'required': Schema.boolean(),
                'matched': Schema.boolean(),
                'relevance': Schema.number(),
                'evidence': _str(nullable: true),
              },
            ),
          ),
          'rubric': Schema.object(properties: {
            'relevance': Schema.integer(),
            'impact': Schema.integer(),
            'ats': Schema.integer(),
          }),
          'sections': Schema.array(
            items: Schema.object(
              properties: {'section': _str(), 'note': _str(), 'evidence': _str(nullable: true)},
            ),
          ),
          'fixes': Schema.array(items: _str()),
        },
      ),
      parse: (j) {
        final r = MatchResult.fromJson(j).withVerifiedEvidence(_resumeText(resume));
        if (r.requirements.isEmpty) throw const FormatException('no requirements');
        return r;
      },
      temperature: 0,
    );
  }

  /// Three rewrites. A rewrite that contains a number not in the original is rejected in code.
  Future<List<Rewrite>> rewrite(String bullet, String jd) {
    return generateStructured<List<Rewrite>>(
      model: AiConfig.fastModel,
      system: 'Rewrite the resume bullet three different ways. Each: a strong action verb, a quantified result and the '
          'impact. NEVER invent a number. Where a metric is missing write a bracket placeholder like [X%] or '
          '[N users] and list it in placeholders. Use a JD keyword only if the original bullet already states it or '
          'it is a plain synonym of something stated. Never add a technology, tool, domain, employer or scope the '
          'bullet does not mention: the candidate must be able to say every word in an interview.',
      parts: [TextPart('BULLET:\n$bullet\n\nJOB DESCRIPTION:\n$jd')],
      schema: Schema.object(properties: {
        'rewrites': Schema.array(
          items: Schema.object(properties: {'text': _str(), 'placeholders': Schema.array(items: _str())}),
        ),
      }),
      parse: (j) {
        final list = [for (final r in j['rewrites'] as List) Rewrite.fromJson(r as Map<String, dynamic>)];
        if (list.length < 3) throw const FormatException('fewer than 3 rewrites');
        if (list.any((r) => inventsNumbers(bullet, r.text))) throw const FormatException('invented a number');
        return list.take(3).toList();
      },
    );
  }
}
