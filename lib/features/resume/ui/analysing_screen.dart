import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/controls.dart';
import '../resume_flow.dart';

const _steps = [
  (FlowStage.reading, 'Reading your resume'),
  (FlowStage.comparing, 'Comparing with the job description'),
  (FlowStage.writing, 'Writing your fixes'),
];

class AnalysingScreen extends ConsumerWidget {
  const AnalysingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.hc;
    final flow = ref.watch(resumeFlowProvider);
    final order = FlowStage.values;

    ref.listen(resumeFlowProvider, (prev, next) {
      if (next.stage == FlowStage.done && prev?.stage != FlowStage.done) context.go('/resume/result');
    });

    if (flow.stage == FlowStage.failed) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(HiredSpace.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded, color: c.bad, size: 32),
              const SizedBox(height: HiredSpace.lg),
              Text('That did not work', style: HiredText.h1.copyWith(color: c.text)),
              const SizedBox(height: HiredSpace.sm),
              Text(flow.error ?? 'Something went wrong.', style: HiredText.body.copyWith(color: c.text2)),
              const SizedBox(height: HiredSpace.xxl),
              PrimaryButton(label: 'Try again', onPressed: () => ref.read(resumeFlowProvider.notifier).run()),
              const SizedBox(height: HiredSpace.sm),
              OutlineAction(label: 'Back', onPressed: () => context.go('/resume')),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(HiredSpace.screen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text.rich(TextSpan(style: HiredText.h1.copyWith(color: c.text), children: [
              const TextSpan(text: 'Comparing you with '),
              TextSpan(text: 'this role', style: HiredText.h1Em),
            ])),
            const SizedBox(height: HiredSpace.xxl),
            for (final (stage, label) in _steps) ...[
              _Step(
                label: label,
                done: order.indexOf(flow.stage) > order.indexOf(stage),
                active: flow.stage == stage,
              ),
              const SizedBox(height: HiredSpace.lg),
            ],
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.done, required this.active});
  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: done
              ? Icon(Icons.check_rounded, color: c.ok, size: 22)
              : active
                  ? CircularProgressIndicator(strokeWidth: 2, color: c.ember)
                  : Container(
                      margin: const EdgeInsets.all(6),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: c.track),
                    ),
        ),
        const SizedBox(width: HiredSpace.md),
        Text(label,
            style: HiredText.body.copyWith(
              color: active || done ? c.text : c.text3,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            )),
      ],
    );
  }
}
