import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';

/// The interviewer. Cool and large while it speaks, warm and small while it listens to you.
class Orb extends StatefulWidget {
  const Orb({super.key, required this.interviewerSpeaking, required this.level, this.busy = false, this.size = 230});

  final bool interviewerSpeaking;

  /// Microphone level 0 to 1; makes the orb react to your voice.
  final double level;

  /// Connecting or wrapping up: a slow steady breath.
  final bool busy;

  /// Outer diameter; shrinks while the keyboard is open.
  final double size;

  @override
  State<Orb> createState() => _OrbState();
}

class _OrbState extends State<Orb> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 3));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
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
    final speaking = widget.interviewerSpeaking || widget.busy;
    final tone = speaking ? c.signal : c.ember;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final breath = Curves.easeInOut.transform(_c.value);
        final react = speaking ? 0.04 * breath : widget.level * 0.14;
        final scale = (speaking ? 1.0 : 0.86) + react;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [tone.withValues(alpha: 0.30), tone.withValues(alpha: 0)]),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: HiredMotion.easeOutQuart,
                width: widget.size * 0.65 * scale,
                height: widget.size * 0.65 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.35, -0.4),
                    colors: [tone.withValues(alpha: 0.95), tone.withValues(alpha: 0.45), tone.withValues(alpha: 0.12)],
                    stops: const [0, 0.65, 1],
                  ),
                  boxShadow: [BoxShadow(color: tone.withValues(alpha: 0.35), blurRadius: 40, spreadRadius: 2)],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Recent microphone levels as quiet bars.
class LevelWave extends StatelessWidget {
  const LevelWave({super.key, required this.levels, required this.color});
  final List<double> levels;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 36,
        child: CustomPaint(painter: _WavePainter(levels, color), size: const Size.fromHeight(36)),
      );
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.levels, this.color);
  final List<double> levels;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const bars = 32;
    final gap = size.width / bars;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    for (var i = 0; i < bars; i++) {
      final src = levels.length - bars + i;
      final v = src >= 0 && src < levels.length ? levels[src] : 0.0;
      final h = 4 + v * (size.height - 4);
      paint.color = color.withValues(alpha: 0.25 + 0.65 * v);
      final x = gap * i + gap / 2;
      canvas.drawLine(Offset(x, size.height / 2 - h / 2), Offset(x, size.height / 2 + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.levels.length != levels.length || old.color != color;
}

/// A small labelled number, like the live metric tiles in the design.
class MetricTile extends StatelessWidget {
  const MetricTile({super.key, required this.label, required this.value, this.unit, this.note, this.onTap});
  final String label;
  final String value;
  final String? unit;
  final String? note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(HiredRadii.tile),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: HiredText.label.copyWith(color: c.text3)),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: HiredText.num(30).copyWith(color: c.text)),
                if (unit != null) ...[
                  const SizedBox(width: 3),
                  Text(unit!, style: HiredText.tiny.copyWith(color: c.text3)),
                ],
              ],
            ),
            if (note != null) Text(note!, style: HiredText.tiny.copyWith(color: c.text3)),
          ],
        ),
      ),
    );
  }
}

String clock(int ms) {
  final s = ms ~/ 1000;
  return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Words per minute described in plain language, for the report and live tile.
String paceNote(double? wpm) {
  if (wpm == null) return 'Not enough speech yet';
  if (wpm > 160) return 'a bit fast';
  if (wpm < 120) return 'a bit slow';
  return 'good pace';
}

double sineBreath(double t) => 0.5 + 0.5 * math.sin(t * math.pi * 2);
