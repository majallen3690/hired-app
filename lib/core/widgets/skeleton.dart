import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A soft light that sweeps across everything inside it, so placeholder shapes read as "loading" rather than as an
/// empty screen. With reduced motion it stays still.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});
  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
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
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) {
          final x = -1.0 + 3.0 * _c.value;
          return LinearGradient(
            begin: Alignment(x - 0.6, -0.3),
            end: Alignment(x + 0.6, 0.3),
            colors: [Colors.transparent, c.text.withValues(alpha: 0.10), Colors.transparent],
          ).createShader(rect);
        },
        child: child,
      ),
    );
  }
}

/// One placeholder block. Wrap a group of them in [Shimmer].
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = HiredRadii.tag + 2});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: context.hc.track, borderRadius: BorderRadius.circular(radius)),
      );
}

/// Placeholder rows shaped like a list of cards: an avatar tile, two lines of text, and a tag.
class SkeletonCards extends StatelessWidget {
  const SkeletonCards({super.key, this.count = 4});
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Shimmer(
      child: Column(
        children: [
          for (var i = 0; i < count; i++)
            Container(
              margin: const EdgeInsets.only(bottom: HiredSpace.md),
              padding: const EdgeInsets.all(HiredSpace.lg),
              decoration: BoxDecoration(
                color: c.glassBottom,
                borderRadius: BorderRadius.circular(HiredRadii.card),
                border: Border.all(color: c.hair),
              ),
              child: Row(
                children: [
                  const SkeletonBox(width: 44, height: 44, radius: HiredRadii.tile),
                  const SizedBox(width: HiredSpace.md),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 140, height: 16),
                        SizedBox(height: 8),
                        SkeletonBox(height: 12),
                      ],
                    ),
                  ),
                  const SizedBox(width: HiredSpace.md),
                  const SkeletonBox(width: 56, height: 22, radius: HiredRadii.tag),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
