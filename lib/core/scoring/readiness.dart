enum SubScore { resume, interview, communication, presence }

const readyThreshold = 75;

const _weights = <SubScore, double>{
  SubScore.resume: 0.30,
  SubScore.interview: 0.35,
  SubScore.communication: 0.20,
  SubScore.presence: 0.15,
};

class SubScores {
  const SubScores({
    required this.resume,
    required this.interview,
    required this.communication,
    required this.presence,
  });

  final int resume;
  final int interview;
  final int communication;
  final int presence;

  int operator [](SubScore s) => switch (s) {
        SubScore.resume => resume,
        SubScore.interview => interview,
        SubScore.communication => communication,
        SubScore.presence => presence,
      };

  SubScores copyWith({int? resume, int? interview, int? communication, int? presence}) => SubScores(
        resume: resume ?? this.resume,
        interview: interview ?? this.interview,
        communication: communication ?? this.communication,
        presence: presence ?? this.presence,
      );
}

int _clamp(int v) => v < 0 ? 0 : (v > 100 ? 100 : v);

/// Resume 30% · Interview 35% · Communication 20% · Presence 15%, each from the latest result.
int readinessScore(SubScores s) {
  var total = 0.0;
  for (final k in SubScore.values) {
    total += _clamp(s[k]) * _weights[k]!;
  }
  return total.round();
}

/// The sub-score with the most room to grow, or null when every area is at or above [readyThreshold].
/// Ties resolve in enum order so the result is stable.
SubScore? weakestSubScore(SubScores s) {
  SubScore? weakest;
  var lowest = 101;
  for (final k in SubScore.values) {
    final v = _clamp(s[k]);
    if (v < lowest) {
      lowest = v;
      weakest = k;
    }
  }
  return lowest >= readyThreshold ? null : weakest;
}
