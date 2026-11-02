import 'dart:math' as math;

import 'framing.dart';
import 'presence_models.dart';

int _clamp(num v) => v.round().clamp(0, 100);

/// Brightness of the face, 0 to 100. Null when no brightness was measured (a gallery photo).
/// Anything from a moderate to a fairly bright face scores full marks; very dark, washed out or backlit loses points.
int? lightingScore(FaceFrame f) {
  final face = f.lumaFace;
  if (face == null) return null;
  var score = 100.0 - math.max(0, (face - 0.55).abs() - 0.15) * 250;
  final back = f.lumaBackground;
  if (back != null && back > face) {
    final ratio = face / back;
    if (ratio < 0.85) score -= math.min(40, (0.85 - ratio) * 120);
  }
  return _clamp(score);
}

/// How well the face sits in the picture, 0 to 100. Null without a face position.
int? framingScore(FaceFrame f, Occasion o) {
  final box = f.box;
  if (box == null || !f.hasOneFace) return null;
  final size = faceSizeRange(o);
  final sizeErr = box.height < size.min ? size.min - box.height : (box.height > size.max ? box.height - size.max : 0.0);
  final centreErr = (box.centerX - 0.5).abs() + (box.centerY - targetCenterY).abs();
  return _clamp(100 - centreErr * 150 - sizeErr * 250);
}

/// Looking at the lens with eyes open, 0 to 100. Null without head angles.
int? eyeContactScore(FaceFrame f) {
  final yaw = f.yawDeg;
  if (yaw == null) return null;
  var score = 100.0 - math.max(0, yaw.abs() - 5) * 3 - math.max(0, (f.pitchDeg ?? 0).abs() - 8) * 2;
  final eyes = f.eyesOpen;
  if (eyes != null && eyes < 0.5) score -= 35;
  return _clamp(score);
}

/// A relaxed face is fine and a real smile is better: neutral scores 55, a clear smile 100. Null without a reading.
int? smileScore(FaceFrame f) {
  final s = f.smile;
  if (s == null) return null;
  return _clamp(55 + 45 * (s / 0.5).clamp(0.0, 1.0));
}

double? _mean(Iterable<(num?, double)> parts) {
  var sum = 0.0, weight = 0.0;
  for (final (v, w) in parts) {
    if (v == null) continue;
    sum += v * w;
    weight += w;
  }
  return weight == 0 ? null : sum / weight;
}

class PartScore {
  const PartScore({required this.part, required this.value, required this.measured, required this.observed});
  final PresencePart part;
  final int value;

  /// What was measured on the phone, or null when nothing was.
  final String? measured;

  /// What the model saw in the photo, or null when it is not visible.
  final String? observed;
}

class PresenceResult {
  const PresenceResult({required this.score, required this.parts, required this.fixes});
  final int score;
  final List<PartScore> parts;
  final List<Fix> fixes;
}

/// The highest rating an area can have when a fix is suggested for it.
const maxRatingWithFix = 4;

String _percent(double v) => '${(v * 100).round()}%';

/// Combines what was measured with the model's reading. Each area states which is which, so no number rests on a
/// guess: a rating is the model's, a percentage is the phone's.
///
/// - Attire and grooming are the model's rating only (attire is left out when clothes are not in the photo).
/// - Light and background are half measured brightness, half the model's view of the background.
/// - Expression is half the model's rating, a quarter measured smile and a quarter measured gaze.
PresenceResult scorePresence(Occasion occasion, FaceFrame frame, PresenceEvaluation eval) {
  // Models rate generously. An area cannot be perfect when the same model also says what to fix in it, so a fix caps
  // that area's rating at 4.
  final fixed = {for (final f in eval.fixes) f.area};
  Rated capped(Rated r, Set<FixArea> areas) =>
      r.rating > maxRatingWithFix && fixed.any(areas.contains) ? Rated(rating: maxRatingWithFix, observation: r.observation) : r;
  eval = PresenceEvaluation(
    attire: eval.attire == null ? null : capped(eval.attire!, {FixArea.attire}),
    grooming: capped(eval.grooming, {FixArea.grooming}),
    background: capped(eval.background, {FixArea.background, FixArea.lighting}),
    expression: capped(eval.expression, {FixArea.expression}),
    fixes: eval.fixes,
  );

  final lighting = lightingScore(frame);
  final gaze = eyeContactScore(frame);
  final smile = smileScore(frame);

  final lightValue = _mean([(lighting, 1), (eval.background.rating * 20, 1)])!;
  final expressionValue = _mean([(eval.expression.rating * 20, 2), (smile, 1), (gaze, 1)])!;

  String? lightMeasured;
  if (frame.lumaFace != null) {
    lightMeasured = 'Face light ${_percent(frame.lumaFace!)}';
    final back = frame.lumaBackground;
    if (back != null && back > 0.4 && frame.lumaFace! < back * backlitRatio) lightMeasured += ', light behind you';
  }

  String? expressionMeasured;
  final bits = [
    if (frame.smile != null) 'smile ${_percent(frame.smile!)}',
    if (frame.eyesOpen != null) 'eyes ${frame.eyesOpen! >= 0.5 ? 'open' : 'closed'}',
    if (frame.yawDeg != null) 'head ${frame.yawDeg!.abs() <= maxYawDeg ? 'facing the camera' : 'turned away'}',
  ];
  if (bits.isNotEmpty) expressionMeasured = 'Measured: ${bits.join(', ')}';

  final parts = <PartScore>[
    if (eval.attire != null)
      PartScore(part: PresencePart.attire, value: _clamp(eval.attire!.rating * 20), measured: null, observed: eval.attire!.observation),
    PartScore(part: PresencePart.grooming, value: _clamp(eval.grooming.rating * 20), measured: null, observed: eval.grooming.observation),
    PartScore(
      part: PresencePart.lighting,
      value: _clamp(lightValue),
      measured: lightMeasured == null ? null : 'Measured: $lightMeasured',
      observed: eval.background.observation,
    ),
    PartScore(part: PresencePart.expression, value: _clamp(expressionValue), measured: expressionMeasured, observed: eval.expression.observation),
  ];

  final weights = occasion.weights;
  final score = _clamp(_mean([for (final p in parts) (p.value, weights[p.part]!)])!);
  return PresenceResult(score: score, parts: parts, fixes: buildFixes(occasion, frame, eval));
}

/// The three fixes. Problems the phone measured come first, because they are certain; the model's suggestions fill
/// the rest, one per area, so the list never says the same thing twice.
List<Fix> buildFixes(Occasion occasion, FaceFrame frame, PresenceEvaluation eval) {
  final out = <Fix>[];
  final seen = <FixArea>{};
  void add(Fix f) {
    if (out.length < 3 && seen.add(f.area)) out.add(f);
  }

  final light = lightingScore(frame);
  final back = frame.lumaBackground;
  if (frame.lumaFace != null && back != null && back > 0.4 && frame.lumaFace! < back * backlitRatio) {
    add(const Fix(area: FixArea.lighting, text: 'Light is behind you. Turn to face a window or lamp so your face is lit.'));
  } else if (light != null && light < 60) {
    add(Fix(
      area: FixArea.lighting,
      text: frame.lumaFace! < 0.5
          ? 'Your face is dark. Sit facing a window or put a lamp in front of you.'
          : 'Your face is washed out. Move away from the strongest light or dim it.',
    ));
  }

  final framing = framingScore(frame, occasion);
  final box = frame.box;
  if (framing != null && framing < 70 && box != null) {
    final size = faceSizeRange(occasion);
    add(Fix(
      area: FixArea.framing,
      text: box.height < size.min
          ? 'Move closer so your face and shoulders fill the frame.'
          : (box.height > size.max ? 'Move back a little so your shoulders are in the picture.' : 'Centre your face in the frame.'),
    ));
  }

  final gaze = eyeContactScore(frame);
  if (gaze != null && gaze < 65) {
    add(const Fix(area: FixArea.expression, text: 'Look straight into the lens, not at the screen, so it reads as eye contact.'));
  }

  for (final f in eval.fixes) {
    add(f);
  }
  return out;
}

/// "Interview ready", "Almost there" or "Needs work".
String verdict(Occasion o, int score) => score >= 75 ? o.readyLabel : (score >= 50 ? 'Almost there' : 'Needs work');
