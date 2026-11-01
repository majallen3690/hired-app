import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';

/// Structured Gemini call: JSON mime type + response schema, validated by [parse], one retry on failure.
/// Never parses free text. A thrown [AiException] carries a message that is safe to show the user.
class AiException implements Exception {
  AiException(this.message);
  final String message;
  @override
  String toString() => message;
}

Future<T> generateStructured<T>({
  required String model,
  required String system,
  required List<Part> parts,
  required Schema schema,
  required T Function(Map<String, dynamic> json) parse,
  double temperature = 0.2,
}) async {
  final m = FirebaseAI.googleAI().generativeModel(
    model: model,
    systemInstruction: Content.system(system),
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: schema,
      temperature: temperature,
    ),
  );

  Object? lastError;
  for (var attempt = 0; attempt < 2; attempt++) {
    try {
      final extra = attempt == 0 ? <Part>[] : <Part>[TextPart('Previous output was invalid ($lastError). Return valid JSON.')];
      final res = await m.generateContent([Content.multi([...parts, ...extra])]);
      final text = res.text;
      if (text == null || text.isEmpty) throw const FormatException('empty response');
      return parse(jsonDecode(text) as Map<String, dynamic>);
    } on FormatException catch (e) {
      lastError = e;
    } on TypeError catch (e) {
      lastError = e;
    } on FirebaseAIException catch (e) {
      throw AiException(_friendly(e.message));
    }
  }
  throw AiException('The AI returned an unreadable answer twice. Try again.');
}

String _friendly(String raw) {
  final r = raw.toLowerCase();
  if (r.contains('quota') || r.contains('429') || r.contains('rate')) {
    return 'The free AI quota is used up for now. Try again in a minute.';
  }
  if (r.contains('api has not been used') || r.contains('not enabled') || r.contains('permission')) {
    return 'Firebase AI Logic is not switched on for this project yet.';
  }
  if (r.contains('network') || r.contains('unavailable') || r.contains('socket')) {
    return 'No connection. Check your internet and try again.';
  }
  return 'The AI request failed. Try again.';
}
