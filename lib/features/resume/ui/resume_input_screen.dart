import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/glass.dart';
import '../resume_flow.dart';

class ResumeInputScreen extends ConsumerStatefulWidget {
  const ResumeInputScreen({super.key});

  @override
  ConsumerState<ResumeInputScreen> createState() => _State();
}

class _State extends ConsumerState<ResumeInputScreen> {
  late final _jd = TextEditingController(text: ref.read(resumeFlowProvider).jd);

  @override
  void dispose() {
    _jd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final flow = ref.watch(resumeFlowProvider);
    final notifier = ref.read(resumeFlowProvider.notifier);
    final jdLen = flow.jd.trim().length;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(HiredSpace.screen, HiredSpace.md, HiredSpace.screen, 120),
        children: [
          Text.rich(TextSpan(style: HiredText.h1.copyWith(color: c.text), children: [
            const TextSpan(text: 'How well do you '),
            TextSpan(text: 'fit', style: HiredText.h1Em),
            const TextSpan(text: ' this job?'),
          ])),
          const SizedBox(height: HiredSpace.xs),
          Text('Add your resume and the job description. You get a score you can trace back to your own lines.',
              style: HiredText.body.copyWith(color: c.text2)),
          const SizedBox(height: HiredSpace.xxl),
          const SectionLabel('Your resume'),
          const SizedBox(height: HiredSpace.sm),
          Glass(
            onTap: notifier.pickPdf,
            padding: const EdgeInsets.symmetric(horizontal: HiredSpace.lg, vertical: 14),
            child: Row(
              children: [
                Icon(flow.pdf == null ? Icons.upload_file_rounded : Icons.description_rounded,
                    color: flow.pdf == null ? c.text2 : c.ember),
                const SizedBox(width: HiredSpace.md),
                Expanded(
                  child: Text(flow.pdfName ?? 'Choose a PDF',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HiredText.body.copyWith(color: c.text, fontWeight: FontWeight.w500)),
                ),
                if (flow.pdf != null) Tag('${(flow.pdf!.length / 1024).round()} KB', tone: TagTone.signal),
              ],
            ),
          ),
          const SizedBox(height: HiredSpace.xl),
          const SectionLabel('Job description'),
          const SizedBox(height: HiredSpace.sm),
          TextField(
            controller: _jd,
            onChanged: notifier.setJd,
            minLines: 7,
            maxLines: 12,
            style: HiredText.body.copyWith(color: c.text),
            decoration: InputDecoration(
              hintText: 'Paste the full job description',
              hintStyle: HiredText.body.copyWith(color: c.text3),
              filled: true,
              fillColor: c.glassBottom,
              contentPadding: const EdgeInsets.all(HiredSpace.lg),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(HiredRadii.button),
                borderSide: BorderSide(color: c.hair),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(HiredRadii.button),
                borderSide: BorderSide(color: c.hair),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(HiredRadii.button),
                borderSide: BorderSide(color: c.ember, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: HiredSpace.sm),
          Text(jdLen < 40 ? 'A few more lines and we can start' : '$jdLen characters',
              style: HiredText.tiny.copyWith(color: c.text3)),
          const SizedBox(height: HiredSpace.xxl),
          PrimaryButton(
            label: 'Run match',
            icon: Icons.arrow_forward_rounded,
            onPressed: flow.canRun
                ? () {
                    notifier.run();
                    context.go('/resume/analysing');
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
