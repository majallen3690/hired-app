import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// One place for every haptic, so each kind of touch always feels the same.
class Haptics {
  const Haptics._();

  /// Committing an action: a button, a card.
  static void tap() => _fire(HapticFeedback.lightImpact);

  /// Moving a selection: a tab, a segment, a chip.
  static void select() => _fire(HapticFeedback.selectionClick);

  /// A score has landed.
  static void success() => _fire(HapticFeedback.mediumImpact);

  static void _fire(Future<void> Function() f) {
    // A device with no vibrator, or a test with no platform, must never turn a tap into an error.
    unawaited(f().catchError((_) {}));
  }
}

/// Gives whatever it wraps instant press feedback: it shrinks on touch-down, not on release, and springs back.
/// It only listens, so the child still handles its own tap. Sliding the finger away releases it, so scrolling a
/// list never leaves a card stuck pressed.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.enabled = true, this.scale = 0.97});

  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: HiredMotion.press,
    reverseDuration: HiredMotion.release,
  );
  Offset? _start;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // A pointer can outlive the widget it landed on (a dragged card is rebuilt under the finger), so every handler
  // checks it is still mounted before touching the controller.
  void _down(PointerDownEvent e) {
    if (!mounted || !widget.enabled) return;
    _start = e.position;
    _c.forward();
  }

  void _move(PointerMoveEvent e) {
    if (!mounted) return;
    final s = _start;
    if (s != null && (e.position - s).distance > kTouchSlop) {
      _start = null;
      _c.reverse();
    }
  }

  void _up(PointerEvent e) {
    if (!mounted) return;
    _start = null;
    _c.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Listener(
      // Translucent: a card with gaps in it still answers a touch in the gaps, and nothing underneath is blocked.
      behavior: HitTestBehavior.translucent,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (_, child) {
          final t = HiredMotion.easeOut.transform(_c.value);
          // Reduced motion keeps the feedback but drops the movement.
          if (reduce) return Opacity(opacity: 1 - 0.28 * t, child: child);
          return Transform.scale(scale: 1 - (1 - widget.scale) * t, child: child);
        },
      ),
    );
  }
}

/// Fades and lifts its child in once, when it first appears. [index] staggers a column of them; anything past
/// [maxStaggered] simply appears so a long list never makes the user wait.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.index = 0, this.rise = 14});

  final Widget child;
  final int index;
  final double rise;

  static const maxStaggered = 8;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  AnimationController? _c;
  late Animation<double> _v = const AlwaysStoppedAnimation(1);
  var _reduce = false;
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduce = MediaQuery.disableAnimationsOf(context);
    if (widget.index >= Reveal.maxStaggered) return;
    final delay = HiredMotion.stagger.inMilliseconds * widget.index;
    final total = (_reduce ? 160 : HiredMotion.reveal.inMilliseconds) + delay;
    final c = AnimationController(vsync: this, duration: Duration(milliseconds: total));
    _c = c;
    // Once it has landed, the fade wrapper steps out of the tree so a settled screen carries no extra layers.
    c.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() {});
    });
    _v = CurvedAnimation(parent: c, curve: Interval(delay / total, 1, curve: HiredMotion.easeOut));
    c.forward();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null || c.isCompleted) return widget.child;
    return FadeTransition(
      opacity: _v,
      child: AnimatedBuilder(
        animation: _v,
        child: widget.child,
        builder: (_, child) =>
            Transform.translate(offset: Offset(0, _reduce ? 0 : widget.rise * (1 - _v.value)), child: child),
      ),
    );
  }
}

extension RevealChildren on List<Widget> {
  /// Wraps each real child in a [Reveal], counting only widgets that take up space (not bare spacers).
  List<Widget> revealed({int from = 0}) {
    var i = from;
    return [
      for (final w in this)
        if (w is SizedBox && w.child == null) w else Reveal(index: i++, child: w),
    ];
  }
}

/// A ListView whose children rise in one after another the first time the screen opens.
class RevealListView extends StatelessWidget {
  const RevealListView({
    super.key,
    required this.children,
    this.padding,
    this.controller,
    this.physics,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  @override
  Widget build(BuildContext context) => ListView(
        padding: padding,
        controller: controller,
        physics: physics,
        keyboardDismissBehavior: keyboardDismissBehavior,
        children: children.revealed(),
      );
}

/// A spinner that stays out of sight for a beat. Local reads finish in a few milliseconds, and a spinner that
/// flashes for two frames reads as a glitch; a real wait still gets one.
class DelayedSpinner extends StatefulWidget {
  const DelayedSpinner({super.key, this.delay = const Duration(milliseconds: 280), this.size = 26});

  final Duration delay;
  final double size;

  @override
  State<DelayedSpinner> createState() => _DelayedSpinnerState();
}

class _DelayedSpinnerState extends State<DelayedSpinner> {
  var _show = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(widget.delay, () {
      if (mounted) setState(() => _show = true);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _show ? 1 : 0,
      duration: HiredMotion.quick,
      curve: HiredMotion.easeOut,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: _show ? CircularProgressIndicator(strokeWidth: 2.2, color: context.hc.ember) : null,
      ),
    );
  }
}

/// Rubber-band scrolling everywhere, with no glow: content resists at the edge instead of stopping dead.
class HiredScrollBehavior extends MaterialScrollBehavior {
  const HiredScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
}

/// Sheets rise with the same long-settle curve as the tab thumb and leave a little faster than they arrive.
final hiredSheetMotion = AnimationStyle(
  duration: const Duration(milliseconds: 380),
  curve: HiredMotion.drawer,
  reverseDuration: const Duration(milliseconds: 260),
  reverseCurve: Curves.easeInCubic,
);

/// A progress bar that fills from empty to its value the first time it shows, and glides when the value changes.
class AnimatedBar extends StatelessWidget {
  const AnimatedBar({
    super.key,
    required this.value,
    required this.color,
    required this.backgroundColor,
    this.minHeight = 4,
  });

  final double value;
  final Color color;
  final Color backgroundColor;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: reduce ? Duration.zero : const Duration(milliseconds: 800),
      curve: HiredMotion.easeOutExpo,
      builder: (_, v, __) =>
          LinearProgressIndicator(value: v, minHeight: minHeight, backgroundColor: backgroundColor, color: color),
    );
  }
}

/// Swaps between whole-screen states (connecting, live, wrapping up) with a short fade and settle instead of a
/// cut. It keeps the tight constraints a screen expects, which a plain AnimatedSwitcher would loosen.
class PhaseSwitcher extends StatelessWidget {
  const PhaseSwitcher({super.key, required this.phase, required this.child});

  /// Changes whenever the screen moves to a different state.
  final Object phase;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reduce ? Duration.zero : const Duration(milliseconds: 320),
      switchInCurve: HiredMotion.easeOut,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 0.985, end: 1.0).animate(a), child: child),
      ),
      child: KeyedSubtree(key: ValueKey(phase), child: child),
    );
  }
}
