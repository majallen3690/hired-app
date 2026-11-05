import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/glass.dart';
import '../data/presence_store.dart';
import '../domain/presence_models.dart';
import '../domain/presence_record.dart';
import '../domain/presence_scoring.dart';
import '../presence_controller.dart';
import '../../../core/motion/motion.dart';
import '../../../core/widgets/skeleton.dart';

const _partIcons = {
  PresencePart.attire: Icons.checkroom_rounded,
  PresencePart.grooming: Icons.face_rounded,
  PresencePart.lighting: Icons.light_mode_rounded,
  PresencePart.expression: Icons.sentiment_satisfied_rounded,
};

const _fixIcons = {
  FixArea.lighting: Icons.wb_sunny_rounded,
  FixArea.background: Icons.wallpaper_rounded,
  FixArea.attire: Icons.checkroom_rounded,
  FixArea.grooming: Icons.face_rounded,
  FixArea.expression: Icons.sentiment_satisfied_rounded,
  FixArea.framing: Icons.center_focus_strong_rounded,
};

class PresenceResultScreen extends ConsumerStatefulWidget {
  const PresenceResultScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<PresenceResultScreen> createState() => _State();
}

class _State extends ConsumerState<PresenceResultScreen> {
  var _retrying = false;
  String? _retryError;
  var _saving = false;

  Future<void> _retry() async {
    setState(() {
      _retrying = true;
      _retryError = null;
    });
    final err = await ref
        .read(presenceControllerProvider.notifier)
        .retry(widget.id);
    if (mounted) {
      setState(() {
        _retrying = false;
        _retryError = err;
      });
    }
  }

  /// A check that was never saved is thrown away, photo included, when the user leaves or retakes.
  Future<void> _leave(PresenceRecord r, String route) async {
    if (!r.saved) {
      await ref.read(presenceControllerProvider.notifier).delete(r.id);
    }
    if (!mounted) return;
    // Retaking swaps this screen for the camera on top of the tabs; anything else returns to a tab.
    route == '/presence' ? context.pushReplacement(route) : context.go(route);
  }

  Future<void> _confirmDelete(PresenceRecord r) async {
    final c = context.hc;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.ink2,
        title: Text(
          'Delete this photo?',
          style: HiredText.h2.copyWith(color: c.text),
        ),
        content: Text(
          'The photo and its score are removed from this phone.',
          style: HiredText.body.copyWith(color: c.text2),
        ),
        actions: [
          TextAction(
            label: 'Keep it',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          TextAction(
            label: 'Delete',
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(presenceControllerProvider.notifier).delete(r.id);
      if (mounted) context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    // The controller disposes itself when nothing listens; this screen calls it after awaits (save, retry, delete),
    // so it must stay alive for as long as the screen is open.
    ref.watch(presenceControllerProvider);
    final async = ref.watch(presenceRecordProvider(widget.id));
    return Scaffold(
      backgroundColor: c.ink,
      body: Aurora(
        child: SafeArea(
          child: async.when(
            loading: () => const Padding(padding: EdgeInsets.all(HiredSpace.screen), child: SkeletonCards(count: 3)),
            error: (e, _) => Center(
              child: Text(
                'Could not open this check.',
                style: HiredText.body.copyWith(color: c.text2),
              ),
            ),
            data: (r) => r == null
                ? Center(
                    child: Text(
                      'This check was not found.',
                      style: HiredText.body.copyWith(color: c.text2),
                    ),
                  )
                : _body(c, r),
          ),
        ),
      ),
    );
  }

  Widget _body(HiredPalette c, PresenceRecord r) {
    final result = r.result;
    return Column(
      children: [
        Expanded(
          child: RevealListView(
            padding: const EdgeInsets.fromLTRB(
              HiredSpace.screen,
              HiredSpace.sm,
              HiredSpace.screen,
              HiredSpace.xl,
            ),
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: c.text2),
                    tooltip: 'Back',
                    onPressed: () => _leave(r, '/presence'),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        r.occasion.title,
                        style: HiredText.body.copyWith(
                          color: c.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: HiredSpace.md),
              _hero(c, r, result),
              if (result != null) ...[
                const SizedBox(height: HiredSpace.lg),
                _breakdown(c, result),
                const SizedBox(height: HiredSpace.xl),
                Text(
                  'Three quick fixes',
                  style: HiredText.h2.copyWith(color: c.text),
                ),
                const SizedBox(height: HiredSpace.md),
                for (final f in result.fixes) _fix(c, f),
                const SizedBox(height: HiredSpace.sm),
                Text(
                  'Scored on things you can change in a minute. It never rates your face or looks.',
                  style: HiredText.tiny.copyWith(color: c.text3),
                ),
              ] else ...[
                const SizedBox(height: HiredSpace.lg),
                Glass(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your photo is saved, but it could not be read yet.',
                        style: HiredText.h2.copyWith(color: c.text),
                      ),
                      const SizedBox(height: HiredSpace.sm),
                      Text(
                        _retryError ??
                            r.failed ??
                            'The analysis did not finish.',
                        style: HiredText.body.copyWith(color: c.text2),
                      ),
                      const SizedBox(height: HiredSpace.lg),
                      PrimaryButton(
                        label: _retrying ? 'Reading…' : 'Try again',
                        onPressed: _retrying ? null : _retry,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        _dock(c, r),
      ],
    );
  }

  Widget _hero(HiredPalette c, PresenceRecord r, PresenceResult? result) {
    final score = result?.score;
    // 160 for the photo plus the glass frame around it; a fixed height because this sits in a scrolling list.
    return SizedBox(
      height: 168,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FutureBuilder<String>(
            future: ref.read(presenceStoreProvider).photoPath(r),
            builder: (context, snap) => Glass(
              padding: const EdgeInsets.all(4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(HiredRadii.tile),
                child: SizedBox(
                  width: 124,
                  height: 160,
                  child: snap.hasData
                      ? Image.file(
                          File(snap.data!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              ColoredBox(color: c.track),
                        )
                      : ColoredBox(color: c.track),
                ),
              ),
            ),
          ),
          const SizedBox(width: HiredSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SectionLabel('Presence'),
                if (score != null) ...[
                  TweenAnimationBuilder<double>(
                    onEnd: Haptics.success,
                    tween: Tween(begin: 0, end: score.toDouble()),
                    duration: MediaQuery.of(context).disableAnimations
                        ? Duration.zero
                        : HiredMotion.scoreReveal,
                    curve: HiredMotion.easeOutQuart,
                    builder: (_, v, __) => Text(
                      '${v.round()}',
                      style: HiredText.num(
                        88,
                      ).copyWith(color: c.band(score), height: 1),
                    ),
                  ),
                  const SizedBox(height: HiredSpace.xs),
                  Tag(
                    verdict(r.occasion, score),
                    tone: score >= 75
                        ? TagTone.ok
                        : (score >= 50 ? TagTone.warn : TagTone.bad),
                  ),
                ] else
                  Text(
                    '–',
                    style: HiredText.num(
                      88,
                    ).copyWith(color: c.text3, height: 1),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _breakdown(HiredPalette c, PresenceResult result) => Glass(
    padding: const EdgeInsets.all(HiredSpace.lg + 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Breakdown', style: HiredText.h2.copyWith(color: c.text)),
        const SizedBox(height: HiredSpace.lg),
        for (final p in result.parts) ...[
          Row(
            children: [
              Icon(_partIcons[p.part], size: 20, color: c.text2),
              const SizedBox(width: HiredSpace.sm),
              Expanded(
                child: Text(
                  p.part.label,
                  style: HiredText.body.copyWith(
                    color: c.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${p.value}',
                style: HiredText.num(22).copyWith(color: c.band(p.value)),
              ),
            ],
          ),
          const SizedBox(height: HiredSpace.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: AnimatedBar(
              value: p.value / 100,
              minHeight: 4,
              backgroundColor: c.track,
              color: c.band(p.value),
            ),
          ),
          if (p.observed != null && p.observed!.isNotEmpty) ...[
            const SizedBox(height: HiredSpace.sm),
            Text(
              'Seen: ${p.observed}',
              style: HiredText.small.copyWith(color: c.text2),
            ),
          ],
          if (p.measured != null) ...[
            const SizedBox(height: 2),
            Text(p.measured!, style: HiredText.small.copyWith(color: c.text3)),
          ],
          const SizedBox(height: HiredSpace.lg),
        ],
        Text(
          '"Seen" is the AI\'s reading of your photo. "Measured" comes from your phone.',
          style: HiredText.tiny.copyWith(color: c.text3),
        ),
      ],
    ),
  );

  Widget _fix(HiredPalette c, Fix f) => Padding(
    padding: const EdgeInsets.only(bottom: HiredSpace.sm),
    child: Glass(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.track,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_fixIcons[f.area], color: c.text, size: 22),
          ),
          const SizedBox(width: HiredSpace.md),
          Expanded(
            child: Text(f.text, style: HiredText.small.copyWith(color: c.text)),
          ),
        ],
      ),
    ),
  );

  Widget _dock(HiredPalette c, PresenceRecord r) => Container(
    padding: const EdgeInsets.fromLTRB(
      HiredSpace.screen,
      HiredSpace.md,
      HiredSpace.screen,
      HiredSpace.lg,
    ),
    decoration: BoxDecoration(
      color: c.ink.withValues(alpha: 0.92),
      border: Border(top: BorderSide(color: c.hair)),
    ),
    child: Row(
      children: [
        Expanded(
          flex: 2,
          child: OutlineAction(
            label: 'Retake',
            icon: Icons.photo_camera_rounded,
            onPressed: () => _leave(r, '/presence'),
          ),
        ),
        const SizedBox(width: HiredSpace.sm),
        Expanded(
          flex: 3,
          child: r.saved
              ? OutlineAction(
                  label: 'Delete photo',
                  icon: Icons.delete_outline_rounded,
                  onPressed: () => _confirmDelete(r),
                )
              : PrimaryButton(
                  label: _saving ? 'Saving…' : 'Save to my score',
                  icon: Icons.check_rounded,
                  onPressed: r.score == null || _saving
                      ? null
                      : () async {
                          setState(() => _saving = true);
                          await ref
                              .read(presenceControllerProvider.notifier)
                              .save(r.id);
                          if (mounted) context.go('/home');
                        },
                ),
        ),
      ],
    ),
  );
}
