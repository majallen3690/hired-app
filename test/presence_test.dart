import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hired/features/presence/domain/framing.dart';
import 'package:hired/features/presence/domain/presence_models.dart';
import 'package:hired/features/presence/domain/presence_scoring.dart';

const centred = Box(left: 0.32, top: 0.22, right: 0.68, bottom: 0.58); // height 0.36, centre (0.5, 0.40)

FaceFrame face({
  Box? box = centred,
  int count = 1,
  double? roll = 0,
  double? yaw = 0,
  double? pitch = 0,
  double? smile = 0.4,
  double? eyes = 0.9,
  double? luma = 0.55,
  double? back = 0.55,
}) =>
    FaceFrame(
      faceCount: count,
      box: box,
      rollDeg: roll,
      yawDeg: yaw,
      pitchDeg: pitch,
      smile: smile,
      leftEyeOpen: eyes,
      rightEyeOpen: eyes,
      lumaFace: luma,
      lumaBackground: back,
    );

Rated rated(int r, [String o = 'ok']) => Rated(rating: r, observation: o);

PresenceEvaluation eval({
  int attire = 4,
  int grooming = 4,
  int background = 4,
  int expression = 4,
  bool showClothes = true,
  List<Fix> fixes = const [],
}) =>
    PresenceEvaluation(
      attire: showClothes ? rated(attire, 'Collared shirt') : null,
      grooming: rated(grooming, 'Neat hair'),
      background: rated(background, 'Plain wall'),
      expression: rated(expression, 'Relaxed'),
      fixes: fixes,
    );

void main() {
  group('live framing guide', () {
    test('no face means one instruction', () {
      final c = framingChecks(null, Occasion.interview);
      expect(c.length, 1);
      expect(c.single.message, 'Move your face into the oval');
      expect(readyToShoot(c), isFalse);
    });

    test('a good frame passes all three checks', () {
      final c = framingChecks(face(), Occasion.interview);
      expect(c.map((x) => x.kind), [CheckKind.framing, CheckKind.light, CheckKind.pose]);
      expect(c.every((x) => x.ok), isTrue);
      expect(readyToShoot(c), isTrue);
    });

    test('more than one face is called out', () {
      expect(framingChecks(face(count: 2), Occasion.interview).single.message, 'Only one person in the frame');
    });

    test('too far, too close and off centre each say so', () {
      const small = Box(left: 0.4, top: 0.3, right: 0.6, bottom: 0.45);
      const big = Box(left: 0.1, top: 0.0, right: 0.9, bottom: 0.9);
      const side = Box(left: 0.62, top: 0.22, right: 0.98, bottom: 0.58);
      expect(framingChecks(face(box: small), Occasion.interview).first.message, 'Move a little closer');
      expect(framingChecks(face(box: big), Occasion.interview).first.message, 'Move back a little');
      expect(framingChecks(face(box: side), Occasion.interview).first.message, 'Centre your face in the oval');
    });

    test('a LinkedIn photo wants the face a little bigger than an interview', () {
      expect(framingChecks(face(), Occasion.linkedin).first.ok, isTrue);
      const medium = Box(left: 0.36, top: 0.27, right: 0.64, bottom: 0.55); // height 0.28
      expect(framingChecks(face(box: medium), Occasion.interview).first.ok, isTrue);
      expect(framingChecks(face(box: medium), Occasion.linkedin).first.message, 'Move a little closer');
    });

    test('light problems: dark, washed out, and backlit', () {
      expect(framingChecks(face(luma: 0.15, back: 0.2), Occasion.interview)[1].message, 'Too dark. Face a light');
      expect(framingChecks(face(luma: 0.92, back: 0.9), Occasion.interview)[1].message, 'Too bright. Move away from the light');
      final back = framingChecks(face(luma: 0.3, back: 0.8), Occasion.interview)[1];
      expect(back.ok, isFalse);
      expect(back.message, startsWith('Light is behind you'));
    });

    test('a dim room is dark, not backlit, when the background is dim too', () {
      expect(framingChecks(face(luma: 0.2, back: 0.25), Occasion.interview)[1].message, 'Too dark. Face a light');
    });

    test('head tilt reports how far, and looking away is called out', () {
      expect(framingChecks(face(roll: 12.4), Occasion.interview)[2].message, 'Level your head (12° off)');
      expect(framingChecks(face(yaw: 25), Occasion.interview)[2].message, 'Look straight at the camera');
      expect(framingChecks(face(pitch: 22), Occasion.interview)[2].message, 'Keep your chin level');
    });

    test('with no brightness reading it cannot be ready yet', () {
      final c = framingChecks(face(luma: null, back: null, roll: null, yaw: null, pitch: null), Occasion.interview);
      expect(c.length, 1);
      expect(readyToShoot(c), isFalse);
    });

    test('ready only after the frame has been good for a moment', () {
      final s = StableReady(hold: const Duration(milliseconds: 700));
      final t = DateTime(2026, 11, 2, 10);
      expect(s.update(true, t), isFalse);
      expect(s.update(true, t.add(const Duration(milliseconds: 400))), isFalse);
      expect(s.update(true, t.add(const Duration(milliseconds: 800))), isTrue);
      expect(s.update(false, t.add(const Duration(milliseconds: 900))), isFalse);
      expect(s.update(true, t.add(const Duration(milliseconds: 1000))), isFalse); // the clock restarted
    });
  });

  group('brightness from a camera frame', () {
    test('rotation maps raw positions to the upright picture', () {
      expect(rawToUpright(0.2, 0.7, 0), (x: 0.2, y: 0.7));
      final r90 = rawToUpright(0.2, 0.7, 90);
      expect(r90.x, closeTo(0.3, 1e-9));
      expect(r90.y, closeTo(0.2, 1e-9));
      final r180 = rawToUpright(0.2, 0.7, 180);
      expect(r180.x, closeTo(0.8, 1e-9));
      expect(r180.y, closeTo(0.3, 1e-9));
      final r270 = rawToUpright(0.2, 0.7, 270);
      expect(r270.x, closeTo(0.7, 1e-9));
      expect(r270.y, closeTo(0.8, 1e-9));
    });

    test('a bright face on a dark wall is measured as such, whichever way the frame is stored', () {
      for (final rotation in [0, 90, 180, 270]) {
        final rawW = rotation.isEven ? 60 : 80;
        final rawH = rotation.isEven ? 80 : 60;
        final data = Uint8List(rawW * rawH);
        const box = Box(left: 0.3, top: 0.3, right: 0.7, bottom: 0.7);
        for (var y = 0; y < rawH; y++) {
          for (var x = 0; x < rawW; x++) {
            final up = rawToUpright(x / rawW, y / rawH, rotation);
            data[y * rawW + x] = box.contains(up.x, up.y) ? 200 : 40;
          }
        }
        final r = lumaSplit(yPlane: data, width: rawW, height: rawH, rowStride: rawW, rotation: rotation, box: box, step: 2)!;
        expect(r.face, closeTo(200 / 255, 0.02), reason: 'rotation $rotation');
        expect(r.background, closeTo(40 / 255, 0.02), reason: 'rotation $rotation');
      }
    });

    test('a box that covers nothing gives no reading', () {
      final data = Uint8List(100 * 100)..fillRange(0, 100 * 100, 128);
      expect(
        lumaSplit(
          yPlane: data,
          width: 100,
          height: 100,
          rowStride: 100,
          rotation: 0,
          box: const Box(left: 0, top: 0, right: 0, bottom: 0),
          step: 7,
        ),
        isNull,
      );
    });

    test('row padding in the frame is skipped, not read as picture', () {
      final data = Uint8List(16 * 10);
      for (var y = 0; y < 10; y++) {
        for (var x = 0; x < 16; x++) {
          data[y * 16 + x] = x < 10 ? 50 : 255;
        }
      }
      final r = lumaSplit(
        yPlane: data,
        width: 10,
        height: 10,
        rowStride: 16,
        rotation: 0,
        box: const Box(left: 0, top: 0, right: 0.5, bottom: 1),
        step: 1,
      )!;
      expect(r.face, closeTo(50 / 255, 1e-6));
      expect(r.background, closeTo(50 / 255, 1e-6));
    });
  });

  group('measured scores', () {
    test('even light on the face scores full marks, dark and backlit lose points', () {
      expect(lightingScore(face(luma: 0.55, back: 0.55)), 100);
      expect(lightingScore(face(luma: 0.25, back: 0.3))!, lessThan(80));
      expect(lightingScore(face(luma: 0.3, back: 0.85))!, lessThan(lightingScore(face(luma: 0.3, back: 0.3))!));
      expect(lightingScore(face(luma: null)), isNull);
    });

    test('framing falls as the face drifts or shrinks', () {
      expect(framingScore(face(), Occasion.interview), 100);
      const off = Box(left: 0.6, top: 0.22, right: 0.96, bottom: 0.58);
      expect(framingScore(face(box: off), Occasion.interview)!, lessThan(90));
      expect(framingScore(face(box: null), Occasion.interview), isNull);
      expect(framingScore(face(count: 2), Occasion.interview), isNull);
    });

    test('eye contact needs the head facing the lens and the eyes open', () {
      expect(eyeContactScore(face(yaw: 0)), 100);
      expect(eyeContactScore(face(yaw: 30))!, lessThan(80));
      expect(eyeContactScore(face(eyes: 0.1))!, lessThan(70));
      expect(eyeContactScore(face(yaw: null)), isNull);
    });

    test('a neutral face is not punished hard and a clear smile is best', () {
      expect(smileScore(face(smile: 0.0)), 55);
      expect(smileScore(face(smile: 0.5)), 100);
      expect(smileScore(face(smile: 1.0)), 100);
      expect(smileScore(face(smile: null)), isNull);
    });
  });

  group('the presence score', () {
    test('is the occasion-weighted mean of the four areas', () {
      final r = scorePresence(Occasion.office, face(), eval());
      final mean = r.parts.fold<int>(0, (s, p) => s + p.value) / r.parts.length;
      expect(r.score, closeTo(mean, 1)); // equal weights at the office
    });

    test('every occasion weighs the four areas to exactly 1', () {
      for (final o in Occasion.values) {
        expect(o.weights.values.fold<double>(0, (a, b) => a + b), closeTo(1, 1e-9), reason: o.name);
      }
    });

    test('attire counts more for an interview than for a LinkedIn photo', () {
      final e = eval(attire: 1, grooming: 5, background: 5, expression: 5);
      final interview = scorePresence(Occasion.interview, face(), e).score;
      final linkedin = scorePresence(Occasion.linkedin, face(), e).score;
      expect(interview, lessThan(linkedin));
    });

    test('attire is left out, not invented, when clothes are not in the photo', () {
      final r = scorePresence(Occasion.interview, face(), eval(showClothes: false));
      expect(r.parts.map((p) => p.part), isNot(contains(PresencePart.attire)));
      expect(r.parts.length, 3);
      expect(r.score, inInclusiveRange(0, 100));
    });

    test('a backlit face pulls the light score down even when the model likes the room', () {
      final fine = scorePresence(Occasion.interview, face(luma: 0.55, back: 0.55), eval(background: 5));
      final backlit = scorePresence(Occasion.interview, face(luma: 0.25, back: 0.85), eval(background: 5));
      final f = fine.parts.firstWhere((p) => p.part == PresencePart.lighting).value;
      final b = backlit.parts.firstWhere((p) => p.part == PresencePart.lighting).value;
      expect(b, lessThan(f - 20));
    });

    test('a gallery photo with no measurements still scores, from the model alone', () {
      const none = FaceFrame(faceCount: 1);
      final r = scorePresence(Occasion.interview, none, eval());
      expect(r.parts.firstWhere((p) => p.part == PresencePart.lighting).value, 80);
      expect(r.parts.firstWhere((p) => p.part == PresencePart.lighting).measured, isNull);
    });

    test('each area states what was measured and what the model saw', () {
      final r = scorePresence(Occasion.interview, face(luma: 0.62, smile: 0.4), eval());
      final light = r.parts.firstWhere((p) => p.part == PresencePart.lighting);
      expect(light.measured, 'Measured: Face light 62%');
      expect(light.observed, 'Plain wall');
      final ex = r.parts.firstWhere((p) => p.part == PresencePart.expression);
      expect(ex.measured, contains('smile 40%'));
      expect(r.parts.firstWhere((p) => p.part == PresencePart.attire).measured, isNull);
    });

    test('scores stay within 0 and 100', () {
      for (final r in [1, 5]) {
        final s = scorePresence(
          Occasion.interview,
          face(luma: r == 1 ? 0.02 : 0.55, back: 0.9),
          eval(attire: r, grooming: r, background: r, expression: r),
        );
        expect(s.score, inInclusiveRange(0, 100));
        for (final p in s.parts) {
          expect(p.value, inInclusiveRange(0, 100));
        }
      }
    });

    test('a model that rates everything 5 but still suggests fixes cannot give those areas full marks', () {
      const fixes = [
        Fix(area: FixArea.attire, text: 'Iron the collar.'),
        Fix(area: FixArea.background, text: 'Move away from the shelf.'),
      ];
      final r = scorePresence(
        Occasion.interview,
        const FaceFrame(faceCount: 1),
        eval(attire: 5, grooming: 5, background: 5, expression: 5, fixes: fixes),
      );
      int value(PresencePart p) => r.parts.firstWhere((x) => x.part == p).value;
      expect(value(PresencePart.attire), 80);
      expect(value(PresencePart.lighting), 80);
      expect(value(PresencePart.grooming), 100); // no fix suggested for grooming
      expect(value(PresencePart.expression), 100);
    });

    test('a lighting fix also caps the background rating, since they share one area', () {
      final r = scorePresence(
        Occasion.interview,
        const FaceFrame(faceCount: 1),
        eval(background: 5, fixes: const [Fix(area: FixArea.lighting, text: 'Face a window.')]),
      );
      expect(r.parts.firstWhere((x) => x.part == PresencePart.lighting).value, 80);
    });

    test('verdict labels follow the score', () {
      expect(verdict(Occasion.interview, 81), 'Interview ready');
      expect(verdict(Occasion.linkedin, 75), 'Profile ready');
      expect(verdict(Occasion.client, 60), 'Almost there');
      expect(verdict(Occasion.office, 30), 'Needs work');
    });
  });

  group('the three fixes', () {
    const modelFixes = [
      Fix(area: FixArea.background, text: 'Move away from the shelf.'),
      Fix(area: FixArea.attire, text: 'Iron the collar.'),
      Fix(area: FixArea.grooming, text: 'Tidy the hair at the sides.'),
      Fix(area: FixArea.expression, text: 'Relax your jaw.'),
    ];

    test('never more than three, with measured problems first', () {
      final f = buildFixes(Occasion.interview, face(luma: 0.3, back: 0.85), eval(fixes: modelFixes));
      expect(f.length, 3);
      expect(f.first.area, FixArea.lighting);
      expect(f.first.text, startsWith('Light is behind you'));
    });

    test('with a clean frame the model suggestions are used', () {
      final f = buildFixes(Occasion.interview, face(), eval(fixes: modelFixes));
      expect(f.map((x) => x.area), [FixArea.background, FixArea.attire, FixArea.grooming]);
    });

    test('one fix per area, so a repeat from the model is dropped', () {
      final f = buildFixes(
        Occasion.interview,
        face(luma: 0.15, back: 0.2),
        eval(fixes: const [Fix(area: FixArea.lighting, text: 'Add light.'), Fix(area: FixArea.attire, text: 'Iron the collar.')]),
      );
      expect(f.where((x) => x.area == FixArea.lighting).length, 1);
      expect(f.first.text, contains('dark'));
    });

    test('a face too far away gets a framing fix', () {
      const small = Box(left: 0.42, top: 0.3, right: 0.58, bottom: 0.42);
      final f = buildFixes(Occasion.interview, face(box: small), eval());
      expect(f.first.area, FixArea.framing);
      expect(f.first.text, contains('closer'));
    });

    test('looking away gets a gaze fix', () {
      final f = buildFixes(Occasion.interview, face(yaw: 35), eval());
      expect(f.any((x) => x.area == FixArea.expression && x.text.contains('lens')), isTrue);
    });
  });

  group('saving', () {
    test('a frame and an evaluation survive a JSON round trip', () {
      final fr = FaceFrame.fromJson(face().toJson());
      expect(fr.box!.height, closeTo(0.36, 1e-9));
      expect(fr.lumaFace, 0.55);
      final e = PresenceEvaluation.fromJson(eval(fixes: const [Fix(area: FixArea.lighting, text: 'x')]).toJson());
      expect(e.attire!.observation, 'Collared shirt');
      expect(e.fixes.single.area, FixArea.lighting);
      expect(PresenceEvaluation.fromJson(eval(showClothes: false).toJson()).attire, isNull);
    });

    test('a frame with no measurements loads', () {
      final fr = FaceFrame.fromJson(const FaceFrame(faceCount: 1).toJson());
      expect(fr.box, isNull);
      expect(fr.lumaFace, isNull);
    });

    test('a rating outside 1 to 5 is clamped', () {
      expect(Rated.fromJson({'rating': 9, 'observation': 'x'}).rating, 5);
      expect(Rated.fromJson({'rating': 0, 'observation': 'x'}).rating, 1);
    });
  });
}
