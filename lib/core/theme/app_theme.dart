import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Colourless text styles; apply colour with `.copyWith(color: context.hc.text2)` so they work in light and dark.
class HiredText {
  const HiredText._();

  static TextStyle _base(double size, FontWeight w, {double? height, double spacing = 0, FontStyle? style}) =>
      GoogleFonts.hankenGrotesk(
        fontSize: size,
        fontWeight: w,
        height: height == null ? null : height / size,
        letterSpacing: spacing * size,
        fontStyle: style,
      );

  /// Light headline; italicise the one phrase that matters with [h1Em].
  static final h1 = _base(27, FontWeight.w300, height: 32, spacing: -0.03);
  static final h1Em = _base(27, FontWeight.w400, height: 32, spacing: -0.02, style: FontStyle.italic);
  static final h2 = _base(17, FontWeight.w600, height: 23, spacing: -0.015);
  static final lead = _base(18, FontWeight.w400, height: 23, spacing: -0.015);
  static final body = _base(15, FontWeight.w400, height: 22);
  static final small = _base(13, FontWeight.w400, height: 18);
  static final tiny = _base(12, FontWeight.w400, height: 16);
  static final italic = _base(14, FontWeight.w400, height: 20, style: FontStyle.italic);
  static final button = _base(16, FontWeight.w600, spacing: -0.01);

  static TextStyle num(double size) => _base(size, FontWeight.w300, height: size, spacing: -0.045).copyWith(
        fontFeatures: const [FontFeature.tabularFigures(), FontFeature.liningFigures()],
      );

  /// Micro label, uppercase. Mono face is JetBrains Mono (Geist Mono is not in google_fonts).
  static final label = GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.w500, letterSpacing: 1.05);
}

ThemeData buildHiredTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? HiredPalette.dark : HiredPalette.light;
  final scheme = ColorScheme.fromSeed(seedColor: p.ember, brightness: brightness).copyWith(
    primary: p.ember,
    onPrimary: p.onEmber,
    surface: p.ink,
    onSurface: p.text,
    error: p.bad,
  );
  final base = ThemeData(brightness: brightness).textTheme;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.ink,
    extensions: [p],
    textTheme: GoogleFonts.hankenGroteskTextTheme(base).apply(bodyColor: p.text, displayColor: p.text),
    splashFactory: InkRipple.splashFactory,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.ember,
        foregroundColor: p.onEmber,
        minimumSize: const Size.fromHeight(52),
        textStyle: HiredText.button,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HiredRadii.button)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.text,
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: p.text.withValues(alpha: 0.16)),
        textStyle: HiredText.button,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HiredRadii.button)),
      ),
    ),
  );
}
