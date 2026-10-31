import 'package:flutter_test/flutter_test.dart';
import 'package:hired/core/scoring/readiness.dart';

void main() {
  const demo = SubScores(resume: 74, interview: 50, communication: 62, presence: 66);

  test('demo persona starts at 62', () {
    expect(readinessScore(demo), 62);
  });

  test('a better mock interview lifts the score to 68', () {
    expect(readinessScore(demo.copyWith(interview: 66)), 68);
  });

  test('weights sum to 100% so all-100 is 100 and all-0 is 0', () {
    const full = SubScores(resume: 100, interview: 100, communication: 100, presence: 100);
    const none = SubScores(resume: 0, interview: 0, communication: 0, presence: 0);
    expect(readinessScore(full), 100);
    expect(readinessScore(none), 0);
  });

  test('out-of-range inputs are clamped', () {
    const wild = SubScores(resume: 140, interview: -20, communication: 100, presence: 100);
    expect(readinessScore(wild), 65); // 30 + 0 + 20 + 15
  });

  test('weakest sub-score drives the next best action', () {
    expect(weakestSubScore(demo), SubScore.interview);
    expect(weakestSubScore(demo.copyWith(interview: 66)), SubScore.communication);
  });

  test('no weakest area once everything is ready', () {
    const ready = SubScores(resume: 80, interview: 78, communication: 75, presence: 90);
    expect(weakestSubScore(ready), isNull);
  });

  test('ties resolve in a stable order', () {
    const tie = SubScores(resume: 60, interview: 60, communication: 60, presence: 60);
    expect(weakestSubScore(tie), SubScore.resume);
  });
}
