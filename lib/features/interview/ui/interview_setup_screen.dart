import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/glass.dart';
import '../../resume/resume_flow.dart';
import '../data/session_store.dart';
import '../domain/interview_models.dart';
import '../interview_controller.dart';

class InterviewSetupScreen extends ConsumerStatefulWidget {
  const InterviewSetupScreen({super.key});

  @override
  ConsumerState<InterviewSetupScreen> createState() => _State();
}

class _State extends ConsumerState<InterviewSetupScreen> {
  final _role = TextEditingController();
  final _company = TextEditingController();
  var _style = CompanyStyle.product;
  var _round = InterviewRound.technical;
  var _level = Difficulty.real;
  var _lang = InterviewLang.english;
  var _roleFilled = false;

  @override
  void dispose() {
    _role.dispose();
    _company.dispose();
    super.dispose();
  }

  List<String> _projects(Map<String, dynamic> resume) => [
        for (final p in (resume['projects'] as List? ?? const []))
          if (((p as Map)['name'] as String?)?.isNotEmpty ?? false) p['name'] as String,
      ];

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final flow = ref.watch(resumeFlowProvider);
    final resume = flow.resume;
    final sessions = ref.watch(sessionsProvider).asData?.value ?? const [];

    if (!_roleFilled && flow.targetRole != null) {
      _role.text = flow.targetRole!;
      _roleFilled = true;
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(HiredSpace.screen, HiredSpace.md, HiredSpace.screen, 120),
        children: [
          Text.rich(TextSpan(style: HiredText.h1.copyWith(color: c.text), children: [
            const TextSpan(text: 'Set up your '),
            TextSpan(text: 'mock', style: HiredText.h1Em),
          ])),
          const SizedBox(height: HiredSpace.xs),
          Text('A voice interview that asks about your own projects. Earphones help.',
              style: HiredText.body.copyWith(color: c.text2)),
          const SizedBox(height: HiredSpace.xxl),
          if (resume == null) ...[
            Glass(
              onTap: () => context.go('/resume'),
              child: Row(children: [
                Icon(Icons.description_rounded, color: c.ember),
                const SizedBox(width: HiredSpace.md),
                Expanded(
                  child: Text('Your interview is built from your resume. Run a resume match first.',
                      style: HiredText.body.copyWith(color: c.text)),
                ),
                Icon(Icons.arrow_forward_rounded, color: c.text2),
              ]),
            ),
          ] else ...[
            const SectionLabel('Role'),
            const SizedBox(height: HiredSpace.sm),
            _field(c, _role, 'Role, for example SDE-1', Icons.work_outline_rounded),
            const SizedBox(height: HiredSpace.md),
            _field(c, _company, 'Company (optional)', Icons.apartment_rounded),
            const SizedBox(height: HiredSpace.xl),
            const SectionLabel('Company style'),
            const SizedBox(height: HiredSpace.sm),
            Segmented<CompanyStyle>(
              options: const {CompanyStyle.product: 'Product', CompanyStyle.service: 'Service', CompanyStyle.startup: 'Startup'},
              value: _style,
              onChanged: (v) => setState(() => _style = v),
            ),
            const SizedBox(height: HiredSpace.xl),
            const SectionLabel('Round'),
            const SizedBox(height: HiredSpace.sm),
            Segmented<InterviewRound>(
              options: const {InterviewRound.hr: 'HR', InterviewRound.technical: 'Technical', InterviewRound.managerial: 'Managerial'},
              value: _round,
              onChanged: (v) => setState(() => _round = v),
            ),
            const SizedBox(height: HiredSpace.xl),
            const SectionLabel('Difficulty'),
            const SizedBox(height: HiredSpace.sm),
            Segmented<Difficulty>(
              options: const {Difficulty.warmup: 'Warm-up', Difficulty.real: 'Real', Difficulty.tough: 'Tough'},
              value: _level,
              onChanged: (v) => setState(() => _level = v),
            ),
            const SizedBox(height: HiredSpace.xl),
            const SectionLabel('Language'),
            const SizedBox(height: HiredSpace.sm),
            Segmented<InterviewLang>(
              options: const {InterviewLang.english: 'English', InterviewLang.hinglish: 'Hinglish'},
              value: _lang,
              onChanged: (v) => setState(() => _lang = v),
            ),
            if (_projects(resume).isNotEmpty) ...[
              const SizedBox(height: HiredSpace.xl),
              Row(children: [
                Icon(Icons.psychology_rounded, size: 18, color: c.signal),
                const SizedBox(width: HiredSpace.sm),
                Text('It will ask about your own projects', style: HiredText.small.copyWith(color: c.text2)),
              ]),
              const SizedBox(height: HiredSpace.sm),
              Wrap(spacing: HiredSpace.sm, runSpacing: HiredSpace.sm, children: [
                for (final p in _projects(resume)) HiredChip(label: p),
              ]),
            ],
            const SizedBox(height: HiredSpace.xxl),
            ListenableBuilder(
              listenable: _role,
              builder: (context, _) => PrimaryButton(
                label: 'Start interview',
                icon: Icons.mic_rounded,
                onPressed: _role.text.trim().length < 2
                    ? null
                    : () {
                        final config = InterviewConfig(
                          role: _role.text.trim(),
                          company: _company.text.trim(),
                          style: _style,
                          round: _round,
                          difficulty: _level,
                          language: _lang,
                        );
                        ref.read(interviewControllerProvider.notifier).start(config, resume);
                        context.push('/interview/live');
                      },
              ),
            ),
            const SizedBox(height: HiredSpace.sm),
            Center(child: Text('5 questions · about 10 minutes', style: HiredText.tiny.copyWith(color: c.text3))),
          ],
          if (sessions.isNotEmpty) ...[
            const SizedBox(height: 36),
            const SectionLabel('Recent'),
            const SizedBox(height: HiredSpace.sm),
            for (final s in sessions.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: HiredSpace.sm),
                child: Glass(
                  onTap: () => context.push('/interview/report/${s.id}'),
                  padding: const EdgeInsets.symmetric(horizontal: HiredSpace.lg, vertical: 14),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.config.title, style: HiredText.body.copyWith(color: c.text, fontWeight: FontWeight.w500)),
                        Text(_when(s.startedAt), style: HiredText.tiny.copyWith(color: c.text3)),
                      ]),
                    ),
                    if (s.evaluation != null)
                      Text('${s.evaluation!.interviewScore}',
                          style: HiredText.num(26).copyWith(color: c.band(s.evaluation!.interviewScore)))
                    else
                      Tag('Not scored', tone: TagTone.warn),
                  ]),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _when(DateTime t) {
    final l = t.toLocal();
    final now = DateTime.now();
    final today = l.year == now.year && l.month == now.month && l.day == now.day;
    final hm = '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
    return today ? 'Today, $hm' : '${l.day}/${l.month}, $hm';
  }

  Widget _field(HiredPalette c, TextEditingController ctl, String hint, IconData icon) => TextField(
        controller: ctl,
        style: HiredText.body.copyWith(color: c.text),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: HiredText.body.copyWith(color: c.text3),
          prefixIcon: Icon(icon, color: c.text2),
          filled: true,
          fillColor: c.glassBottom,
          contentPadding: const EdgeInsets.symmetric(horizontal: HiredSpace.lg, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(HiredRadii.button), borderSide: BorderSide(color: c.hair)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(HiredRadii.button), borderSide: BorderSide(color: c.hair)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(HiredRadii.button),
              borderSide: BorderSide(color: c.ember, width: 1.5)),
        ),
      );
}
