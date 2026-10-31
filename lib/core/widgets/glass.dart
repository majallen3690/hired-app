import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// BackdropFilter blur 28 + 155° gradient 11% → 3.5% + 1px top highlight. Never nest glass in glass.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(HiredSpace.lg),
    this.radius = HiredRadii.card,
    this.blur = 28,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final r = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: r,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: r,
                gradient: LinearGradient(
                  begin: const Alignment(-0.9, -1),
                  end: const Alignment(0.6, 1),
                  colors: [c.glassTop, c.glassBottom],
                  stops: const [0, 0.62],
                ),
                border: Border(
                  top: BorderSide(color: c.edge),
                  left: BorderSide(color: c.hair),
                  right: BorderSide(color: c.hair),
                  bottom: BorderSide(color: c.hair),
                ),
              ),
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Quiet living background: one warm and one cool light drifting on an 18 s loop. Stills under reduce motion.
class Aurora extends StatefulWidget {
  const Aurora({super.key, required this.child});
  final Widget child;

  @override
  State<Aurora> createState() => _AuroraState();
}

class _AuroraState extends State<Aurora> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 18));

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
    final light = Theme.of(context).brightness == Brightness.light;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: c.ink),
        AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final t = Curves.easeInOut.transform(_c.value);
            return Stack(
              children: [
                _blob(left: 16 + 22 * t, top: 190 - 28 * t, size: 360, color: c.ember, opacity: light ? 0.22 : 0.34),
                _blob(left: -150 + 14 * t, top: 620, size: 260, color: c.signal, opacity: light ? 0.10 : 0.12),
              ],
            );
          },
        ),
        widget.child,
      ],
    );
  }

  Widget _blob({required double left, required double top, required double size, required Color color, required double opacity}) {
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)],
                stops: const [0, 0.7],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
