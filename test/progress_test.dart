import 'package:flutter_test/flutter_test.dart';
import 'package:hired/core/scoring/readiness.dart';
import 'package:hired/features/progress/domain/progress_models.dart';

ScoreEvent ev(String id, DateTime at, SubScore a, int v) => ScoreEvent(id: id, at: at, area: a, value: v);

DateTime d(int day, [int hour = 12]) => DateTime(2026, 11, day, hour);

void main() {
  group('readiness timeline', () {
    test('replays events and counts unmeasured areas as zero', () {
      final pts = readinessTimeline([
        ev('a', d(1), SubScore.resume, 60), // 0.30 * 60 = 18
        ev('b', d(2), SubScore.interview, 80), // + 0.35 * 80 = 28
      ]);
      expect(pts.map((p) => p.value), [18, 46]);
    });

    test('events at the same moment make one point', () {
      final t = d(3);
      final pts = readinessTimeline([
        ev('a', t, SubScore.interview, 80),
        ev('b', t, SubScore.communication, 60),
      ]);
      expect(pts.length, 1);
      expect(pts.single.value, (0.35 * 80 + 0.20 * 60).round());
    });

    test('a newer result replaces the older one for that area', () {
      final pts = readinessTimeline([
        ev('a', d(1), SubScore.interview, 40),
        ev('b', d(2), SubScore.interview, 80),
      ]);
      expect(pts.last.value, (0.35 * 80).round());
      expect(pts.first.value, (0.35 * 40).round());
    });

    test('input order does not matter', () {
      final pts = readinessTimeline([
        ev('b', d(2), SubScore.interview, 80),
        ev('a', d(1), SubScore.resume, 60),
      ]);
      expect(pts.first.at, d(1));
    });

    test('no events, no points', () {
      expect(readinessTimeline(const []), isEmpty);
    });
  });

  group('labels', () {
    test('span reads naturally', () {
      expect(spanLabel(0), 'today');
      expect(spanLabel(1), 'in 1 day');
      expect(spanLabel(5), 'in 5 days');
      expect(spanLabel(21), 'in 3 weeks');
    });

    test('day counts are singular for one', () {
      expect(dayCount(1), '1 day');
      expect(dayCount(7), '7 days');
    });
  });

  group('streak', () {
    test('counts consecutive days ending today', () {
      expect(currentStreak([d(1), d(2), d(3)], d(3, 20)), 3);
    });

    test('is still alive through yesterday when today has nothing yet', () {
      expect(currentStreak([d(1), d(2)], d(3, 8)), 2);
    });

    test('a missed day breaks it', () {
      expect(currentStreak([d(1), d(2)], d(5)), 0);
      expect(currentStreak([d(1), d(3)], d(3)), 1);
    });

    test('several results on one day count once', () {
      expect(currentStreak([d(2, 9), d(2, 18), d(3)], d(3)), 2);
    });

    test('best streak finds the longest run anywhere', () {
      expect(bestStreak([d(1), d(2), d(3), d(10), d(11)]), 3);
      expect(bestStreak(const []), 0);
    });

    test('the last seven days show where activity happened, oldest first', () {
      final week = activityLast7([d(3), d(5), d(7)], d(7));
      expect(week, [false, false, true, false, true, false, true]); // days 1..7 -> shows 1,2,3,4,5,6,7
    });

    test('works across a month boundary', () {
      expect(currentStreak([DateTime(2026, 10, 31), DateTime(2026, 11, 1)], DateTime(2026, 11, 1, 9)), 2);
    });
  });

  group('summary', () {
    test('an empty history is empty, with no made-up numbers', () {
      final s = summariseProgress(const [], now: d(1));
      expect(s.isEmpty, isTrue);
      expect(s.current, isNull);
      expect(s.delta, isNull);
      expect(s.bestInterview, isNull);
      expect(s.badges.every((b) => !b.earned), isTrue);
    });

    test('one point has no delta yet', () {
      final s = summariseProgress([ev('a', d(1), SubScore.resume, 50)], now: d(1));
      expect(s.current, 15);
      expect(s.delta, isNull);
    });

    test('delta is the change since the first measurement', () {
      final s = summariseProgress([
        ev('a', d(1), SubScore.resume, 50),
        ev('b', d(2), SubScore.interview, 70),
      ], now: d(2));
      expect(s.delta, s.points.last.value - s.points.first.value);
      expect(s.delta, greaterThan(0));
    });

    test('counts mocks, matches and bests per area', () {
      final s = summariseProgress([
        ev('a', d(1), SubScore.resume, 40),
        ev('b', d(2), SubScore.resume, 72),
        ev('c', d(3), SubScore.interview, 55),
        ev('d', d(4), SubScore.interview, 70),
      ], now: d(4));
      expect(s.resumeMatches, 2);
      expect(s.mocks, 2);
      expect(s.bestResume, 72);
      expect(s.bestInterview, 70);
    });

    test('badges unlock from real results only', () {
      final s = summariseProgress([
        ev('a', d(1), SubScore.resume, 72),
        ev('b', d(2), SubScore.interview, 60),
      ], now: d(2));
      bool earned(BadgeKind k) => s.badges.firstWhere((b) => b.kind == k).earned;
      expect(earned(BadgeKind.resume70), isTrue);
      expect(earned(BadgeKind.firstMock), isTrue);
      expect(earned(BadgeKind.streak7), isFalse);
      expect(earned(BadgeKind.ready75), isFalse);
    });

    test('the 7-day badge needs seven days in a row', () {
      final events = [for (var i = 1; i <= 7; i++) ev('e$i', d(i), SubScore.resume, 50)];
      final s = summariseProgress(events, now: d(7));
      expect(s.streak, 7);
      expect(s.badges.firstWhere((b) => b.kind == BadgeKind.streak7).earned, isTrue);
    });

    test('ready at 75 unlocks once readiness reaches it', () {
      final s = summariseProgress([
        ev('a', d(1), SubScore.resume, 100),
        ev('b', d(1), SubScore.interview, 100),
        ev('c', d(1), SubScore.communication, 100),
        ev('d', d(1), SubScore.presence, 100),
      ], now: d(1));
      expect(s.bestReadiness, 100);
      expect(s.badges.firstWhere((b) => b.kind == BadgeKind.ready75).earned, isTrue);
    });

    test('events survive a JSON round trip', () {
      final e = ev('x', d(5), SubScore.communication, 66);
      final back = ScoreEvent.fromJson(e.toJson());
      expect(back.id, 'x');
      expect(back.area, SubScore.communication);
      expect(back.value, 66);
      expect(back.at.isAtSameMomentAs(e.at), isTrue);
    });
  });
}
