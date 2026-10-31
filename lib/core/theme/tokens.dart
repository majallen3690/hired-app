import 'package:flutter/material.dart';

/// Ember tokens, mirrored from docs/design/hired.css (dark is the hero theme).
class HiredColors {
  const HiredColors._();

  static const ink = Color(0xFF0C0C0D);
  static const ink2 = Color(0xFF151517);
  static const ink3 = Color(0xFF1E1E21);
  static const text = Color(0xFFF3F2EF);
  static final text2 = text.withValues(alpha: 0.70);
  static final text3 = text.withValues(alpha: 0.55);
  static const ember = Color(0xFFFF8A4C);
  static const onEmber = Color(0xFF1A0D06);
  static const signal = Color(0xFF6ED8C3);
  static const ok = Color(0xFF6FD39A);
  static const warn = Color(0xFFF2C14E);
  static const bad = Color(0xFFFF6B5E);
  static final hair = Colors.white.withValues(alpha: 0.09);
  static final track = Colors.white.withValues(alpha: 0.10);
  static final edge = Colors.white.withValues(alpha: 0.20);
  static final glassTop = Colors.white.withValues(alpha: 0.11);
  static final glassBottom = Colors.white.withValues(alpha: 0.035);

  static Color band(int v) => v >= 75 ? ok : (v >= 50 ? warn : bad);
}

/// Shape lock: cards 18, tiles 14, buttons and inputs 12, chips 10, tags 6.
class HiredRadii {
  const HiredRadii._();

  static const card = 18.0;
  static const tile = 14.0;
  static const button = 12.0;
  static const chip = 10.0;
  static const tag = 6.0;
}

class HiredMotion {
  const HiredMotion._();

  static const scoreReveal = Duration(milliseconds: 1300);
  static const scoreJump = Duration(milliseconds: 900);
  static const cardRise = Duration(milliseconds: 700);
  static const easeOutQuart = Cubic(0.25, 1, 0.5, 1);
  static const easeOutExpo = Cubic(0.16, 1, 0.3, 1);
}
