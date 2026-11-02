import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/glass.dart';
import '../data/session_store.dart';
import '../domain/evaluation_models.dart';
import '../domain/interview_models.dart';
import '../domain/speech_metrics.dart';
import 'interview_widgets.dart';

Color _markerColor(HiredPalette c, MarkerKind k) => switch (k) {
      MarkerKind.question => c.signal,
      MarkerKind.filler => c.ember,
      MarkerKind.pause => c.warn,
    };

class CoachReplayScreen extends ConsumerStatefulWidget {
  const CoachReplayScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<CoachReplayScreen> createState() => _State();
}

class _State extends ConsumerState<CoachReplayScreen> {
  final _player = AudioPlayer();
  final _scroll = ScrollController();
  SessionRecord? _record;
  List<Marker> _markers = const [];
  List<GlobalKey> _keys = const [];
  Marker? _selected;
  String? _loadError;
  int _active = -1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final store = ref.read(sessionStoreProvider);
      final r = await store.load(widget.id);
      if (r == null) throw StateError('This session was not found.');
      final path = await store.audioPath(r);
      if (path == null) throw StateError('This session has no recording.');
      await _player.setFilePath(path);
      if (!mounted) return;
      setState(() {
        _record = r;
        _markers = buildMarkers(r.turns, r.pauses);
        _keys = [for (final _ in r.turns) GlobalKey()];
      });
      _player.positionStream.listen(_followTranscript);
    } catch (e) {
      if (mounted) setState(() => _loadError = e is StateError ? e.message : 'Could not open the recording.');
    }
  }

  void _followTranscript(Duration pos) {
    final r = _record;
    if (r == null) return;
    var idx = -1;
    for (var i = 0; i < r.turns.length; i++) {
      if (r.turns[i].startMs <= pos.inMilliseconds) idx = i;
    }
    if (idx != _active) {
      setState(() => _active = idx);
      final ctx = idx >= 0 && idx < _keys.length ? _keys[idx].currentContext : null;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(ctx, alignment: 0.25, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
      }
    }
  }

  void _seekMs(int ms) => _player.seek(Duration(milliseconds: ms < 0 ? 0 : ms));

  void _pick(Marker m) {
    setState(() => _selected = m);
    // Start a moment early so the cause of the marker is heard.
    _seekMs(m.atMs - 1500);
    _player.play();
  }

  @override
  void dispose() {
    _player.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final r = _record;
    return Scaffold(
      backgroundColor: c.ink,
      body: Aurora(
        child: SafeArea(
          child: _loadError != null
              ? Padding(
                  padding: const EdgeInsets.all(HiredSpace.screen),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Replay unavailable', style: HiredText.h1.copyWith(color: c.text)),
                    const SizedBox(height: HiredSpace.sm),
                    Text(_loadError!, style: HiredText.body.copyWith(color: c.text2)),
                    const SizedBox(height: HiredSpace.xxl),
                    PrimaryButton(label: 'Back', onPressed: () => context.pop()),
                  ]),
                )
              : r == null
                  ? const Center(child: CircularProgressIndicator())
                  : _body(c, r),
        ),
      ),
    );
  }

  Widget _body(HiredPalette c, SessionRecord r) {
    final counts = {
      for (final k in MarkerKind.values) k: _markers.where((m) => m.kind == k).length,
    };
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, HiredSpace.screen, 0),
        child: Row(children: [
          IconButton(icon: Icon(Icons.arrow_back_rounded, color: c.text2), onPressed: () => context.pop()),
          Text('Coach Replay', style: HiredText.h2.copyWith(color: c.text)),
          const SizedBox(width: HiredSpace.md),
          Expanded(
            child: Text(r.config.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: HiredText.tiny.copyWith(color: c.text3)),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: HiredSpace.screen),
        child: Glass(
          child: Column(children: [
            StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (context, snap) {
                final pos = snap.data ?? Duration.zero;
                final total = (_player.duration?.inMilliseconds ?? r.durationMs).clamp(1, 1 << 30);
                return Column(children: [
                  _Timeline(
                    positionMs: pos.inMilliseconds,
                    totalMs: total > r.durationMs ? total : r.durationMs,
                    markers: _markers,
                    selected: _selected,
                    onSeek: _seekMs,
                    onPick: _pick,
                  ),
                  const SizedBox(height: HiredSpace.sm),
                  Row(children: [
                    Text(clock(pos.inMilliseconds), style: HiredText.label.copyWith(color: c.text2)),
                    const Spacer(),
                    Text(clock(total), style: HiredText.label.copyWith(color: c.text3)),
                  ]),
                ]);
              },
            ),
            const SizedBox(height: HiredSpace.sm),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                iconSize: 28,
                icon: Icon(Icons.replay_10_rounded, color: c.text2),
                onPressed: () => _seekMs(_player.position.inMilliseconds - 10000),
              ),
              StreamBuilder<PlayerState>(
                stream: _player.playerStateStream,
                builder: (context, snap) {
                  final playing = snap.data?.playing ?? false;
                  final done = snap.data?.processingState == ProcessingState.completed;
                  return IconButton.filled(
                    iconSize: 34,
                    style: IconButton.styleFrom(backgroundColor: c.ember, foregroundColor: c.onEmber),
                    icon: Icon(playing && !done ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    onPressed: () {
                      if (done) _player.seek(Duration.zero);
                      playing && !done ? _player.pause() : _player.play();
                    },
                  );
                },
              ),
              IconButton(
                iconSize: 28,
                icon: Icon(Icons.forward_10_rounded, color: c.text2),
                onPressed: () => _seekMs(_player.position.inMilliseconds + 10000),
              ),
            ]),
            Wrap(spacing: HiredSpace.md, children: [
              for (final k in MarkerKind.values)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: _markerColor(c, k), shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text('${switch (k) { MarkerKind.question => 'Questions', MarkerKind.filler => 'Fillers', MarkerKind.pause => 'Pauses' }} ${counts[k]}',
                      style: HiredText.tiny.copyWith(color: c.text3)),
                ]),
            ]),
          ]),
        ),
      ),
      if (_selected != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(HiredSpace.screen, HiredSpace.md, HiredSpace.screen, 0),
          child: _note(c, _selected!),
        ),
      const SizedBox(height: HiredSpace.md),
      Expanded(
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(HiredSpace.screen, 0, HiredSpace.screen, HiredSpace.xxl),
          children: [
            const SectionLabel('Transcript'),
            const SizedBox(height: HiredSpace.sm),
            for (var i = 0; i < r.turns.length; i++) _turn(c, i, r.turns[i]),
          ],
        ),
      ),
    ]);
  }

  Widget _note(HiredPalette c, Marker m) {
    final tone = _markerColor(c, m.kind);
    return Glass(
      padding: const EdgeInsets.all(HiredSpace.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Tag(m.label, tone: switch (m.kind) {
            MarkerKind.question => TagTone.signal,
            MarkerKind.filler => TagTone.ember,
            MarkerKind.pause => TagTone.warn,
          }),
          const SizedBox(width: HiredSpace.sm),
          Text(clock(m.atMs), style: HiredText.label.copyWith(color: tone)),
        ]),
        const SizedBox(height: HiredSpace.sm),
        Text(m.note, style: HiredText.body.copyWith(color: c.text)),
        if (m.evidence != null && m.kind != MarkerKind.question) ...[
          const SizedBox(height: HiredSpace.xs),
          Text(m.kind == MarkerKind.filler ? '“…${m.evidence}…”' : m.evidence!,
              style: HiredText.small.copyWith(color: c.text3, fontStyle: FontStyle.italic)),
        ],
      ]),
    );
  }

  Widget _turn(HiredPalette c, int i, TranscriptTurn t) {
    final isYou = t.speaker == Speaker.candidate;
    final active = i == _active;
    final hits = isYou && !t.typed ? findFillers(t.text) : const <FillerHit>[];
    final spans = <TextSpan>[];
    var at = 0;
    for (final h in hits) {
      if (h.start > at) spans.add(TextSpan(text: t.text.substring(at, h.start)));
      spans.add(TextSpan(
        text: t.text.substring(h.start, h.end),
        style: TextStyle(color: c.ember, fontWeight: FontWeight.w700, backgroundColor: c.ember.withValues(alpha: 0.14)),
      ));
      at = h.end;
    }
    if (at < t.text.length) spans.add(TextSpan(text: t.text.substring(at)));
    return Padding(
      key: i < _keys.length ? _keys[i] : null,
      padding: const EdgeInsets.only(bottom: HiredSpace.md),
      child: InkWell(
        onTap: () => _seekMs(t.startMs),
        borderRadius: BorderRadius.circular(HiredRadii.tile),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(HiredSpace.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HiredRadii.tile),
            color: active ? c.selected : Colors.transparent,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(isYou ? 'YOU' : 'INTERVIEWER', style: HiredText.label.copyWith(color: isYou ? c.ember : c.signal)),
              const SizedBox(width: HiredSpace.sm),
              Text(clock(t.startMs), style: HiredText.label.copyWith(color: c.text3)),
              if (t.typed) ...[const SizedBox(width: HiredSpace.sm), const Tag('typed', tone: TagTone.warn)],
            ]),
            const SizedBox(height: 4),
            Text.rich(TextSpan(style: HiredText.body.copyWith(color: active ? c.text : c.text2), children: spans)),
          ]),
        ),
      ),
    );
  }
}

/// The scrubbable bar. Tap a coloured marker to hear that moment and read its coach note.
class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.positionMs,
    required this.totalMs,
    required this.markers,
    required this.selected,
    required this.onSeek,
    required this.onPick,
  });

  final int positionMs;
  final int totalMs;
  final List<Marker> markers;
  final Marker? selected;
  final ValueChanged<int> onSeek;
  final ValueChanged<Marker> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      double x(int ms) => (ms / totalMs).clamp(0.0, 1.0) * w;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          Marker? best;
          var bestDist = 16.0;
          for (final m in markers) {
            final dist = (x(m.atMs) - d.localPosition.dx).abs();
            if (dist < bestDist) {
              best = m;
              bestDist = dist;
            }
          }
          if (best != null) {
            onPick(best);
          } else {
            onSeek((d.localPosition.dx / w * totalMs).round());
          }
        },
        onHorizontalDragUpdate: (d) => onSeek((d.localPosition.dx / w * totalMs).round()),
        child: SizedBox(
          height: 56,
          width: w,
          child: CustomPaint(
            painter: _TimelinePainter(
              c: c,
              positionX: x(positionMs),
              markers: [for (final m in markers) (x(m.atMs), m)],
              selected: selected,
            ),
          ),
        ),
      );
    });
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({required this.c, required this.positionX, required this.markers, required this.selected});
  final HiredPalette c;
  final double positionX;
  final List<(double, Marker)> markers;
  final Marker? selected;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    canvas.drawRRect(
      RRect.fromLTRBR(0, mid - 3, size.width, mid + 3, const Radius.circular(3)),
      Paint()..color = c.track,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(0, mid - 3, positionX, mid + 3, const Radius.circular(3)),
      Paint()..color = c.ember.withValues(alpha: 0.55),
    );
    for (final (x, m) in markers) {
      final color = _markerColor(c, m.kind);
      final isSel = identical(m, selected);
      final tall = m.kind == MarkerKind.question ? 16.0 : 10.0;
      canvas.drawLine(
        Offset(x, mid - tall),
        Offset(x, mid + tall),
        Paint()
          ..color = color
          ..strokeWidth = isSel ? 4 : 2.5
          ..strokeCap = StrokeCap.round,
      );
      if (isSel) canvas.drawCircle(Offset(x, mid), 7, Paint()..color = color.withValues(alpha: 0.25));
    }
    canvas.drawCircle(Offset(positionX, mid), 8, Paint()..color = c.text);
    canvas.drawCircle(Offset(positionX, mid), 4, Paint()..color = c.ember);
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.positionX != positionX || old.selected != selected || old.markers.length != markers.length;
}
