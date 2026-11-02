import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/glass.dart';
import '../../interview/domain/speech_metrics.dart';
import '../../interview/ui/interview_widgets.dart' show LevelWave, Orb;
import '../../resume/resume_flow.dart';
import '../data/intro_store.dart';
import '../domain/intro_analysis.dart';
import '../intro_controller.dart';
import 'countdown_ring.dart';
import '../../../core/motion/motion.dart';

class IntroRecorderScreen extends ConsumerStatefulWidget {
  const IntroRecorderScreen({super.key});

  @override
  ConsumerState<IntroRecorderScreen> createState() => _State();
}

class _State extends ConsumerState<IntroRecorderScreen> {
  final _target = TextEditingController();
  final _typed = TextEditingController();
  var _typing = false;
  var _targetFilled = false;

  @override
  void dispose() {
    _target.dispose();
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final s = ref.watch(introControllerProvider);
    final ctl = ref.read(introControllerProvider.notifier);
    final role = ref.watch(resumeFlowProvider.select((f) => f.targetRole));

    if (!_targetFilled && role != null) {
      _target.text = role;
      _targetFilled = true;
      ctl.setTarget(role);
    }

    ref.listen(introControllerProvider, (prev, next) {
      if (next.savedId != null && next.savedId != prev?.savedId) {
        context.pushReplacement('/intro/result/${next.savedId}');
      }
    });

    return PopScope(
      canPop: s.phase == IntroPhase.idle || s.phase == IntroPhase.failed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && s.phase == IntroPhase.recording) ctl.restart();
      },
      child: Scaffold(
        backgroundColor: c.ink,
        resizeToAvoidBottomInset: true,
        body: Aurora(
          child: SafeArea(
            child: PhaseSwitcher(
              phase: switch (s.phase) {
                IntroPhase.transcribing || IntroPhase.scoring => 'busy',
                IntroPhase.idle => _typing ? 'typing' : 'idle',
                _ => s.phase.name,
              },
              child: switch (s.phase) {
                IntroPhase.recording => _recording(c, s, ctl),
                IntroPhase.transcribing || IntroPhase.scoring => _busy(c, s),
                IntroPhase.failed => _failed(c, s, ctl),
                IntroPhase.idle => _typing ? _typingView(c, s, ctl) : _idle(c, s, ctl),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(HiredPalette c, {required String title, Widget? trailing, VoidCallback? onClose}) => Padding(
        padding: const EdgeInsets.fromLTRB(HiredSpace.sm, HiredSpace.sm, HiredSpace.screen, 0),
        child: Row(children: [
          IconButton(
            icon: Icon(Icons.close_rounded, color: c.text2),
            tooltip: 'Close',
            onPressed: onClose ?? () => context.go('/home'),
          ),
          Expanded(child: Center(child: Text(title, style: HiredText.body.copyWith(color: c.text, fontWeight: FontWeight.w600)))),
          SizedBox(width: 48, child: trailing),
        ]),
      );

  Widget _idle(HiredPalette c, IntroState s, IntroController ctl) {
    final last = (ref.watch(introsProvider).asData?.value ?? const []).where((i) => i.score != null).firstOrNull;
    return Column(children: [
      _header(c, title: 'Your 60-second intro'),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(HiredSpace.screen, HiredSpace.lg, HiredSpace.screen, HiredSpace.xxl),
          children: [
            Text('Who you are, what you have built, and why this role.',
                textAlign: TextAlign.center, style: HiredText.body.copyWith(color: c.text2)),
            const SizedBox(height: HiredSpace.xl),
            Center(
              child: CountdownRing(
                secondsLeft: introSeconds,
                size: 240,
                child: const DialReadout(secondsLeft: introSeconds),
              ),
            ),
            const SizedBox(height: HiredSpace.xl),
            if (s.notice != null) ...[
              Glass(
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline_rounded, color: c.warn, size: 20),
                  const SizedBox(width: HiredSpace.md),
                  Expanded(child: Text(s.notice!, style: HiredText.body.copyWith(color: c.text))),
                ]),
              ),
              const SizedBox(height: HiredSpace.lg),
            ],
            _field(c, _target, 'Role you are aiming for (optional)', Icons.work_outline_rounded, ctl.setTarget),
            const SizedBox(height: HiredSpace.xs),
            Text('So your “why” can be judged against it.', style: HiredText.tiny.copyWith(color: c.text3)),
            const SizedBox(height: HiredSpace.xl),
            Center(child: _RoundButton(label: 'Start recording', onTap: ctl.start, child: Icon(Icons.mic_rounded, color: c.onEmber, size: 34))),
            const SizedBox(height: HiredSpace.sm),
            Center(child: Text('Tap to start', style: HiredText.small.copyWith(color: c.text3))),
            Center(
              child: TextAction(
                label: 'Type it instead',
                onPressed: () {
                  ctl.clearNotice();
                  setState(() => _typing = true);
                },
              ),
            ),
            if (last != null) ...[
              const SizedBox(height: HiredSpace.lg),
              Glass(
                onTap: () => context.push('/intro/result/${last.id}'),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Last try', style: HiredText.small.copyWith(color: c.text3)),
                      Text(last.evaluation!.headline,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: HiredText.body.copyWith(color: c.text)),
                    ]),
                  ),
                  Text('${last.score}', style: HiredText.num(30).copyWith(color: c.band(last.score!))),
                ]),
              ),
            ],
            const SizedBox(height: HiredSpace.xl),
            const SectionLabel('Before you start'),
            const SizedBox(height: HiredSpace.sm),
            for (final tip in const [
              'Say your name, year and college in the first five seconds.',
              'Give one thing you built, with a real detail.',
              'Finish with why this role. Pause instead of saying “um”.',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: HiredSpace.sm),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: HiredSpace.md),
                    child: Container(width: 5, height: 5, decoration: BoxDecoration(color: c.ember, shape: BoxShape.circle)),
                  ),
                  Expanded(child: Text(tip, style: HiredText.body.copyWith(color: c.text2))),
                ]),
              ),
          ],
        ),
      ),
    ]);
  }

  Widget _recording(HiredPalette c, IntroState s, IntroController ctl) {
    final recent = s.levels.length < 5 ? <double>[] : s.levels.sublist(s.levels.length - 5);
    final quiet = recent.isNotEmpty && recent.reduce((a, b) => a + b) / recent.length < 0.2;
    return Column(children: [
      _header(
        c,
        title: 'Recording',
        onClose: ctl.restart,
        trailing: Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(color: c.bad, shape: BoxShape.circle))),
      ),
      const SizedBox(height: HiredSpace.xl),
      Center(
        child: CountdownRing(
          secondsLeft: s.secondsLeft,
          child: DialReadout(secondsLeft: s.secondsLeft, below: SizedBox(width: 130, child: LevelWave(levels: s.levels, color: c.ember))),
        ),
      ),
      const SizedBox(height: HiredSpace.xl),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: HiredSpace.screen),
        child: Glass(
          child: Row(children: [
            Icon(quiet ? Icons.volume_down_rounded : Icons.graphic_eq_rounded, color: quiet ? c.warn : c.ok, size: 22),
            const SizedBox(width: HiredSpace.md),
            Expanded(
              child: Text(
                quiet ? 'Your voice is quiet. Speak up a little.' : 'Good level. Your words appear when you stop.',
                style: HiredText.body.copyWith(color: c.text),
              ),
            ),
          ]),
        ),
      ),
      const Spacer(),
      Padding(
        padding: const EdgeInsets.only(bottom: HiredSpace.xxl),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton.outlined(
            onPressed: ctl.restart,
            tooltip: 'Start over',
            icon: Icon(Icons.restart_alt_rounded, color: c.text2),
            style: IconButton.styleFrom(minimumSize: const Size(56, 56), side: BorderSide(color: c.hair)),
          ),
          const SizedBox(width: 36),
          _RoundButton(
            label: 'Stop and score',
            onTap: ctl.stop,
            child: Container(width: 28, height: 28, decoration: BoxDecoration(color: c.onEmber, borderRadius: BorderRadius.circular(8))),
          ),
          const SizedBox(width: 36 + 56),
        ]),
      ),
    ]);
  }

  Widget _busy(HiredPalette c, IntroState s) {
    final transcribing = s.phase == IntroPhase.transcribing;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Orb(interviewerSpeaking: false, level: 0, busy: true, size: 200),
        const SizedBox(height: HiredSpace.lg),
        Text(transcribing ? 'Writing down what you said' : 'Scoring your intro', style: HiredText.h2.copyWith(color: c.text)),
        const SizedBox(height: HiredSpace.xs),
        Text(
          transcribing ? 'Step 1 of 2' : 'Step 2 of 2 · checking each point against your words',
          style: HiredText.small.copyWith(color: c.text3),
        ),
      ]),
    );
  }

  Widget _failed(HiredPalette c, IntroState s, IntroController ctl) => Padding(
        padding: const EdgeInsets.all(HiredSpace.screen),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.cloud_off_rounded, color: c.bad, size: 40),
          const SizedBox(height: HiredSpace.lg),
          Text('That did not work', style: HiredText.h1.copyWith(color: c.text)),
          const SizedBox(height: HiredSpace.sm),
          Text(s.error ?? 'Something went wrong.', style: HiredText.body.copyWith(color: c.text2)),
          const SizedBox(height: HiredSpace.sm),
          Text('Your recording is still here, so you do not need to say it again.', style: HiredText.small.copyWith(color: c.text3)),
          const SizedBox(height: HiredSpace.xxl),
          PrimaryButton(label: 'Try again', onPressed: ctl.retryProcessing),
          const SizedBox(height: HiredSpace.sm),
          Center(child: TextAction(label: 'Record again', onPressed: ctl.restart)),
        ]),
      );

  Widget _typingView(HiredPalette c, IntroState s, IntroController ctl) => Column(children: [
        _header(c, title: 'Type your intro', onClose: () => setState(() => _typing = false)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(HiredSpace.screen, HiredSpace.lg, HiredSpace.screen, HiredSpace.xxl),
            children: [
              Text('Write it the way you would say it. Typed intros are scored on content only, not delivery.',
                  style: HiredText.body.copyWith(color: c.text2)),
              const SizedBox(height: HiredSpace.lg),
              if (s.notice != null) ...[
                Text(s.notice!, style: HiredText.small.copyWith(color: c.warn)),
                const SizedBox(height: HiredSpace.sm),
              ],
              _field(c, _target, 'Role you are aiming for (optional)', Icons.work_outline_rounded, ctl.setTarget),
              const SizedBox(height: HiredSpace.md),
              TextField(
                controller: _typed,
                minLines: 8,
                maxLines: 14,
                textCapitalization: TextCapitalization.sentences,
                style: HiredText.body.copyWith(color: c.text),
                decoration: _decoration(c, 'Hi, I am…'),
              ),
              const SizedBox(height: HiredSpace.sm),
              ListenableBuilder(
                listenable: _typed,
                builder: (context, _) {
                  final words = wordCount(_typed.text);
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$words words · about ${spokenSeconds(_typed.text)} seconds spoken',
                        style: HiredText.tiny.copyWith(color: words >= minIntroWords ? c.text3 : c.warn)),
                    const SizedBox(height: HiredSpace.xl),
                    PrimaryButton(
                      label: 'Score my intro',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: words < minIntroWords ? null : () => ctl.submitTyped(_typed.text),
                    ),
                  ]);
                },
              ),
              Center(child: TextAction(label: 'Use the microphone', onPressed: () => setState(() => _typing = false))),
            ],
          ),
        ),
      ]);

  Widget _field(HiredPalette c, TextEditingController ctl, String hint, IconData icon, ValueChanged<String> onChanged) =>
      TextField(
        controller: ctl,
        onChanged: onChanged,
        style: HiredText.body.copyWith(color: c.text),
        decoration: _decoration(c, hint, icon: icon),
      );

  InputDecoration _decoration(HiredPalette c, String hint, {IconData? icon}) => InputDecoration(
        hintText: hint,
        hintStyle: HiredText.body.copyWith(color: c.text3),
        prefixIcon: icon == null ? null : Icon(icon, color: c.text2),
        filled: true,
        fillColor: c.glassBottom,
        contentPadding: const EdgeInsets.symmetric(horizontal: HiredSpace.lg, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(HiredRadii.button), borderSide: BorderSide(color: c.hair)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(HiredRadii.button), borderSide: BorderSide(color: c.hair)),
        focusedBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(HiredRadii.button), borderSide: BorderSide(color: c.ember, width: 1.5)),
      );
}

/// The one big record and stop control.
class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.label, required this.onTap, required this.child});
  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 88,
          height: 88,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.ember,
            boxShadow: [BoxShadow(color: c.ember.withValues(alpha: 0.18), spreadRadius: 6, blurRadius: 0)],
          ),
          child: child,
        ),
      ),
    );
  }
}
