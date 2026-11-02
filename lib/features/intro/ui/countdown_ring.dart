import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../domain/intro_analysis.dart';

/// One tick per second around the dial; the ticks go dark as the minute runs out.
class CountdownRing extends StatelessWidget {
  const CountdownRing({super.key, required this.secondsLeft, required this.child, this.size = 260});

  final int secondsLeft;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Semantics(
      label: '$secondsLeft seconds left',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(secondsLeft: secondsLeft, lit: c.ember, dark: c.track),
            ),
            ExcludeSemantics(child: child),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.secondsLeft, required this.lit, required this.dark});

  final int secondsLeft;
  final Color lit;
  final Color dark;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final outer = size.width / 2 - 4;
    const tickLength = 14.0;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.4;
    for (var i = 0; i < introSeconds; i++) {
      final angle = -math.pi / 2 + i * 2 * math.pi / introSeconds;
      paint.color = i < secondsLeft ? lit : dark;
      final from = centre + Offset(math.cos(angle), math.sin(angle)) * (outer - tickLength);
      final to = centre + Offset(math.cos(angle), math.sin(angle)) * outer;
      canvas.drawLine(from, to, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.secondsLeft != secondsLeft || old.lit != lit || old.dark != dark;
}

String countdownClock(int secondsLeft) => '${secondsLeft ~/ 60}:${(secondsLeft % 60).toString().padLeft(2, '0')}';

/// The big number in the middle of the dial.
class DialReadout extends StatelessWidget {
  const DialReadout({super.key, required this.secondsLeft, this.caption = 'of 60 seconds', this.below});
  final int secondsLeft;
  final String caption;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(countdownClock(secondsLeft), style: HiredText.num(72).copyWith(color: c.text)),
        Text(caption, style: HiredText.small.copyWith(color: c.text3)),
        if (below != null) ...[const SizedBox(height: HiredSpace.sm), below!],
      ],
    );
  }
}
