import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hired/core/theme/app_theme.dart';
import 'package:hired/features/presence/data/presence_store.dart';
import 'package:hired/features/presence/domain/presence_models.dart';
import 'package:hired/features/presence/domain/presence_record.dart';
import 'package:hired/features/presence/presence_controller.dart';
import 'package:hired/features/presence/ui/presence_result_screen.dart';

const _frame = FaceFrame(
  faceCount: 1,
  box: Box(left: 0.32, top: 0.22, right: 0.68, bottom: 0.58),
  rollDeg: 2,
  yawDeg: 3,
  pitchDeg: 0,
  smile: 0.4,
  leftEyeOpen: 0.9,
  rightEyeOpen: 0.9,
  lumaFace: 0.3,
  lumaBackground: 0.8,
);

const _eval = PresenceEvaluation(
  attire: Rated(rating: 4, observation: 'Navy collared shirt'),
  grooming: Rated(rating: 4, observation: 'Neat hair'),
  background: Rated(rating: 3, observation: 'Shelf behind you'),
  expression: Rated(rating: 4, observation: 'Relaxed, natural smile'),
  fixes: [
    Fix(area: FixArea.background, text: 'Move away from the shelf.'),
    Fix(area: FixArea.attire, text: 'Iron the collar.'),
    Fix(area: FixArea.grooming, text: 'Tidy the sides.'),
  ],
);

PresenceRecord record({PresenceEvaluation? evaluation = _eval, String? failed, bool saved = false}) => PresenceRecord(
      id: 'p1',
      at: DateTime(2026, 11, 2, 12),
      occasion: Occasion.interview,
      photoFile: 'p1.jpg',
      frame: _frame,
      evaluation: evaluation,
      failed: failed,
      saved: saved,
    );

Widget host(PresenceRecord r) => ProviderScope(
      overrides: [presenceRecordProvider('p1').overrideWith((ref) async => r)],
      child: MaterialApp(theme: buildHiredTheme(Brightness.dark), home: const PresenceResultScreen(id: 'p1')),
    );

void main() {
  setUp(() {
    // A tall screen, so the whole lazily built page is on screen.
  });

  testWidgets('a scored check shows the score, every area, the measured and seen notes and three fixes', (tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(record()));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(find.text('Interview look'), findsOneWidget);
    for (final area in ['Attire', 'Grooming', 'Light and background', 'Expression']) {
      expect(find.text(area), findsOneWidget);
    }
    expect(find.text('Seen: Navy collared shirt'), findsOneWidget);
    expect(find.textContaining('Measured: Face light 30%'), findsOneWidget);
    expect(find.text('Three quick fixes'), findsOneWidget);
    // The measured backlight problem comes first, then the model's suggestions.
    expect(find.textContaining('Light is behind you'), findsOneWidget);
    expect(find.text('Move away from the shelf.'), findsOneWidget);
    expect(find.text('Save to my score'), findsOneWidget);
    expect(find.text('Retake'), findsOneWidget);
  });

  testWidgets('a check that could not be read offers a retry and no score', (tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(record(evaluation: null, failed: 'No connection. Check your internet and try again.')));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('No connection. Check your internet and try again.'), findsOneWidget);
    expect(find.text('Breakdown'), findsNothing);
    final save = find.widgetWithText(FilledButton, 'Save to my score');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
  });

  testWidgets('a saved check offers delete instead of save', (tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(record(saved: true)));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Delete photo'), findsOneWidget);
    expect(find.text('Save to my score'), findsNothing);
  });

  testWidgets('a photo with no clothes in it shows three areas, not four', (tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const noClothes = PresenceEvaluation(
      attire: null,
      grooming: Rated(rating: 4, observation: 'Neat'),
      background: Rated(rating: 4, observation: 'Plain'),
      expression: Rated(rating: 4, observation: 'Calm'),
      fixes: [Fix(area: FixArea.background, text: 'Plain wall is best.')],
    );
    await tester.pumpWidget(host(record(evaluation: noClothes)));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(find.text('Attire'), findsNothing);
    expect(find.text('Grooming'), findsOneWidget);
  });

  testWidgets('the result screen keeps its controller alive, so save and delete can finish after awaiting', (tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: [presenceRecordProvider('p1').overrideWith((ref) async => record())]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: buildHiredTheme(Brightness.dark), home: const PresenceResultScreen(id: 'p1')),
    ));
    await tester.pump(const Duration(seconds: 2));
    // An auto-disposed provider with no listener would be gone after a few frames; this one must still be there.
    await tester.pump(const Duration(seconds: 1));
    expect(container.exists(presenceControllerProvider), isTrue);
  });
}
