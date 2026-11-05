import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/glass.dart';
import '../../resume/resume_flow.dart';
import '../../resume/ui/result_screen.dart' show showEvidence;
import '../data/session_store.dart';
import '../domain/evaluation_models.dart';
import '../domain/interview_models.dart';
import '../domain/speech_metrics.dart';
import '../interview_controller.dart';
import 'interview_widgets.dart';
import '../../../core/motion/motion.dart';
import '../../../core/widgets/skeleton.dart';

class InterviewReportScreen extends ConsumerStatefulWidget {
  const InterviewReportScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<InterviewReportScreen> createState() => _State();
}

class _State extends ConsumerState<InterviewReportScreen> {
  final _open = <int>{};
  var _retrying = false;
  String? _retryError;

  Future<void> _retry() async {
    setState(() {
      _retrying = true;
      _retryError = null;
    });
    final ctl = ref.read(interviewControllerProvider.notifier);
    final resume = ref.read(resumeFlowProvider).resume;
    if (resume != null) ctl.setResume(resume);
    final err = await ctl.retryEvaluation(widget.id);
    if (mounted) {
      setState(() {
        _retrying = false;
        _retryError = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final async = ref.watch(sessionProvider(widget.id));
    final all = ref.watch(sessionsProvider).asData?.value ?? const [];

    return Scaffold(
      backgroundColor: c.ink,
      body: Aurora(
        child: SafeArea(
          child: async.when(
            loading: () => const Padding(padding: EdgeInsets.all(HiredSpace.screen), child: SkeletonCards(count: 3)),
            error: (e, _) => Center(child: Text('Could not open this report.', style: HiredText.body.copyWith(color: c.text2))),
            data: (r) {
              if (r == null) {
                return Center(child: Text('This session was not found.', style: HiredText.body.copyWith(color: c.text2)));
              }
              final previous = all
                  .where((s) => s.startedAt.isBefore(r.startedAt) && s.evaluation != null)
                  .map((s) => s.evaluation!.interviewScore)
                  .firstOrNull;
              return _body(c, r, previous);
            },
          ),
        ),
      ),
    );
  }

  Widget _body(HiredPalette c, SessionRecord r, int? previous) {
    final eval = r.evaluation;
    final speech = summariseSpeech(r.turns, pauses: r.pauses);
    final markers = buildMarkers(r.turns, r.pauses);
    final score = eval?.interviewScore;
    final delta = (score != null && previous != null) ? score - previous : null;

    return RevealListView(
      padding: const EdgeInsets.fromLTRB(HiredSpace.screen, HiredSpace.sm, HiredSpace.screen, HiredSpace.xxl),
      children: [
        Row(children: [
          IconButton(icon: Icon(Icons.close_rounded, color: c.text2), onPressed: () => context.go('/home')),
          Expanded(
            child: Text('${r.config.round.name[0].toUpperCase()}${r.config.round.name.substring(1)} round · ${r.config.title}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: HiredText.small.copyWith(color: c.text2)),
          ),
          if (r.mode == SessionMode.standard) const Tag('Standard mode', tone: TagTone.warn),
        ]),
        const SizedBox(height: HiredSpace.lg),
        if (score != null) ...[
          Center(
            child: TweenAnimationBuilder<double>(
              onEnd: Haptics.success,
              tween: Tween(begin: 0, end: score.toDouble()),
              duration: MediaQuery.of(context).disableAnimations ? Duration.zero : HiredMotion.scoreReveal,
              curve: HiredMotion.easeOutQuart,
              builder: (_, v, __) => Text('${v.round()}', style: HiredText.num(110).copyWith(color: c.band(score))),
            ),
          ),
          Center(child: Text('Interview score', style: HiredText.italic.copyWith(color: c.text3))),
          if (delta != null) ...[
            const SizedBox(height: HiredSpace.sm),
            Center(
              child: Tag('${delta >= 0 ? '▲' : '▼'} ${delta.abs()} since last mock',
                  tone: delta >= 0 ? TagTone.ok : TagTone.bad),
            ),
          ],
          const SizedBox(height: HiredSpace.lg),
          Center(child: Text(eval!.headline, textAlign: TextAlign.center, style: HiredText.h2.copyWith(color: c.text))),
        ] else ...[
          Glass(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Your session is saved, but it could not be scored yet.', style: HiredText.h2.copyWith(color: c.text)),
              const SizedBox(height: HiredSpace.sm),
              Text(_retryError ?? r.failedEvaluation ?? 'Scoring did not finish.',
                  style: HiredText.body.copyWith(color: c.text2)),
              const SizedBox(height: HiredSpace.lg),
              PrimaryButton(label: _retrying ? 'Scoring…' : 'Score it now', onPressed: _retrying ? null : _retry),
            ]),
          ),
        ],
        const SizedBox(height: HiredSpace.xs),
        Center(
          child: Text(
            '${clock(r.durationMs)} · ${eval?.questions.length ?? r.signals.length} '
            '${(eval?.questions.length ?? r.signals.length) == 1 ? 'question' : 'questions'} rated',
            style: HiredText.tiny.copyWith(color: c.text3),
          ),
        ),
        const SizedBox(height: HiredSpace.xxl),
        const SectionLabel('How you sounded · measured'),
        const SizedBox(height: HiredSpace.sm),
        _sounded(c, r, speech, markers),
        if (eval != null) ...[
          const SizedBox(height: HiredSpace.xxl),
          const SectionLabel('Question by question'),
          const SizedBox(height: HiredSpace.sm),
          for (var i = 0; i < eval.questions.length; i++) _question(c, i, eval.questions[i]),
          const SizedBox(height: HiredSpace.xl),
          const SectionLabel('Your top 3 fixes'),
          const SizedBox(height: HiredSpace.sm),
          for (var i = 0; i < eval.topFixes.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: HiredSpace.md),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${i + 1}', style: HiredText.num(26).copyWith(color: c.ember)),
                const SizedBox(width: HiredSpace.md),
                Expanded(child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(eval.topFixes[i], style: HiredText.body.copyWith(color: c.text)),
                )),
              ]),
            ),
        ],
        const SizedBox(height: HiredSpace.xl),
        if (r.audioFile != null) ...[
          PrimaryButton(
            label: 'Open Coach Replay',
            icon: Icons.replay_circle_filled_rounded,
            onPressed: () => context.push('/interview/replay/${r.id}'),
          ),
          const SizedBox(height: HiredSpace.md),
        ],
        Row(children: [
          Expanded(child: OutlineAction(label: 'Again', icon: Icons.replay_rounded, onPressed: () => context.go('/interview'))),
          const SizedBox(width: HiredSpace.md),
          Expanded(
            child: r.audioFile != null
                ? OutlineAction(label: 'My new score', icon: Icons.arrow_forward_rounded, onPressed: () => context.go('/home'))
                : PrimaryButton(label: 'My new score', icon: Icons.arrow_forward_rounded, onPressed: () => context.go('/home')),
          ),
        ]),
      ],
    );
  }

  Widget _sounded(HiredPalette c, SessionRecord r, SpeechSummary speech, List<Marker> markers) {
    final fillerQuotes = markers.where((m) => m.kind == MarkerKind.filler).map((m) => '${m.evidence}  (${clock(m.atMs)})');
    final spoken = r.turns.any((t) => t.speaker == Speaker.candidate && !t.typed);
    if (!spoken) {
      return Glass(
        child: Text('You typed your answers, so pace, fillers and pauses were not measured. Speak next time to get them.',
            style: HiredText.body.copyWith(color: c.text2)),
      );
    }
    return Glass(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: MetricTile(
              label: 'Speaking score',
              value: r.communication == null ? '–' : '${r.communication}',
              note: r.communication == null ? 'Too little speech to judge' : 'pace, fillers, pauses',
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
        ]),
        const SizedBox(height: HiredSpace.sm),
        Row(children: [
          Expanded(
            child: MetricTile(
              label: 'Fillers',
              value: '${speech.fillerCount}',
              note: speech.topFillers.isEmpty
                  ? 'none heard'
                  : speech.topFillers.entries.take(2).map((e) => '${e.key} ×${e.value}').join(', '),
              onTap: fillerQuotes.isEmpty ? null : () => showEvidence(context, 'Filler words', fillerQuotes.join('\n')),
            ),
          ),
          Expanded(
            child: MetricTile(
              label: 'Long pauses',
              value: '${speech.longPauses}',
              note: speech.longPauses == 0 ? 'none over 4 s' : 'over 4 seconds',
            ),
          ),
        ]),
        const SizedBox(height: HiredSpace.sm),
        Text('Measured from your voice and the transcript, not guessed by the AI.',
            style: HiredText.tiny.copyWith(color: c.text3)),
      ]),
    );
  }

  Widget _question(HiredPalette c, int i, QuestionEval q) {
    final open = _open.contains(i);
    final score = (q.score * 20).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: HiredSpace.md),
      child: Glass(
        onTap: () => setState(() => open ? _open.remove(i) : _open.add(i)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Q${i + 1}', style: HiredText.label.copyWith(color: c.text3)),
            const SizedBox(width: HiredSpace.md),
            Expanded(child: Text(q.question, maxLines: open ? 5 : 2, overflow: TextOverflow.ellipsis,
                style: HiredText.body.copyWith(color: c.text, fontWeight: FontWeight.w500))),
            const SizedBox(width: HiredSpace.md),
            Text(q.score.toStringAsFixed(1), style: HiredText.num(26).copyWith(color: c.band(score))),
          ]),
          if (open) ...[
            const SizedBox(height: HiredSpace.lg),
            Row(children: [
              for (final (label, on) in [('S', q.situation), ('T', q.task), ('A', q.action), ('R', q.result)])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: on ? c.ok.withValues(alpha: 0.18) : c.bad.withValues(alpha: 0.12),
                      border: Border.all(color: on ? c.ok : c.bad, width: 1),
                    ),
                    child: Text(label, style: HiredText.label.copyWith(color: on ? c.ok : c.bad)),
                  ),
                ),
              const SizedBox(width: 6),
              Text(q.result ? 'Story complete' : 'Result missing', style: HiredText.tiny.copyWith(color: c.text3)),
            ]),
            const SizedBox(height: HiredSpace.md),
            for (final (label, d) in q.dimensions) _dim(c, label, d),
            const SizedBox(height: HiredSpace.md),
            _note(c, 'Worked', q.good, c.ok),
            const SizedBox(height: HiredSpace.sm),
            _note(c, 'Fix', q.fix, c.ember),
            const SizedBox(height: HiredSpace.md),
            TextAction(
              label: 'See a model answer',
              onPressed: () => showEvidence(context, 'Model answer', q.modelAnswer, quoted: false),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _dim(HiredPalette c, String label, Dimension d) => InkWell(
        onTap: d.evidence == null ? null : () => showEvidence(context, label, d.evidence!),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            SizedBox(width: 84, child: Text(label, style: HiredText.small.copyWith(color: c.text2))),
            for (var k = 1; k <= 5; k++)
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(right: 5),
                decoration: BoxDecoration(shape: BoxShape.circle, color: k <= d.score ? c.band(d.score * 20) : c.track),
              ),
            const Spacer(),
            Text(d.evidence == null ? 'no quote found' : 'tap for the line',
                style: HiredText.tiny.copyWith(color: c.text3)),
          ]),
        ),
      );

  Widget _note(HiredPalette c, String tag, String text, Color tone) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 56, child: Text(tag.toUpperCase(), style: HiredText.label.copyWith(color: tone))),
          Expanded(child: Text(text, style: HiredText.small.copyWith(color: c.text))),
        ],
      );
}
