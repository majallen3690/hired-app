import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

class HiredText {
  const HiredText._();

  static TextStyle _base(double size, FontWeight w, {double? height, double spacing = 0, Color? color, FontStyle? style}) =>
      GoogleFonts.hankenGrotesk(
        fontSize: size,
        fontWeight: w,
        height: height == null ? null : height / size,
        letterSpacing: spacing * size,
        color: color ?? HiredColors.text,
        fontStyle: style,
      );

  /// Light headline; italic the one phrase that matters with [h1Em].
  static final h1 = _base(27, FontWeight.w300, height: 32, spacing: -0.03);
  static final h1Em = _base(27, FontWeight.w400, height: 32, spacing: -0.02, style: FontStyle.italic);
  static final h2 = _base(17, FontWeight.w600, height: 23, spacing: -0.015);
  static final body = _base(15, FontWeight.w400, height: 22, color: HiredColors.text2);
  static final small = _base(13, FontWeight.w400, height: 18, color: HiredColors.text2);
  static final italic = _base(14, FontWeight.w400, height: 20, color: HiredColors.text3, style: FontStyle.italic);
  static final button = _base(16, FontWeight.w600, spacing: -0.01, color: HiredColors.onEmber);
  static TextStyle num(double size, {Color? color}) =>
      _base(size, FontWeight.w300, height: size, spacing: -0.045, color: color).copyWith(
        fontFeatures: const [FontFeature.tabularFigures(), FontFeature.liningFigures()],
      );

  /// Micro label, uppercase, mono.
  static final label = GoogleFonts.jetBrainsMono(
    fontSize: 10.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.05,
    color: HiredColors.text3,
  );
}

ThemeData buildHiredTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: HiredColors.ember,
    brightness: Brightness.dark,
  ).copyWith(
    primary: HiredColors.ember,
    onPrimary: HiredColors.onEmber,
    surface: HiredColors.ink,
    onSurface: HiredColors.text,
    error: HiredColors.bad,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: HiredColors.ink,
    textTheme: GoogleFonts.hankenGroteskTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: HiredColors.text,
      displayColor: HiredColors.text,
    ),
    splashFactory: InkRipple.splashFactory,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: HiredColors.ember,
        foregroundColor: HiredColors.onEmber,
        minimumSize: const Size.fromHeight(52),
        textStyle: HiredText.button,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HiredRadii.button)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: HiredColors.text,
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
        textStyle: HiredText.button.copyWith(color: HiredColors.text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HiredRadii.button)),
      ),
    ),
  );
}
