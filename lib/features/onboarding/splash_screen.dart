import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_info.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/tick_dial.dart';

/// The first moment of the app: the wordmark settles in, then the router decides where to go next (slides, sign-in
/// or Home). It never waits on the network.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.hold = const Duration(milliseconds: 1700)});
  final Duration hold;

  @override
  State<SplashScreen> createState() => _SplashState();
}

class _SplashState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _timer = Timer(widget.hold, () {
      if (mounted) context.go('/home');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final t = reduce ? const AlwaysStoppedAnimation<double>(1) : CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return Scaffold(
      backgroundColor: c.ink,
      body: Aurora(
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 5),
              FadeTransition(
                opacity: t,
                child: ScaleTransition(
                  scale: Tween(begin: 0.92, end: 1.0).animate(t),
                  child: Column(
                    children: [
                      TickDial(
                        size: 116,
                        stroke: 9,
                        tick: 2.2,
                        values: const [78, 64, 70, 52],
                      ),
                      const SizedBox(height: HiredSpace.xl),
                      Text.rich(TextSpan(style: HiredText.h1.copyWith(color: c.text, fontSize: 40), children: [
                        const TextSpan(text: 'hired'),
                        TextSpan(text: '.', style: TextStyle(color: c.ember)),
                      ])),
                      const SizedBox(height: HiredSpace.sm),
                      Text('Your placement coach, in your pocket.', style: HiredText.body.copyWith(color: c.text2)),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: HiredSpace.xl),
                child: Text('Version $appVersion', style: HiredText.tiny.copyWith(color: c.text3)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
