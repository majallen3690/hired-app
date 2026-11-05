import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/glass.dart';
import '../domain/interview_models.dart';
import '../domain/speech_metrics.dart';
import '../interview_controller.dart';
import 'interview_widgets.dart';
import '../../../core/motion/motion.dart';
import '../../../core/widgets/waiting.dart';

class InterviewLiveScreen extends ConsumerStatefulWidget {
  const InterviewLiveScreen({super.key});

  @override
  ConsumerState<InterviewLiveScreen> createState() => _State();
}

class _State extends ConsumerState<InterviewLiveScreen> {
  final _typed = TextEditingController();
  final _levels = <double>[];
  Timer? _tick;
  var _typing = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(
      const Duration(seconds: 1),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    _typed.dispose();
    super.dispose();
  }

  Future<bool> _confirmEnd() async {
    final c = context.hc;
    final end = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.ink2,
        title: Text(
          'End the interview?',
          style: HiredText.h2.copyWith(color: c.text),
        ),
        content: Text(
          'Your answers so far will be scored.',
          style: HiredText.body.copyWith(color: c.text2),
        ),
        actions: [
          TextAction(
            label: 'Keep going',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          TextAction(
            label: 'End and score',
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    return end ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final s = ref.watch(interviewControllerProvider);
    final ctl = ref.read(interviewControllerProvider.notifier);

    ref.listen(interviewControllerProvider, (prev, next) {
      if (next.phase == InterviewPhase.done && next.savedId != null) {
        context.pushReplacement('/interview/report/${next.savedId}');
      }
      if (next.level != prev?.level && next.phase == InterviewPhase.live) {
        _levels.add(next.level);
        if (_levels.length > 64) _levels.removeAt(0);
      }
    });

    final elapsed = s.startedAt == null
        ? 0
        : DateTime.now().difference(s.startedAt!).inMilliseconds;

    return PopScope(
      canPop:
          s.phase == InterviewPhase.failed || s.phase == InterviewPhase.idle,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (s.phase == InterviewPhase.live && await _confirmEnd()) ctl.finish();
      },
      child: Scaffold(
        backgroundColor: c.ink,
        body: Aurora(
          child: SafeArea(
            child: PhaseSwitcher(
              phase: s.phase == InterviewPhase.live ? 'live-${s.mode}' : s.phase.name,
              child: switch (s.phase) {
              InterviewPhase.connecting => _busy(
                c,
                'Connecting to your interviewer',
                'This takes a few seconds',
                s,
              ),
              InterviewPhase.wrapping => _busy(
                c,
                s.wrapStep,
                'Scoring every answer against what you said',
                s,
              ),
              InterviewPhase.failed => _failed(c, s, ctl),
              InterviewPhase.live =>
                s.mode == SessionMode.standard
                    ? _standard(c, s, ctl, elapsed)
                    : _live(c, s, ctl, elapsed),
              _ => const SizedBox.shrink(),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _busy(HiredPalette c, String title, String sub, InterviewState s) =>
      Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Orb(interviewerSpeaking: false, level: 0, busy: true),
            const SizedBox(height: HiredSpace.lg),
            Text(title, style: HiredText.h2.copyWith(color: c.text)),
            const SizedBox(height: HiredSpace.xs),
            Text(sub, style: HiredText.small.copyWith(color: c.text3)),
            const Padding(padding: EdgeInsets.symmetric(horizontal: HiredSpace.xxl, vertical: HiredSpace.xxl), child: TipRotator()),
          ],
        ),
      );

  Widget _failed(HiredPalette c, InterviewState s, InterviewController ctl) =>
      Padding(
        padding: const EdgeInsets.all(HiredSpace.screen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mic_off_rounded, color: c.bad, size: 40),
            const SizedBox(height: HiredSpace.lg),
            Text(
              'That did not work',
              style: HiredText.h1.copyWith(color: c.text),
            ),
            const SizedBox(height: HiredSpace.sm),
            Text(
              s.error ?? 'Something went wrong.',
              style: HiredText.body.copyWith(color: c.text2),
            ),
            const SizedBox(height: HiredSpace.xxl),
            PrimaryButton(
              label: 'Back',
              onPressed: () {
                ctl.reset();
                context.pop();
              },
            ),
          ],
        ),
      );

  Widget _topBar(HiredPalette c, InterviewState s, int elapsed) {
    final total = s.config?.questionCount ?? 5;
    final q = s.mode == SessionMode.standard
        ? (s.questionIndex + 1).clamp(1, total)
        : (s.answered + 1).clamp(1, total);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HiredSpace.screen,
        vertical: HiredSpace.md,
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c.bad, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            s.mode == SessionMode.live ? 'Live' : 'Standard mode',
            style: HiredText.label.copyWith(color: c.text2),
          ),
          const SizedBox(width: HiredSpace.md),
          Text(clock(elapsed), style: HiredText.label.copyWith(color: c.text3)),
          const Spacer(),
          Text(
            'Question $q of $total',
            style: HiredText.small.copyWith(color: c.text2),
          ),
        ],
      ),
    );
  }

  Widget _live(
    HiredPalette c,
    InterviewState s,
    InterviewController ctl,
    int elapsed,
  ) {
    final speech = summariseSpeech(s.turns);
    final last = s.turns.isEmpty ? null : s.turns.last;
    final who = last?.speaker == Speaker.candidate
        ? 'You · live transcript'
        : 'Interviewer';
    final tone = last?.speaker == Speaker.candidate ? c.ember : c.signal;
    return Column(
      children: [
        _topBar(c, s, elapsed),
        if (s.notice != null)
          Padding(
            padding: const EdgeInsets.only(bottom: HiredSpace.sm),
            child: Tag(s.notice!, tone: TagTone.warn),
          ),
        Orb(
          interviewerSpeaking: s.interviewerSpeaking,
          level: s.level,
          size: _typing ? 96 : 230,
        ),
        Text(
          s.reconnecting
              ? 'Reconnecting…'
              : (s.interviewerSpeaking
                    ? 'Interviewer is speaking'
                    : 'Listening to you'),
          style: HiredText.small.copyWith(color: c.text2),
        ),
        if (!_typing) ...[
          const SizedBox(height: HiredSpace.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: HiredSpace.screen),
            child: LevelWave(
              levels: _levels,
              color: s.interviewerSpeaking ? c.signal : c.ember,
            ),
          ),
        ],
        const SizedBox(height: HiredSpace.md),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: HiredSpace.screen),
            child: Glass(
              child: SingleChildScrollView(
                reverse: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      who.toUpperCase(),
                      style: HiredText.label.copyWith(color: tone),
                    ),
                    const SizedBox(height: HiredSpace.sm),
                    Text(
                      last?.text.trim().isEmpty ?? true
                          ? '…'
                          : last!.text.trim(),
                      style: HiredText.lead.copyWith(color: c.text),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!_typing)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HiredSpace.screen,
              HiredSpace.md,
              HiredSpace.screen,
              0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: MetricTile(
                    label: 'Fillers',
                    value: '${speech.fillerCount}',
                    note: speech.topFillers.isEmpty
                        ? null
                        : '${speech.topFillers.keys.first} ×${speech.topFillers.values.first}',
                  ),
                ),
                Expanded(
                  child: MetricTile(
                    label: 'Pace',
                    value: speech.wpm == null ? '–' : '${speech.wpm!.round()}',
                    unit: 'wpm',
                    note: paceNote(speech.wpm),
                  ),
                ),
                Expanded(
                  child: MetricTile(
                    label: 'Answered',
                    value: '${s.answered}',
                    unit: '/ ${s.config?.questionCount ?? 5}',
                  ),
                ),
              ],
            ),
          ),
        if (_typing)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HiredSpace.screen,
              HiredSpace.sm,
              HiredSpace.screen,
              0,
            ),
            child: _typeBox(c, ctl),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            HiredSpace.screen,
            HiredSpace.md,
            HiredSpace.screen,
            HiredSpace.lg,
          ),
          child: Row(
            children: [
              IconAction(
                icon: _typing
                    ? Icons.keyboard_hide_rounded
                    : Icons.keyboard_rounded,
                label: _typing ? 'Hide keyboard' : 'Type an answer',
                onPressed: () => setState(() => _typing = !_typing),
              ),
              const SizedBox(width: HiredSpace.md),
              Expanded(
                child: OutlineAction(
                  label: 'End',
                  icon: Icons.call_end_rounded,
                  onPressed: () async {
                    if (await _confirmEnd()) ctl.finish();
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _typeBox(HiredPalette c, InterviewController ctl) => TextField(
    controller: _typed,
    autofocus: true,
    textInputAction: TextInputAction.send,
    onSubmitted: (v) {
      ctl.sendText(v);
      _typed.clear();
    },
    style: HiredText.body.copyWith(color: c.text),
    decoration: InputDecoration(
      hintText: 'Type your answer and press send',
      hintStyle: HiredText.body.copyWith(color: c.text3),
      filled: true,
      fillColor: c.glassBottom,
      suffixIcon: IconButton(
        icon: Icon(Icons.send_rounded, color: c.ember),
        onPressed: () {
          ctl.sendText(_typed.text);
          _typed.clear();
        },
      ),
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
  );

  /// Standard mode: the same interview, one question at a time, answered by typing.
  Widget _standard(
    HiredPalette c,
    InterviewState s,
    InterviewController ctl,
    int elapsed,
  ) {
    final i = s.questionIndex.clamp(0, s.questions.length - 1);
    return Column(
      children: [
        _topBar(c, s, elapsed),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(HiredSpace.screen),
            children: [
              Text(
                'INTERVIEWER',
                style: HiredText.label.copyWith(color: c.signal),
              ),
              const SizedBox(height: HiredSpace.sm),
              Text(s.questions[i], style: HiredText.h2.copyWith(color: c.text)),
              const SizedBox(height: HiredSpace.xl),
              _typeBox(c, ctl),
              const SizedBox(height: HiredSpace.md),
              Text(
                'Answer the way you would out loud, in full sentences.',
                style: HiredText.tiny.copyWith(color: c.text3),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            HiredSpace.screen,
            0,
            HiredSpace.screen,
            HiredSpace.lg,
          ),
          child: OutlineAction(
            label: 'End and score',
            icon: Icons.call_end_rounded,
            onPressed: () async {
              if (await _confirmEnd()) ctl.finish();
            },
          ),
        ),
      ],
    );
  }
}
