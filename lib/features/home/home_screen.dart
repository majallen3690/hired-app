import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/scoring/readiness.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/glass.dart';
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

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scores = ref.watch(latestScoresProvider);
    final readiness = scores == null ? null : readinessScore(scores);
    final weakest = scores == null ? null : weakestSubScore(scores);

    // A new account has no scores yet, so the honest first step is the resume.
    final next = scores == null ? SubScore.resume : weakest;
    final action = next == null ? null : _actions[next];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back', style: HiredText.small.copyWith(color: HiredColors.text3)),
                    const SizedBox(height: 4),
                    Text.rich(TextSpan(style: HiredText.h1, children: [
                      const TextSpan(text: 'Ready to '),
                      TextSpan(text: 'practise?', style: HiredText.h1Em),
                    ])),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),
          _Dial(scores: scores, readiness: readiness, weakest: weakest),
          const SizedBox(height: 28),
          if (action != null)
            Glass(
              padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
              onTap: () => context.go(action.route),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scores == null ? 'START HERE' : 'BIGGEST LIFT · ${_labels[next]!.toUpperCase()}',
                          style: HiredText.label,
                        ),
                        const SizedBox(height: 5),
                        Text.rich(TextSpan(
                          style: HiredText.h2.copyWith(fontWeight: FontWeight.w400, fontSize: 18),
                          children: [
                            TextSpan(text: '${action.lead} '),
                            TextSpan(text: action.em, style: const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w500)),
                          ],
                        )),
                        const SizedBox(height: 5),
                        Text(action.note, style: HiredText.small.copyWith(color: HiredColors.text3)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: HiredColors.ember,
                      borderRadius: BorderRadius.circular(HiredRadii.button),
                    ),
                    child: const Icon(Icons.arrow_forward_rounded, color: HiredColors.onEmber),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Dial extends StatelessWidget {
  const _Dial({required this.scores, required this.readiness, required this.weakest});

  final SubScores? scores;
  final int? readiness;
  final SubScore? weakest;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduce ? Duration.zero : HiredMotion.scoreReveal,
      curve: HiredMotion.easeOutQuart,
      builder: (context, e, _) {
        final s = scores;
        final values = s == null
            ? List<double>.filled(4, 0)
            : [for (final k in SubScore.values) s[k] * e];
        const corners = [
          (SubScore.resume, Alignment.topRight),
          (SubScore.interview, Alignment.bottomRight),
          (SubScore.communication, Alignment.bottomLeft),
          (SubScore.presence, Alignment.topLeft),
        ];
        return SizedBox(
          height: 292,
          child: Stack(
            children: [
              Align(
                child: TickDial(
                  values: values,
                  focus: weakest?.index,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(readiness == null ? '–' : '${(readiness! * e).round()}', style: HiredText.num(80)),
                      const SizedBox(height: 2),
                      Text('readiness', style: HiredText.italic),
                    ],
                  ),
                ),
              ),
              for (final (k, align) in corners)
                Align(
                  alignment: align,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: align.x > 0 ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Text(
                        s == null ? '–' : '${(s[k] * e).round()}',
                        style: HiredText.num(30, color: k == weakest ? HiredColors.band(s![k]) : HiredColors.text),
                      ),
                      Text(
                        _labels[k]!,
                        style: HiredText.small.copyWith(
                          fontSize: 12,
                          fontWeight: k == weakest ? FontWeight.w600 : FontWeight.w400,
                          color: k == weakest ? HiredColors.band(s![k]) : HiredColors.text3,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
