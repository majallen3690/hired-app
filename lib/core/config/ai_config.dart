/// Model names for Firebase AI Logic with the Gemini Developer API (free tier, Spark plan, no key in the app).
/// Change them here if Google retires a model.
class AiConfig {
  const AiConfig._();

  /// Parsing, matching, grading, interview evaluation.
  static const textModel = 'gemini-3.5-flash';

  /// Quick scoring: rewrites, intro, tracker autofill.
  static const fastModel = 'gemini-3.5-flash-lite';

  static const liveModel = 'gemini-3.1-flash-live-preview';
  static const liveModelFallback = 'gemini-2.5-flash-native-audio-preview-12-2025';

  static const maxResumeBytes = 8 * 1024 * 1024;
}
