import 'package:flutter_test/flutter_test.dart';
import 'package:hired/core/scoring/readiness.dart';
import 'package:hired/features/progress/domain/progress_models.dart';
import 'package:hired/features/progress/domain/progress_report.dart';

ScoreEvent e(String id, int daysAgo, SubScore area, int v) =>
    ScoreEvent(id: id, at: DateTime(2026, 11, 5, 12).subtract(Duration(days: daysAgo)), area: area, value: v);

void main() {
  final now = DateTime(2026, 11, 5, 12);

  test('each area keeps its first and latest result and how often it was measured', () {
    final r = buildProgressReport([
      e('1', 20, SubScore.resume, 49),
      e('2', 10, SubScore.resume, 63),
      e('3', 1, SubScore.resume, 79),
      e('4', 5, SubScore.interview, 47),
    ], readiness: 40);
    final resume = r.areas.firstWhere((a) => a.area == SubScore.resume);
    expect((resume.first, resume.latest, resume.count, resume.delta), (49, 79, 3, 30));
    final interview = r.areas.firstWhere((a) => a.area == SubScore.interview);
    expect(interview.delta, isNull);
    expect(r.areas.firstWhere((a) => a.area == SubScore.presence).measured, isFalse);
  });

  test('the strongest area is the best measured one and the focus counts an unmeasured area as zero', () {
    final r = buildProgressReport([e('1', 3, SubScore.resume, 79), e('2', 2, SubScore.interview, 47)]);
    expect(r.strongest!.area, SubScore.resume);
    expect(r.focus.area, SubScore.communication);
  });

  test('the biggest mover is the area that rose most, and nothing is named when nothing rose', () {
    final rising = buildProgressReport([
      e('1', 9, SubScore.resume, 40),
      e('2', 1, SubScore.resume, 50),
      e('3', 9, SubScore.interview, 30),
      e('4', 1, SubScore.interview, 70),
    ]);
    expect(rising.biggestMover!.area, SubScore.interview);
    final flat = buildProgressReport([e('1', 9, SubScore.resume, 50), e('2', 1, SubScore.resume, 45)]);
    expect(flat.biggestMover, isNull);
  });

  test('the lift from raising one area to the ready line uses the readiness weights', () {
    final r = buildProgressReport([e('1', 1, SubScore.resume, 75), e('2', 1, SubScore.presence, 15)]);
    // Presence 15 -> 75 is 60 points at weight 0.15.
    expect(r.liftToReady(SubScore.presence), 9);
    expect(r.liftToReady(SubScore.resume), 0);
    // Interview was never measured, so it counts as zero: 75 x 0.35 = 26.25, rounded.
    expect(r.liftToReady(SubScore.interview), 26);
  });

  test('points to the ready line stop at zero', () {
    expect(buildProgressReport([], readiness: 62).pointsToReady, 13);
    expect(buildProgressReport([], readiness: 80).pointsToReady, 0);
    expect(buildProgressReport([]).pointsToReady, isNull);
    expect(buildProgressReport([]).isEmpty, isTrue);
  });

  test('activity is counted per day, oldest first, and ignores days outside the window', () {
    final counts = activityCounts([
      now,
      now.subtract(const Duration(hours: 2)),
      now.subtract(const Duration(days: 2)),
      now.subtract(const Duration(days: 40)),
    ], now, days: 7);
    expect(counts, [0, 0, 0, 0, 1, 0, 2]);
  });
}
