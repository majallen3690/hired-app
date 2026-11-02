import 'package:firebase_ai/firebase_ai.dart';

import '../../../core/ai/structured.dart';
import '../../../core/config/ai_config.dart';
import '../domain/application_models.dart';
import '../domain/tracker_logic.dart';

class TrackerAi {
  const TrackerAi();

  /// Reads the company, role and key skills out of a pasted job description, then keeps only what the text says.
  Future<Autofill> autofill(String jd) {
    return generateStructured<Autofill>(
      model: AiConfig.fastModel,
      system: 'You read a job description pasted from a careers page or message. Return the hiring company, the job '
          'title, and the 5 to 8 most important skills, tools or technologies it asks for. Copy each skill the way '
          'the description writes it. Use an empty string for a company or title the text does not state. Never '
          'guess from the writing style and never add a skill that is not in the text.',
      parts: [TextPart(jd.length > 12000 ? jd.substring(0, 12000) : jd)],
      schema: Schema.object(properties: {
        'company': Schema.string(),
        'role': Schema.string(),
        'skills': Schema.array(items: Schema.string()),
      }),
      parse: (j) => verifyAutofill(
        jd,
        Autofill(
          company: (j['company'] as String?) ?? '',
          role: (j['role'] as String?) ?? '',
          skills: [for (final s in (j['skills'] as List? ?? const [])) s as String],
        ),
      ),
      temperature: 0,
    );
  }
}
