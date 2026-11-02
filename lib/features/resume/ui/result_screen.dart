import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/glass.dart';
import '../domain/match_models.dart';
import '../resume_flow.dart';
import 'rewrite_sheet.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.hc;
    final flow = ref.watch(resumeFlowProvider);
    final m = flow.match;
    if (m == null) {
      return SafeArea(
        child: Center(child: TextAction(label: 'No result yet. Start a match', onPressed: () => context.go('/resume'))),
      );
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(HiredSpace.screen, HiredSpace.md, HiredSpace.screen, 120),
        children: [
          Row(children: [
            IconAction(icon: Icons.arrow_back_rounded, label: 'Back', onPressed: () => context.go('/resume')),
            const Spacer(),
            Text(m.role, style: HiredText.small.copyWith(color: c.text3)),
          ]),
          const SizedBox(height: HiredSpace.lg),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: m.overall.toDouble()),
              duration: MediaQuery.of(context).disableAnimations ? Duration.zero : HiredMotion.scoreReveal,
              curve: HiredMotion.easeOutQuart,
              builder: (_, v, __) => Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('${v.round()}', style: HiredText.num(96).copyWith(color: c.band(m.overall))),
                  Text('%', style: HiredText.num(40).copyWith(color: c.text3)),
                ],
              ),
            ),
          ),
          Center(child: Text('match', style: HiredText.italic.copyWith(color: c.text3))),
          const SizedBox(height: HiredSpace.xxl),
          Glass(
            child: Column(children: [
              _Component('Keywords', m.keywordScore, 'Skills the JD names that your resume states'),
              const SizedBox(height: HiredSpace.lg),
              _Component('Meaning', m.semanticScore, 'How well your work answers each requirement'),
              const SizedBox(height: HiredSpace.lg),
              _Component('Recruiter view', m.rubricScore, 'Relevance, results and ATS formatting'),
            ]),
          ),
          const SizedBox(height: HiredSpace.xxl),
          _Skills('Matched', m.matchedSkills, TagTone.ok),
          if (m.missingSkills.isNotEmpty) ...[
            const SizedBox(height: HiredSpace.xl),
            _Skills('Missing', m.missingSkills, TagTone.bad),
          ],
          const SizedBox(height: HiredSpace.xxl),
          const SectionLabel('Top fixes'),
          const SizedBox(height: HiredSpace.md),
          for (final (i, f) in m.fixes.take(5).indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: HiredSpace.md),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 26, child: Text('${i + 1}', style: HiredText.num(18).copyWith(color: c.ember))),
                Expanded(child: Text(f, style: HiredText.body.copyWith(color: c.text))),
              ]),
            ),
          if (m.sections.isNotEmpty) ...[
            const SizedBox(height: HiredSpace.xl),
            const SectionLabel('Section notes'),
            const SizedBox(height: HiredSpace.md),
            for (final s in m.sections)
              Padding(
                padding: const EdgeInsets.only(bottom: HiredSpace.md),
                child: Glass(
                  onTap: s.evidence == null ? null : () => showEvidence(context, s.section, s.evidence!),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.section, style: HiredText.h2.copyWith(color: c.text)),
                    const SizedBox(height: 4),
                    Text(s.note, style: HiredText.small.copyWith(color: c.text2)),
                    if (s.evidence != null) ...[
                      const SizedBox(height: 8),
                      Text('Tap to see the line this is based on', style: HiredText.tiny.copyWith(color: c.text3)),
                    ],
                  ]),
                ),
              ),
          ],
          if (flow.bullets.isNotEmpty) ...[
            const SizedBox(height: HiredSpace.xl),
            const SectionLabel('Tap a bullet to rewrite it'),
            const SizedBox(height: HiredSpace.md),
            for (final b in flow.bullets)
              Padding(
                padding: const EdgeInsets.only(bottom: HiredSpace.sm),
                child: Glass(
                  onTap: () => showRewriteSheet(context, bullet: b),
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Expanded(child: Text(b, style: HiredText.small.copyWith(color: c.text))),
                    const SizedBox(width: HiredSpace.md),
                    Icon(Icons.auto_fix_high_rounded, size: 20, color: c.ember),
                  ]),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Component extends StatelessWidget {
  const _Component(this.label, this.value, this.note);
  final String label;
  final int value;
  final String note;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: HiredText.body.copyWith(color: c.text, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text('$value', style: HiredText.num(22).copyWith(color: c.band(value))),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: value / 100,
          minHeight: 4,
          backgroundColor: c.track,
          color: c.ember,
        ),
      ),
      const SizedBox(height: 6),
      Text(note, style: HiredText.tiny.copyWith(color: c.text3)),
    ]);
  }
}

class _Skills extends StatelessWidget {
  const _Skills(this.title, this.items, this.tone);
  final String title;
  final List<Requirement> items;
  final TagTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionLabel('$title · ${items.length}'),
      const SizedBox(height: HiredSpace.md),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final r in items)
          GestureDetector(
            onTap: () => showEvidence(
              context,
              r.skill,
              r.evidence ?? (r.matched ? 'No single line quoted.' : 'Nothing in your resume states this.'),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(HiredRadii.chip),
                border: Border.all(color: c.hair),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(tone == TagTone.ok ? Icons.check_rounded : Icons.close_rounded, size: 14, color: tone == TagTone.ok ? c.ok : c.bad),
                const SizedBox(width: 5),
                Text(r.skill, style: HiredText.small.copyWith(color: c.text, fontWeight: r.required ? FontWeight.w600 : FontWeight.w400)),
              ]),
            ),
          ),
      ]),
    ]);
  }
}

/// Every score can be traced to the line it came from.
void showEvidence(BuildContext context, String title, String evidence, {bool quoted = true}) {
  final c = context.hc;
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    backgroundColor: c.ink2,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(HiredRadii.card))),
    builder: (sheet) => Padding(
      // useSafeArea leaves the bottom alone, so clear the system navigation bar here.
      padding: EdgeInsets.fromLTRB(
          HiredSpace.screen, HiredSpace.screen, HiredSpace.screen,
          HiredSpace.screen + MediaQuery.viewPaddingOf(sheet).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionLabel('Evidence'),
        const SizedBox(height: HiredSpace.sm),
        Text(title, style: HiredText.h2.copyWith(color: c.text)),
        const SizedBox(height: HiredSpace.md),
        Text(quoted ? '“$evidence”' : evidence,
            style: HiredText.body.copyWith(color: c.text2, fontStyle: quoted ? FontStyle.italic : FontStyle.normal)),
        const SizedBox(height: HiredSpace.xl),
      ]),
    ),
  );
}
