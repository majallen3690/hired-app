import '../../../core/scoring/readiness.dart';

/// One measured result for one area at one moment. The progress chart is rebuilt from these, never stored as a number.
class ScoreEvent {
  const ScoreEvent({
    required this.id,
    required this.at,
    required this.area,
    required this.value,
  });

  /// Stable, so the same session or match is never counted twice.
  final String id;
  final DateTime at;
  final SubScore area;
  final int value;

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toUtc().toIso8601String(),
    'area': area.name,
    'value': value,
  };

  factory ScoreEvent.fromJson(Map<String, dynamic> j) => ScoreEvent(
    id: j['id'] as String,
    at: DateTime.parse(j['at'] as String),
    area: SubScore.values.firstWhere(
      (a) => a.name == j['area'],
      orElse: () => SubScore.resume,
    ),
    value: j['value'] as int,
  );
}

class ReadinessPoint {
  const ReadinessPoint(this.at, this.value);
  final DateTime at;
  final int value;
}

enum BadgeKind { firstMock, resume70, streak7, ready75 }

class Achievement {
  const Achievement({
    required this.kind,
    required this.label,
    required this.earned,
    required this.hint,
  });
  final BadgeKind kind;
  final String label;
  final bool earned;

  /// What earns it, shown while it is still locked.
  final String hint;
}

class ProgressSummary {
  const ProgressSummary({
    required this.points,
    required this.streak,
    required this.bestStreak,
    required this.mocks,
    required this.resumeMatches,
    required this.bestReadiness,
    required this.bestInterview,
    required this.bestResume,
    required this.badges,
  });

  /// Readiness after each measured moment, oldest first.
  final List<ReadinessPoint> points;
  final int streak;
  final int bestStreak;
  final int mocks;
  final int resumeMatches;
  final int? bestReadiness;
  final int? bestInterview;
  final int? bestResume;
  final List<Achievement> badges;

  bool get isEmpty => points.isEmpty;
  int? get current => points.isEmpty ? null : points.last.value;

  /// Change since the first measurement, or null with fewer than two points.
  int? get delta =>
      points.length < 2 ? null : points.last.value - points.first.value;

  DateTime? get since => points.isEmpty ? null : points.first.at;
}

DateTime _day(DateTime t) {
  final l = t.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// Readiness after each moment, replaying the events in order. Several results from the same moment (a mock gives an
/// interview and a speaking score) make one point. An area nobody has measured yet counts as zero, as on Home.
List<ReadinessPoint> readinessTimeline(List<ScoreEvent> events) {
  final sorted = [...events]..sort((a, b) => a.at.compareTo(b.at));
  final latest = <SubScore, int>{};
  final points = <ReadinessPoint>[];
  var i = 0;
  while (i < sorted.length) {
    final at = sorted[i].at;
    while (i < sorted.length && sorted[i].at == at) {
      latest[sorted[i].area] = sorted[i].value;
      i++;
    }
    final scores = SubScores(
      resume: latest[SubScore.resume] ?? 0,
      interview: latest[SubScore.interview] ?? 0,
      communication: latest[SubScore.communication] ?? 0,
      presence: latest[SubScore.presence] ?? 0,
    );
    points.add(ReadinessPoint(at, readinessScore(scores)));
  }
  return points;
}

/// Consecutive days with at least one measured result, ending today. If today has none yet, the streak is still alive
/// through yesterday, so opening the app in the morning does not zero it.
int currentStreak(Iterable<DateTime> activity, DateTime now) {
  final days = {for (final t in activity) _day(t)};
  var d = _day(now);
  if (!days.contains(d)) d = d.subtract(const Duration(days: 1));
  // Subtracting whole days from a local midnight can cross a DST change, so rebuild the date each step.
  var n = 0;
  while (days.contains(d)) {
    n++;
    d = DateTime(d.year, d.month, d.day - 1);
  }
  return n;
}

/// "today", "in 5 days" or "in 3 weeks": how long a change took.
String spanLabel(int days) {
  if (days < 1) return 'today';
  if (days < 14) return 'in $days ${days == 1 ? 'day' : 'days'}';
  return 'in ${(days / 7).round()} weeks';
}

String dayCount(int n) => '$n ${n == 1 ? 'day' : 'days'}';

/// For each of the last seven days ending today, oldest first: was anything measured that day?
List<bool> activityLast7(Iterable<DateTime> activity, DateTime now) {
  final days = {for (final t in activity) _day(t)};
  final today = _day(now);
  return [
    for (var back = 6; back >= 0; back--)
      days.contains(DateTime(today.year, today.month, today.day - back)),
  ];
}

int bestStreak(Iterable<DateTime> activity) {
  final days = {for (final t in activity) _day(t)}.toList()..sort();
  var best = 0, run = 0;
  DateTime? prev;
  for (final d in days) {
    run = (prev != null && DateTime(prev.year, prev.month, prev.day + 1) == d)
        ? run + 1
        : 1;
    if (run > best) best = run;
    prev = d;
  }
  return best;
}

ProgressSummary summariseProgress(
  List<ScoreEvent> events, {
  required DateTime now,
}) {
  final points = readinessTimeline(events);
  final activity = events.map((e) => e.at).toList();
  int? best(SubScore a) {
    final vs = events.where((e) => e.area == a).map((e) => e.value);
    return vs.isEmpty ? null : vs.reduce((x, y) => x > y ? x : y);
  }

  final bestRead = points.isEmpty
      ? null
      : points.map((p) => p.value).reduce((x, y) => x > y ? x : y);
  final bestRun = bestStreak(activity);
  return ProgressSummary(
    points: points,
    streak: currentStreak(activity, now),
    bestStreak: bestRun,
    mocks: events.where((e) => e.area == SubScore.interview).length,
    resumeMatches: events.where((e) => e.area == SubScore.resume).length,
    bestReadiness: bestRead,
    bestInterview: best(SubScore.interview),
    bestResume: best(SubScore.resume),
    badges: [
      Achievement(
        kind: BadgeKind.firstMock,
        label: 'First mock',
        earned: events.any((e) => e.area == SubScore.interview),
        hint: 'Finish one mock interview',
      ),
      Achievement(
        kind: BadgeKind.resume70,
        label: 'Resume 70+',
        earned: (best(SubScore.resume) ?? 0) >= 70,
        hint: 'Get a resume match of 70',
      ),
      Achievement(
        kind: BadgeKind.streak7,
        label: '7-day streak',
        earned: bestRun >= 7,
        hint: 'Practise 7 days in a row',
      ),
      Achievement(
        kind: BadgeKind.ready75,
        label: 'Ready at $readyThreshold',
        earned: (bestRead ?? 0) >= readyThreshold,
        hint: 'Reach a readiness of $readyThreshold',
      ),
    ],
  );
}
