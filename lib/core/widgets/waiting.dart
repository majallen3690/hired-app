import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Short, true things worth reading while the AI works. None of them is a promise about the user's own result.
const placementTips = [
  'Put a number on every bullet: users, time saved, percent improved.',
  'Answer in four beats: the situation, your task, what you did, what changed.',
  'A pause is better than "um". Take a breath before you start answering.',
  'Match your resume to one job at a time. Recruiters skim for the same words as the posting.',
  'Aim for about 140 words a minute when you speak: slow enough to follow.',
  'Say what you personally did. "We" hides your part.',
  'Practise out loud. Reading an answer silently feels easier than it is.',
  'Look at the camera lens, not at your own face on the screen.',
];

/// A ring of ticks that breathes while something is being worked out. It replaces a bare spinner on the waiting
/// screens, and stays still when the device asks for reduced motion.
class BreathingDial extends StatefulWidget {
  const BreathingDial({super.key, this.size = 96, this.icon});
  final double size;
  final IconData? icon;

  @override
  State<BreathingDial> createState() => _BreathingDialState();
}

class _BreathingDialState extends State<BreathingDial> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 0.5;
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          painter: _DialPainter(t: _c.value, lit: c.ember, dim: c.track),
          child: widget.icon == null ? null : Center(child: Icon(widget.icon, color: c.text2, size: widget.size * 0.28)),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.t, required this.lit, required this.dim});
  final double t;
  final Color lit, dim;

  @override
  void paint(Canvas canvas, Size size) {
    const ticks = 36;
    final centre = size.center(Offset.zero);
    final outer = size.width / 2;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.6;
    for (var i = 0; i < ticks; i++) {
      final a = i / ticks;
      // A bright wave travels round the ring; ticks fade back to dim behind it.
      var d = (t - a) % 1.0;
      if (d < 0) d += 1;
      final glow = math.pow(1 - d, 4).toDouble();
      paint.color = Color.lerp(dim, lit, glow)!;
      final angle = a * 2 * math.pi - math.pi / 2;
      final len = 6 + 5 * glow;
      final p1 = centre + Offset(math.cos(angle), math.sin(angle)) * (outer - len);
      final p2 = centre + Offset(math.cos(angle), math.sin(angle)) * outer;
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) => old.t != t || old.lit != lit || old.dim != dim;
}

/// One tip at a time, changing every few seconds with a soft cross-fade.
class TipRotator extends StatefulWidget {
  const TipRotator({super.key, this.tips = placementTips, this.every = const Duration(seconds: 4)});
  final List<String> tips;
  final Duration every;

  @override
  State<TipRotator> createState() => _TipRotatorState();
}

class _TipRotatorState extends State<TipRotator> {
  late int _i = DateTime.now().second % widget.tips.length;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.every, (_) {
      if (mounted) setState(() => _i = (_i + 1) % widget.tips.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('WHILE YOU WAIT', style: HiredText.label.copyWith(color: c.text3, fontSize: 11, letterSpacing: 1.6)),
        const SizedBox(height: HiredSpace.sm),
        SizedBox(
          height: 64,
          child: AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 420),
            switchInCurve: HiredMotion.easeOut,
            child: Text(
              widget.tips[_i],
              key: ValueKey(_i),
              textAlign: TextAlign.center,
              style: HiredText.body.copyWith(color: c.text2),
            ),
          ),
        ),
      ],
    );
  }
}

/// A full waiting screen body: the breathing dial, what is happening, and a tip.
class WaitingBody extends StatelessWidget {
  const WaitingBody({super.key, required this.title, this.detail, this.icon});
  final String title;
  final String? detail;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HiredSpace.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BreathingDial(icon: icon),
            const SizedBox(height: HiredSpace.xxl),
            Text(title, textAlign: TextAlign.center, style: HiredText.h2.copyWith(color: c.text)),
            if (detail != null) ...[
              const SizedBox(height: HiredSpace.xs),
              Text(detail!, textAlign: TextAlign.center, style: HiredText.small.copyWith(color: c.text3)),
            ],
            const SizedBox(height: HiredSpace.xxl),
            const TipRotator(),
          ],
        ),
      ),
    );
  }
}
