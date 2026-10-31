import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/scoring/readiness.dart';

/// Latest result per sub-score. Null until the user has completed something; Firestore feeds this later.
/// Nothing here is seeded: a new account honestly starts empty.
class LatestScores extends Notifier<SubScores?> {
  @override
  SubScores? build() => null;

  void set(SubScores scores) => state = scores;
}

final latestScoresProvider = NotifierProvider<LatestScores, SubScores?>(LatestScores.new);
