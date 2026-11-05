import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/glass.dart';

const _free = [
  'Resume match against any job description',
  'Live voice mock interviews with Coach Replay',
  'Self-intro coach and presence check',
  'Application tracker with reminders',
  'Progress report and shareable scorecard',
];

const _pro = [
  'Company mode: rounds modelled on a specific company',
  'Side-by-side resume versions',
  'Deeper delivery analysis across many sessions',
  'Mentor-ready PDF report',
  'Early access to new interview formats',
];

/// A concept screen: it shows where the product could go. Nothing here can be bought, and nothing is charged.
class ProScreen extends StatelessWidget {
  const ProScreen({super.key});

  void _soon(BuildContext context) {
    Haptics.tap();
    final c = context.hc;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      sheetAnimationStyle: hiredSheetMotion,
      backgroundColor: c.ink2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(HiredRadii.card))),
      builder: (sheet) => Padding(
        padding: EdgeInsets.fromLTRB(HiredSpace.screen, HiredSpace.xl, HiredSpace.screen, HiredSpace.xl + MediaQuery.viewPaddingOf(sheet).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.hourglass_top_rounded, color: c.ember, size: 28),
          const SizedBox(height: HiredSpace.md),
          Text('Coming soon', style: HiredText.h1.copyWith(color: c.text)),
          const SizedBox(height: HiredSpace.sm),
          Text(
            'Hired Pro is a preview of where this could go. Nothing is for sale yet and nothing will be charged. Everything you use today stays free.',
            style: HiredText.body.copyWith(color: c.text2),
          ),
          const SizedBox(height: HiredSpace.xl),
          PrimaryButton(label: 'Got it', onPressed: () => Navigator.of(sheet).pop()),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Scaffold(
      backgroundColor: c.ink,
      body: Aurora(
        child: SafeArea(
          child: RevealListView(
            padding: const EdgeInsets.fromLTRB(HiredSpace.screen, HiredSpace.sm, HiredSpace.screen, HiredSpace.xxl),
            children: [
              Row(children: [
                IconAction(icon: Icons.arrow_back_rounded, label: 'Back', onPressed: () => context.pop()),
                const Spacer(),
                const Tag('Preview', tone: TagTone.signal),
              ]),
              const SizedBox(height: HiredSpace.lg),
              Text.rich(TextSpan(style: HiredText.h1.copyWith(color: c.text), children: [
                const TextSpan(text: 'Hired '),
                TextSpan(text: 'Pro', style: HiredText.h1Em),
              ])),
              const SizedBox(height: HiredSpace.sm),
              Text('A look at what a paid tier could add.', style: HiredText.body.copyWith(color: c.text2)),
              const SizedBox(height: HiredSpace.xl),
              _Plan(name: 'Free', note: 'What you have today', lines: _free, icon: Icons.check_rounded, color: c.ok),
              const SizedBox(height: HiredSpace.md),
              _Plan(name: 'Pro', note: 'Concept', lines: _pro, icon: Icons.auto_awesome_rounded, color: c.ember, highlight: true),
              const SizedBox(height: HiredSpace.xl),
              PrimaryButton(label: 'Tell me when it exists', icon: Icons.notifications_none_rounded, onPressed: () => _soon(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Plan extends StatelessWidget {
  const _Plan({required this.name, required this.note, required this.lines, required this.icon, required this.color, this.highlight = false});
  final String name, note;
  final List<String> lines;
  final IconData icon;
  final Color color;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Container(
      decoration: highlight
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(HiredRadii.card),
              border: Border.all(color: c.ember.withValues(alpha: 0.6), width: 1.4),
            )
          : null,
      child: Glass(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(name, style: HiredText.h2.copyWith(color: c.text)),
            const SizedBox(width: HiredSpace.sm),
            Text(note, style: HiredText.small.copyWith(color: c.text3)),
          ]),
          const SizedBox(height: HiredSpace.md),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: HiredSpace.sm),
                Expanded(child: Text(l, style: HiredText.small.copyWith(color: c.text2))),
              ]),
            ),
        ]),
      ),
    );
  }
}
