import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/glass.dart';
import '../../interview/domain/speech_metrics.dart';
import '../../interview/ui/interview_widgets.dart' show clock, paceNote;
import '../../resume/ui/result_screen.dart' show showEvidence;
import '../data/intro_store.dart';
import '../domain/intro_analysis.dart';
import '../domain/intro_models.dart';
import '../intro_controller.dart';

class IntroResultScreen extends ConsumerStatefulWidget {
  const IntroResultScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<IntroResultScreen> createState() => _State();
}

class _State extends ConsumerState<IntroResultScreen> {
  var _retrying = false;
  String? _retryError;

  Future<void> _retry() async {
    setState(() {
      _retrying = true;
      _retryError = null;
    });
    final err = await ref.read(introControllerProvider.notifier).retryEvaluation(widget.id);
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
    // The controller disposes itself when nothing listens; "Score it now" calls it after awaits, so keep it alive.
    ref.watch(introControllerProvider);
    final async = ref.watch(introProvider(widget.id));
    final all = ref.watch(introsProvider).asData?.value ?? const [];
    return Scaffold(
      backgroundColor: c.ink,
      body: Aurora(
        child: SafeArea(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Could not open this intro.', style: HiredText.body.copyWith(color: c.text2))),
            data: (r) {
              if (r == null) {
                return Center(child: Text('This intro was not found.', style: HiredText.body.copyWith(color: c.text2)));
              }
              // Typed and spoken intros are scored differently, so only like is compared with like.
              final previous = all
                  .where((i) => i.startedAt.isBefore(r.startedAt) && i.score != null && i.mode == r.mode)
                  .firstOrNull;
              return _body(c, r, previous);
            },
          ),
        ),
      ),
    );
  }

  Widget _body(HiredPalette c, IntroRecord r, IntroRecord? previous) {
    final e = r.evaluation;
    final score = r.score;
    final delta = (score != null && previous != null) ? score - previous.score! : null;
    final changes = (previous != null) ? compareIntros(previous, r) : const <IntroChange>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(HiredSpace.screen, HiredSpace.sm, HiredSpace.screen, HiredSpace.xxl),
      children: [
        Row(children: [
          IconButton(icon: Icon(Icons.close_rounded, color: c.text2), tooltip: 'Close', onPressed: () => context.go('/home')),
          Expanded(
            child: Center(
              child: Text(r.mode == IntroMode.typed ? 'Your intro' : 'Your 60-second intro',
                  style: HiredText.body.copyWith(color: c.text, fontWeight: FontWeight.w600)),
            ),
          ),
          SizedBox(width: 48, child: r.audioFile == null ? null : _PlayButton(record: r)),
        ]),
        const SizedBox(height: HiredSpace.lg),
        if (e != null && score != null) ...[
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: score.toDouble()),
              duration: MediaQuery.of(context).disableAnimations ? Duration.zero : HiredMotion.scoreReveal,
              curve: HiredMotion.easeOutQuart,
              builder: (_, v, __) => Text('${v.round()}', style: HiredText.num(110).copyWith(color: c.band(score))),
            ),
          ),
          Center(child: Text('Intro score', style: HiredText.italic.copyWith(color: c.text3))),
          if (delta != null) ...[
            const SizedBox(height: HiredSpace.sm),
            Center(
              child: delta == 0
                  ? const Tag('Same as last try', tone: TagTone.signal)
                  : Tag('${delta > 0 ? '▲' : '▼'} ${delta.abs()} since last try', tone: delta > 0 ? TagTone.ok : TagTone.bad),
            ),
          ],
          const SizedBox(height: HiredSpace.lg),
          Center(child: Text(e.headline, textAlign: TextAlign.center, style: HiredText.h2.copyWith(color: c.text))),
          if (r.mode == IntroMode.typed) ...[
            const SizedBox(height: HiredSpace.sm),
            Center(
              child: Text('Typed, so scored on content only. Say it out loud to score your delivery too.',
                  textAlign: TextAlign.center, style: HiredText.tiny.copyWith(color: c.text3)),
            ),
          ],
          const SizedBox(height: HiredSpace.xl),
          _ratings(c, e),
          const SizedBox(height: HiredSpace.xl),
          const SectionLabel('Who, what, why'),
          const SizedBox(height: HiredSpace.sm),
          _parts(c, e),
          if (r.delivery != null) ...[
            const SizedBox(height: HiredSpace.xl),
            const SectionLabel('How you sounded · measured'),
            const SizedBox(height: HiredSpace.sm),
            _delivery(c, r.delivery!),
          ],
          if (changes.isNotEmpty) ...[
            const SizedBox(height: HiredSpace.xl),
            const SectionLabel('Since your last try'),
            const SizedBox(height: HiredSpace.sm),
            _changes(c, changes),
          ],
          const SizedBox(height: HiredSpace.xl),
          _coaching(c, e),
          const SizedBox(height: HiredSpace.xl),
          _stronger(c, e),
        ] else
          Glass(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Your intro is saved, but it could not be scored yet.', style: HiredText.h2.copyWith(color: c.text)),
              const SizedBox(height: HiredSpace.sm),
              Text(_retryError ?? r.failed ?? 'Scoring did not finish.', style: HiredText.body.copyWith(color: c.text2)),
              const SizedBox(height: HiredSpace.lg),
              PrimaryButton(label: _retrying ? 'Scoring…' : 'Score it now', onPressed: _retrying ? null : _retry),
            ]),
          ),
        const SizedBox(height: HiredSpace.xl),
        const SectionLabel('What you said'),
        const SizedBox(height: HiredSpace.sm),
        _transcript(c, r),
        const SizedBox(height: HiredSpace.xxl),
        OutlineAction(label: 'Record another try', icon: Icons.mic_rounded, onPressed: () => context.go('/intro')),
      ],
    );
  }

  Widget _ratings(HiredPalette c, IntroEvaluation e) {
    final capped = e.structureScore < e.structure.score;
    Widget tile(String label, int value, String? evidence, {String? note}) => Expanded(
          child: Glass(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            onTap: evidence == null ? null : () => showEvidence(context, '$label: $value of 5', evidence),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: HiredText.small.copyWith(color: c.text, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text('$value', style: HiredText.num(30).copyWith(color: c.text)),
                Text(' /5', style: HiredText.tiny.copyWith(color: c.text3)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(value: value / 5, minHeight: 4, backgroundColor: c.track, color: c.band(value * 20)),
              ),
              if (note != null) ...[
                const SizedBox(height: 6),
                Text(note, style: HiredText.tiny.copyWith(color: c.text3)),
              ],
            ]),
          ),
        );

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      tile('Clarity', e.clarity.score, e.clarity.evidence),
      const SizedBox(width: HiredSpace.sm),
      tile('Structure', e.structureScore, e.structure.evidence, note: capped ? 'Capped: a part is missing' : null),
      const SizedBox(width: HiredSpace.sm),
      tile('Confidence', e.confidence.score, e.confidence.evidence),
    ]);
  }

  Widget _parts(HiredPalette c, IntroEvaluation e) {
    const labels = {IntroPart.who: 'Who', IntroPart.what: 'What', IntroPart.why: 'Why'};
    return Glass(
      child: Column(children: [
        for (final p in IntroPart.values)
          InkWell(
            onTap: e.part(p).evidence == null ? null : () => showEvidence(context, labels[p]!, e.part(p).evidence!),
            borderRadius: BorderRadius.circular(HiredRadii.chip),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 64,
                  child: Tag(labels[p]!, tone: e.part(p).covered ? TagTone.ok : TagTone.bad),
                ),
                const SizedBox(width: HiredSpace.md),
                Expanded(child: Text(e.part(p).note, style: HiredText.small.copyWith(color: c.text))),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _delivery(HiredPalette c, IntroDelivery d) {
    Widget cell(String value, String label, String note, {Color? tone}) => Expanded(
          child: Column(children: [
            Text(value, style: HiredText.num(26).copyWith(color: tone ?? c.text)),
            Text(label, style: HiredText.small.copyWith(color: c.text2)),
            Text(note, textAlign: TextAlign.center, style: HiredText.tiny.copyWith(color: c.text3)),
          ]),
        );
    final fillerNote = d.topFillers.isEmpty
        ? 'none heard'
        : d.topFillers.entries.take(2).map((e) => '${e.key} ×${e.value}').join(', ');
    final pause = d.longestPause;
    return Glass(
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          cell('${d.fillerCount}', 'fillers', fillerNote, tone: d.fillerCount == 0 ? c.ok : c.warn),
          cell(d.wpm == null ? '–' : '${d.wpm!.round()}', 'wpm', paceNote(d.wpm),
              tone: d.wpm == null ? null : (d.wpm! >= idealPaceMin && d.wpm! <= idealPaceMax ? c.ok : c.warn)),
          cell(pause == null ? 'none' : '${(pause.lengthMs / 1000).toStringAsFixed(1)}s', 'longest pause',
              pause == null ? 'smooth' : 'at ${clock(pause.startMs).replaceFirst(RegExp(r'^0'), '')}'),
        ]),
        const SizedBox(height: HiredSpace.md),
        Divider(color: c.hair, height: 1),
        const SizedBox(height: HiredSpace.md),
        Row(children: [
          Icon(Icons.graphic_eq_rounded, size: 18, color: c.text2),
          const SizedBox(width: HiredSpace.sm),
          Text('Volume: ${steadinessLabel(d.steadinessDb)}', style: HiredText.small.copyWith(color: c.text2)),
          const Spacer(),
          if (d.score != null) Text('Delivery ${d.score}', style: HiredText.small.copyWith(color: c.text3)),
        ]),
      ]),
    );
  }

  Widget _changes(HiredPalette c, List<IntroChange> changes) => Glass(
        child: Column(children: [
          for (final ch in changes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Icon(ch.better ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    size: 18, color: ch.better ? c.ok : c.bad),
                const SizedBox(width: HiredSpace.md),
                Expanded(child: Text(ch.text, style: HiredText.body.copyWith(color: c.text))),
              ]),
            ),
        ]),
      );

  Widget _coaching(HiredPalette c, IntroEvaluation e) => Glass(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.check_circle_outline_rounded, size: 18, color: c.ok),
            const SizedBox(width: HiredSpace.sm),
            Text('Did well', style: HiredText.small.copyWith(color: c.ok, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          Text(e.good, style: HiredText.body.copyWith(color: c.text)),
          const SizedBox(height: HiredSpace.lg),
          Row(children: [
            Icon(Icons.flag_outlined, size: 18, color: c.warn),
            const SizedBox(width: HiredSpace.sm),
            Text('Fix first', style: HiredText.small.copyWith(color: c.warn, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          Text(e.fix, style: HiredText.body.copyWith(color: c.text)),
        ]),
      );

  Widget _stronger(HiredPalette c, IntroEvaluation e) {
    final base = HiredText.body.copyWith(color: c.text, fontWeight: FontWeight.w600, height: 1.55);
    return Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(HiredRadii.card + 1),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.ember.withValues(alpha: 0.9), c.ember.withValues(alpha: 0.25), c.hair],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(HiredSpace.lg + 2),
        decoration: BoxDecoration(color: c.ink2, borderRadius: BorderRadius.circular(HiredRadii.card)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('A STRONGER VERSION', style: HiredText.label.copyWith(color: c.ember))),
            Text('${spokenSeconds(e.stronger)} seconds', style: HiredText.small.copyWith(color: c.text3)),
          ]),
          const SizedBox(height: HiredSpace.md),
          Text.rich(TextSpan(style: base, children: _withPlaceholders(e.stronger, base, c))),
          const SizedBox(height: HiredSpace.sm),
          Text('Built only from your words, your resume and your target role. Fill any [highlighted] part with your own detail.',
              style: HiredText.tiny.copyWith(color: c.text3)),
          const SizedBox(height: HiredSpace.lg),
          // The theme's buttons are full width, so they stack instead of sharing a row.
          PrimaryButton(label: 'Practise this one', icon: Icons.mic_rounded, onPressed: () => context.go('/intro')),
          const SizedBox(height: HiredSpace.sm),
          OutlineAction(
            label: 'Copy',
            icon: Icons.content_copy_rounded,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: e.stronger));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
              }
            },
          ),
        ]),
      ),
    );
  }

  List<InlineSpan> _withPlaceholders(String text, TextStyle base, HiredPalette c) {
    final spans = <InlineSpan>[];
    var at = 0;
    for (final m in RegExp(r'\[[^\]]*\]').allMatches(text)) {
      if (m.start > at) spans.add(TextSpan(text: text.substring(at, m.start)));
      spans.add(TextSpan(
        text: m.group(0),
        style: base.copyWith(color: c.warn, backgroundColor: c.warn.withValues(alpha: 0.12)),
      ));
      at = m.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return spans;
  }

  Widget _transcript(HiredPalette c, IntroRecord r) {
    final base = HiredText.body.copyWith(color: c.text, height: 1.55);
    final spans = <InlineSpan>[];
    var at = 0;
    // Fillers are only meaningful in speech; a typed intro has none to flag.
    final fillers = r.mode == IntroMode.spoken ? findFillers(r.transcript) : const <FillerHit>[];
    for (final h in fillers) {
      if (h.start > at) spans.add(TextSpan(text: r.transcript.substring(at, h.start)));
      spans.add(TextSpan(
        text: r.transcript.substring(h.start, h.end),
        style: base.copyWith(color: c.warn, decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.wavy, decorationColor: c.warn),
      ));
      at = h.end;
    }
    if (at < r.transcript.length) spans.add(TextSpan(text: r.transcript.substring(at)));
    return Glass(child: Text.rich(TextSpan(style: base, children: spans)));
  }
}

class _PlayButton extends StatefulWidget {
  const _PlayButton({required this.record});
  final IntroRecord record;

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
  AudioPlayer? _player;
  var _loaded = false;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final player = _player ??= AudioPlayer();
    if (!_loaded) {
      final path = await IntroStore().audioPath(widget.record);
      if (path == null) return;
      await player.setFilePath(path);
      _loaded = true;
    }
    if (player.playing) {
      await player.pause();
    } else {
      if (player.processingState == ProcessingState.completed) await player.seek(Duration.zero);
      await player.play();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final player = _player;
    return StreamBuilder<PlayerState>(
      stream: player?.playerStateStream,
      builder: (context, snap) {
        final playing = (snap.data?.playing ?? false) && snap.data?.processingState != ProcessingState.completed;
        return IconButton(
          tooltip: playing ? 'Pause recording' : 'Play recording',
          onPressed: _toggle,
          icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: c.ember),
        );
      },
    );
  }
}
