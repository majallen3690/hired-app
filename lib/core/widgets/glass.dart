import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../theme/tokens.dart';

/// 155° gradient 11% → 3.5% + 1px top highlight. Never nest glass in glass.
///
/// A card sits on a smooth, soft background, so blurring what is behind it changes nothing you can see, and a
/// live blur on every card is the most expensive thing a phone can be asked to draw. Cards are therefore plain
/// translucent fills. Set [frosted] only where something busy really passes underneath: the tab bar over
/// scrolling content, or a control over the camera preview.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(HiredSpace.lg),
    this.radius = HiredRadii.card,
    this.frosted = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool frosted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final r = BorderRadius.circular(radius);
    final tap = onTap;

    Widget body = Padding(padding: padding, child: child);
    if (tap != null) {
      body = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Haptics.tap();
          tap();
        },
        child: body,
      );
    }

    Widget card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: LinearGradient(
          begin: const Alignment(-0.9, -1),
          end: const Alignment(0.6, 1),
          colors: [c.glassTop, c.glassBottom],
          stops: const [0, 0.62],
        ),
        // Uniform colour: Flutter rejects a borderRadius with mixed-colour sides.
        border: Border.all(color: c.hair),
      ),
      child: Stack(
        children: [
          // Transparent Material so ink effects and inputs inside the card paint above its gradient.
          Material(type: MaterialType.transparency, child: body),
          // The 1px top highlight, like light catching the glass edge.
          Positioned(
            top: 0,
            left: radius,
            right: radius,
            height: 1,
            child: IgnorePointer(child: ColoredBox(color: c.edge)),
          ),
        ],
      ),
    );

    if (frosted) {
      card = ClipRRect(
        borderRadius: r,
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), child: card),
      );
    }
    return tap == null ? card : PressScale(child: card);
  }
}

/// One clock for every background, so a screen that slides in over another carries the same light and the
/// two never visibly disagree about where it is.
final _auroraClock = Stopwatch()..start();
const _auroraLoop = Duration(seconds: 18);

/// Quiet living background: one warm and one cool light drifting on an 18 s loop. Stills under reduce motion.
///
/// Each light is a soft radial gradient painted once into its own layer; the loop only moves that layer, so the
/// drift costs the compositor a transform per frame and never repaints the screen on top of it.
class Aurora extends StatefulWidget {
  const Aurora({super.key, required this.child});
  final Widget child;

  @override
  State<Aurora> createState() => _AuroraState();
}

class _AuroraState extends State<Aurora> {
  final _t = ValueNotifier<double>(0);
  Timer? _timer;

  /// The lights travel about two pixels a second, so ten updates a second is already finer than the eye can
  /// resolve. Driving them from a vsync ticker instead would redraw the whole screen sixty times a second while
  /// the user does nothing, which on a phone is most of the app's idle battery and heat.
  static const _step = Duration(milliseconds: 100);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Still under reduced motion, and quiet while another screen covers this one.
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce || !TickerMode.valuesOf(context).enabled) {
      _timer?.cancel();
      _timer = null;
      if (reduce) _t.value = 0.5;
    } else {
      _t.value = _phase();
      _timer ??= Timer.periodic(_step, (_) => _t.value = _phase());
    }
  }

  /// Triangle wave 0 → 1 → 0 over two loops, eased.
  double _phase() {
    final x = (_auroraClock.elapsedMicroseconds / _auroraLoop.inMicroseconds) % 2;
    return Curves.easeInOut.transform(x <= 1 ? x : 2 - x);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final light = Theme.of(context).brightness == Brightness.light;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: c.ink),
        RepaintBoundary(
          child: IgnorePointer(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _Light(
                  clock: _t,
                  left: -14,
                  top: 160,
                  size: 420,
                  drift: const Offset(22, -28),
                  color: c.ember,
                  opacity: light ? 0.22 : 0.34,
                ),
                _Light(
                  clock: _t,
                  left: -190,
                  top: 590,
                  size: 340,
                  drift: const Offset(14, 0),
                  color: c.signal,
                  opacity: light ? 0.10 : 0.12,
                ),
              ],
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _Light extends StatelessWidget {
  const _Light({
    required this.clock,
    required this.left,
    required this.top,
    required this.size,
    required this.drift,
    required this.color,
    required this.opacity,
  });

  final ValueListenable<double> clock;
  final double left;
  final double top;
  final double size;
  final Offset drift;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    // A smooth falloff in the gradient itself replaces the old 60px blur filter, which re-blurred every frame.
    final glow = RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: opacity),
                color.withValues(alpha: opacity * 0.55),
                color.withValues(alpha: opacity * 0.16),
                color.withValues(alpha: 0),
              ],
              stops: const [0, 0.32, 0.66, 1],
            ),
          ),
        ),
      ),
    );
    return Positioned(
      left: left,
      top: top,
      child: ValueListenableBuilder<double>(
        valueListenable: clock,
        child: glow,
        builder: (_, t, child) => Transform.translate(offset: drift * t, child: child),
      ),
    );
  }
}
