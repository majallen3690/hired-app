import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';

import '../../../core/ai/structured.dart';
import '../../../core/config/ai_config.dart';
import '../domain/presence_models.dart';

class PresenceAi {
  const PresenceAi();

  Schema get _rated => Schema.object(properties: {'rating': Schema.integer(), 'observation': Schema.string()});

  /// Reads one photo for the occasion. It is told to rate only what a person can change in a minute, and never a
  /// person's face or body. Lighting is measured on the phone, so the model is not asked to score it.
  Future<PresenceEvaluation> evaluate(Uint8List jpeg, Occasion occasion) {
    return generateStructured<PresenceEvaluation>(
      model: AiConfig.textModel,
      system: 'You review a photo a student took to check how they present for this occasion: ${occasion.title}. '
          'Rate ONLY things they can change in a minute: attire (is the clothing neat and suitable for the occasion), '
          'grooming (is hair and appearance neat and tidy), background (clutter and distractions behind them) and '
          'expression (relaxed, engaged, natural). Rate each 1 to 5 and describe in at most 14 words what you can '
          'actually see. Never comment on, rate or infer age, gender, race, body, health, disability or how '
          'attractive anyone is, and never rate a face or features themselves. If clothes are not visible, for '
          'example a tight crop of the face, set attire to null. fixes: exactly 3 concrete, kind, actionable '
          'suggestions, one per area, each area one of lighting, background, attire, grooming, expression, framing. '
          'Brightness is measured separately, so mention lighting only if it is plainly visible in the photo. '
          'Be honest but encouraging, and use the whole range: 3 is a fine, ordinary result, most real photos deserve 3 or 4, '
          'and 5 is only for an area with nothing at all to improve. If you suggest a fix for an area, its rating is at most 4. '
          'Judge only what is in the photo.',
      parts: [InlineDataPart('image/jpeg', jpeg), TextPart('Occasion: ${occasion.title}.')],
      schema: Schema.object(
        properties: {
          'attire': Schema.object(properties: {'rating': Schema.integer(), 'observation': Schema.string()}, nullable: true),
          'grooming': _rated,
          'background': _rated,
          'expression': _rated,
          'fixes': Schema.array(
            items: Schema.object(properties: {
              'area': Schema.enumString(enumValues: [for (final a in FixArea.values) a.name]),
              'text': Schema.string(),
            }),
          ),
        },
      ),
      parse: (j) {
        final e = PresenceEvaluation.fromJson(j);
        if (e.fixes.isEmpty) throw const FormatException('no fixes');
        return e;
      },
      temperature: 0,
    );
  }
}
