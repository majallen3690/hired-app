import 'package:flutter/material.dart';

/// Ember tokens, mirrored from docs/design/hired.css (`:root` = dark, `.light` = light).
/// Read them with `context.hc`; nothing outside lib/core/theme should hardcode a colour.
@immutable
class HiredPalette extends ThemeExtension<HiredPalette> {
  const HiredPalette({
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.text,
    required this.text2,
    required this.text3,
    required this.ember,
    required this.onEmber,
    required this.signal,
    required this.ok,
    required this.warn,
    required this.bad,
    required this.hair,
    required this.track,
    required this.edge,
    required this.glassTop,
    required this.glassBottom,
    required this.selected,
  });

  final Color ink, ink2, ink3;
  final Color text, text2, text3;
  final Color ember, onEmber, signal, ok, warn, bad;
  final Color hair, track, edge, glassTop, glassBottom, selected;

  static final dark = HiredPalette(
    ink: const Color(0xFF0C0C0D),
    ink2: const Color(0xFF151517),
    ink3: const Color(0xFF1E1E21),
    text: const Color(0xFFF3F2EF),
    text2: const Color(0xFFF3F2EF).withValues(alpha: 0.70),
    text3: const Color(0xFFF3F2EF).withValues(alpha: 0.55),
    ember: const Color(0xFFFF8A4C),
    onEmber: const Color(0xFF1A0D06),
    signal: const Color(0xFF6ED8C3),
    ok: const Color(0xFF6FD39A),
    warn: const Color(0xFFF2C14E),
    bad: const Color(0xFFFF6B5E),
    hair: Colors.white.withValues(alpha: 0.09),
    track: Colors.white.withValues(alpha: 0.10),
    edge: Colors.white.withValues(alpha: 0.20),
    glassTop: Colors.white.withValues(alpha: 0.11),
    glassBottom: Colors.white.withValues(alpha: 0.035),
    selected: Colors.white.withValues(alpha: 0.12),
  );

  static final light = HiredPalette(
    ink: const Color(0xFFF2F1EF),
    ink2: const Color(0xFFFFFFFF),
    ink3: const Color(0xFFE7E5E2),
    text: const Color(0xFF161514),
    text2: const Color(0xFF161514).withValues(alpha: 0.74),
    text3: const Color(0xFF161514).withValues(alpha: 0.62),
    ember: const Color(0xFFF07A3C),
    onEmber: const Color(0xFF1A0D06),
    signal: const Color(0xFF0E8C78),
    ok: const Color(0xFF1E8A4C),
    warn: const Color(0xFF9A6A00),
    bad: const Color(0xFFCF3A2E),
    hair: const Color(0xFF161514).withValues(alpha: 0.08),
    track: const Color(0xFF161514).withValues(alpha: 0.10),
    edge: Colors.white,
    glassTop: Colors.white.withValues(alpha: 0.82),
    glassBottom: Colors.white.withValues(alpha: 0.50),
    selected: Colors.white,
  );

  Color band(int v) => v >= 75 ? ok : (v >= 50 ? warn : bad);

  @override
  HiredPalette copyWith() => this;

  @override
  HiredPalette lerp(ThemeExtension<HiredPalette>? other, double t) {
    if (other is! HiredPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return HiredPalette(
      ink: l(ink, other.ink),
      ink2: l(ink2, other.ink2),
      ink3: l(ink3, other.ink3),
      text: l(text, other.text),
      text2: l(text2, other.text2),
      text3: l(text3, other.text3),
      ember: l(ember, other.ember),
      onEmber: l(onEmber, other.onEmber),
      signal: l(signal, other.signal),
      ok: l(ok, other.ok),
      warn: l(warn, other.warn),
      bad: l(bad, other.bad),
      hair: l(hair, other.hair),
      track: l(track, other.track),
      edge: l(edge, other.edge),
      glassTop: l(glassTop, other.glassTop),
      glassBottom: l(glassBottom, other.glassBottom),
      selected: l(selected, other.selected),
    );
  }
}

extension HiredContext on BuildContext {
  HiredPalette get hc => Theme.of(this).extension<HiredPalette>() ?? HiredPalette.dark;
}

/// Shape lock: cards 18, tiles 14, buttons and inputs 12, chips 10, tags 6.
class HiredRadii {
  const HiredRadii._();

  static const card = 18.0;
  static const tile = 14.0;
  static const button = 12.0;
  static const chip = 10.0;
  static const tag = 6.0;
  static const tabBar = 22.0;
}

class HiredSpace {
  const HiredSpace._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
  static const screen = 20.0;
}

class HiredMotion {
  const HiredMotion._();

  static const scoreReveal = Duration(milliseconds: 1300);
  static const scoreJump = Duration(milliseconds: 900);
  static const cardRise = Duration(milliseconds: 700);
  static const press = Duration(milliseconds: 90);
  static const release = Duration(milliseconds: 260);
  static const quick = Duration(milliseconds: 180);
  static const tab = Duration(milliseconds: 320);
  static const reveal = Duration(milliseconds: 460);
  static const stagger = Duration(milliseconds: 50);
  static const easeOutQuart = Cubic(0.25, 1, 0.5, 1);
  static const easeOutExpo = Cubic(0.16, 1, 0.3, 1);

  /// Strong ease-out for anything entering or responding; the built-in curves are too weak.
  static const easeOut = Cubic(0.23, 1, 0.32, 1);

  /// iOS sheet curve: fast start, long settle. For things that travel across the screen.
  static const drawer = Cubic(0.32, 0.72, 0, 1);
}
