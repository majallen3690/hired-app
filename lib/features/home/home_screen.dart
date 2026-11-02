import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/scoring/readiness.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/score_widgets.dart';
import '../../core/widgets/tick_dial.dart';
import 'scores_provider.dart';

class _Action {
  const _Action(this.lead, this.em, this.note, this.route);
  final String lead;
  final String em;
  final String note;
  final String route;
}

const _actions = <SubScore, _Action>{
  SubScore.resume: _Action('Tailor your resume to', 'one JD', '8 min · usually +4 to 6', '/resume'),
  SubScore.interview: _Action('Take a 10-minute', 'technical mock', '10 min · usually +5 to 8', '/interview'),
  SubScore.communication: _Action('Record your', '60-second intro', '2 min · usually +3 to 5', '/intro'),
  SubScore.presence: _Action('Check your', 'interview look', '2 min · usually +3 to 5', '/presence'),
};

const _labels = <SubScore, String>{
  SubScore.resume: 'Resume',
  SubScore.interview: 'Interview',
  SubScore.communication: 'Speaking',
  SubScore.presence: 'Presence',
};

const _corners = <SubScore, Alignment>{
  SubScore.resume: Alignment.topRight,
  SubScore.interview: Alignment.bottomRight,
  SubScore.communication: Alignment.bottomLeft,
  SubScore.presence: Alignment.topLeft,
};

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.hc;
    final measured = ref.watch(latestScoresProvider);
    final scores = measured.isEmpty ? null : measured.toScores();
    final weakest = scores == null ? null : weakestSubScore(scores);

    // A new install has no scores yet, so the honest first step is the resume.
    final next = scores == null ? SubScore.resume : weakest;
    final action = next == null ? null : _actions[next];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(HiredSpace.screen, HiredSpace.md, HiredSpace.screen, 120),
        children: [
          Text('Welcome back', style: HiredText.small.copyWith(color: c.text3)),
          const SizedBox(height: HiredSpace.xs),
          Text.rich(TextSpan(style: HiredText.h1.copyWith(color: c.text), children: [
            const TextSpan(text: 'Ready to '),
            TextSpan(text: 'practise?', style: HiredText.h1Em),
          ])),
          const SizedBox(height: 36),
          _Dial(scores: scores, measured: measured, weakest: weakest, onCorner: (k) => context.go(_actions[k]!.route)),
          const SizedBox(height: HiredSpace.xxl),
          if (action != null)
            NextActionCard(
              kicker: scores == null ? 'Start here' : 'Biggest lift · ${_labels[next]}',
              lead: action.lead,
              emphasis: action.em,
              note: action.note,
              onTap: () => context.go(action.route),
            ),
        ],
      ),
    );
  }
}

class _Dial extends StatelessWidget {
  const _Dial({required this.scores, required this.measured, required this.weakest, required this.onCorner});

  final SubScores? scores;
  final MeasuredScores measured;
  final SubScore? weakest;
  final ValueChanged<SubScore> onCorner;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final reduce = MediaQuery.of(context).disableAnimations;
    final s = scores;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduce ? Duration.zero : HiredMotion.scoreReveal,
      curve: HiredMotion.easeOutQuart,
      builder: (context, e, _) {
        return SizedBox(
          height: 292,
          child: Stack(
            children: [
              Align(
                child: TickDial(
                  values: s == null ? List.filled(4, 0.0) : [for (final k in SubScore.values) s[k] * e],
                  focus: weakest?.index,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(s == null ? '–' : '${(readinessScore(s) * e).round()}',
                          style: HiredText.num(80).copyWith(color: c.text)),
                      const SizedBox(height: 2),
                      Text(
                        s == null || measured.measuredCount == 4
                            ? 'readiness'
                            : 'readiness · ${measured.measuredCount} of 4',
                        style: HiredText.italic.copyWith(color: c.text3),
                      ),
                    ],
                  ),
                ),
              ),
              for (final k in SubScore.values)
                ScoreCorner(
                  label: _labels[k]!,
                  value: measured[k] == null ? null : (measured[k]! * e).round(),
                  alignment: _corners[k]!,
                  highlight: k == weakest,
                  onTap: () => onCorner(k),
                ),
            ],
          ),
        );
      },
    );
  }
}
