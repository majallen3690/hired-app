import '../../../core/scoring/readiness.dart';
import 'progress_models.dart';

/// How one area has gone: its first and latest measured result, and how many times it was measured.
class AreaReport {
  const AreaReport({required this.area, required this.first, required this.latest, required this.count});

  final SubScore area;
  final int? first;
  final int? latest;
  final int count;

  bool get measured => latest != null;

  /// Change since the first measurement, or null when there is only one (or none).
  int? get delta => count < 2 || first == null || latest == null ? null : latest! - first!;

  String get label => areaLabel(area);
}

String areaLabel(SubScore s) => switch (s) {
      SubScore.resume => 'Resume',
      SubScore.interview => 'Interview',
      SubScore.communication => 'Speaking',
      SubScore.presence => 'Presence',
    };

/// A read-out of the whole history, worked out only from measured results: nothing here is estimated.
class ProgressReport {
  const ProgressReport({required this.areas, required this.readiness});

  final List<AreaReport> areas;
  final int? readiness;

  List<AreaReport> get measured => [for (final a in areas) if (a.measured) a];

  /// The area with the highest latest score.
  AreaReport? get strongest {
    final m = measured;
    if (m.isEmpty) return null;
    return m.reduce((a, b) => b.latest! > a.latest! ? b : a);
  }

  /// The area with the most room to grow. An area never measured counts as zero, because that is how readiness
  /// counts it too, so the advice and the score never disagree.
  AreaReport get focus => areas.reduce((a, b) => (b.latest ?? 0) < (a.latest ?? 0) ? b : a);

  /// The area that has risen the most, if any has risen at all.
  AreaReport? get biggestMover {
    AreaReport? best;
    for (final a in areas) {
      final d = a.delta;
      if (d != null && d > 0 && (best == null || d > best.delta!)) best = a;
    }
    return best;
  }

  SubScores get _scores => SubScores(
        resume: _latest(SubScore.resume),
        interview: _latest(SubScore.interview),
        communication: _latest(SubScore.communication),
        presence: _latest(SubScore.presence),
      );

  int _latest(SubScore s) => areas.firstWhere((a) => a.area == s).latest ?? 0;

  /// How many readiness points raising [area] to the placement-ready line would add, using the same weights as the
  /// score itself. Zero when it is already there.
  int liftToReady(SubScore area) {
    final now = _scores;
    if (now[area] >= readyThreshold) return 0;
    final raised = switch (area) {
      SubScore.resume => now.copyWith(resume: readyThreshold),
      SubScore.interview => now.copyWith(interview: readyThreshold),
      SubScore.communication => now.copyWith(communication: readyThreshold),
      SubScore.presence => now.copyWith(presence: readyThreshold),
    };
    return readinessScore(raised) - readinessScore(now);
  }

  /// Points of readiness still to go to the placement-ready line, or 0 once there.
  int? get pointsToReady => readiness == null ? null : (readyThreshold - readiness!).clamp(0, 100);

  bool get isEmpty => measured.isEmpty;
}

ProgressReport buildProgressReport(List<ScoreEvent> events, {int? readiness}) {
  final sorted = [...events]..sort((a, b) => a.at.compareTo(b.at));
  return ProgressReport(
    readiness: readiness,
    areas: [
      for (final area in SubScore.values)
        () {
          final mine = [for (final e in sorted) if (e.area == area) e.value];
          return AreaReport(
            area: area,
            first: mine.isEmpty ? null : mine.first,
            latest: mine.isEmpty ? null : mine.last,
            count: mine.length,
          );
        }(),
    ],
  );
}

/// Measured results per day for the last [days] days ending today, oldest first, so a week or two can be drawn as bars.
List<int> activityCounts(Iterable<DateTime> activity, DateTime now, {int days = 14}) {
  DateTime day(DateTime t) {
    final l = t.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  final today = day(now);
  final counts = <DateTime, int>{};
  for (final t in activity) {
    counts[day(t)] = (counts[day(t)] ?? 0) + 1;
  }
  return [
    for (var i = days - 1; i >= 0; i--) counts[DateTime(today.year, today.month, today.day - i)] ?? 0,
  ];
}
