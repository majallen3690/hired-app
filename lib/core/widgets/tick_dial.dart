import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 60 ticks in four arcs of 14, clockwise from 12. The quarter ticks stay empty so the arcs read apart.
/// [values] are 0-100 in order Resume, Interview, Speaking, Presence. Only [focus] takes a band colour.
class TickDial extends StatelessWidget {
  const TickDial({
    super.key,
    required this.values,
    this.focus,
    this.size = 248,
    this.stroke = 16,
    this.tick = 3.4,
    this.child,
  });

  final List<double> values;
  final int? focus;
  final double size;
  final double stroke;
  final double tick;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _DialPainter(
                values: values,
                focus: focus,
                stroke: stroke,
                tick: tick,
                palette: context.hc,
              ),
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.values,
    required this.focus,
    required this.stroke,
    required this.tick,
    required this.palette,
  });

  final List<double> values;
  final int? focus;
  final double stroke;
  final double tick;
  final HiredPalette palette;

  static const _perArc = 14;
  static const _step = 2 * math.pi / 60;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - stroke / 2;
    final inner = r - stroke / 2;
    final outer = r + stroke / 2;

    final track = Paint()
      ..color = palette.track
      ..strokeWidth = tick
      ..strokeCap = StrokeCap.butt;

    for (var arc = 0; arc < 4; arc++) {
      final lit = (_perArc * values[arc].clamp(0, 100) / 100).round();
      final isFocus = focus == arc;
      final litColor = isFocus ? palette.band(values[arc].round()) : palette.text;
      final litPaint = Paint()
        ..color = litColor
        ..strokeWidth = tick
        ..strokeCap = StrokeCap.butt;

      if (isFocus && lit > 0) {
        final glow = Paint()
          ..color = litColor.withValues(alpha: 0.35)
          ..strokeWidth = tick * 2.4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
        for (var j = 0; j < lit; j++) {
          _tick(canvas, c, inner, outer, arc, j, glow);
        }
      }
      for (var j = 0; j < _perArc; j++) {
        _tick(canvas, c, inner, outer, arc, j, j < lit ? litPaint : track);
      }
    }
  }

  void _tick(Canvas canvas, Offset c, double inner, double outer, int arc, int j, Paint paint) {
    final a = -math.pi / 2 + (arc * 15 + 1 + j) * _step;
    final dir = Offset(math.cos(a), math.sin(a));
    canvas.drawLine(c + dir * inner, c + dir * outer, paint);
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.values != values || old.focus != focus || old.palette != palette;
}
