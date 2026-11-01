import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/resume/ui/analysing_screen.dart';
import '../features/resume/ui/result_screen.dart';
import '../features/resume/ui/resume_input_screen.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';
import 'widgets/glass.dart';

/// Honest placeholder for modules not built yet; replaced screen by screen from docs/design.
class _Pending extends StatelessWidget {
  const _Pending(this.title, this.design);
  final String title;
  final String design;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: HiredText.h1.copyWith(color: context.hc.text)),
              const SizedBox(height: 8),
              Text('Not built yet. Design: $design', style: HiredText.body.copyWith(color: context.hc.text2)),
            ],
          ),
        ),
      );
}

const _tabs = [
  ('/home', 'Home', Icons.home_rounded),
  ('/resume', 'Resume', Icons.description_rounded),
  ('/interview', 'Interview', Icons.mic_rounded),
  ('/tracker', 'Tracker', Icons.work_rounded),
  ('/progress', 'Progress', Icons.insights_rounded),
];

class _Shell extends StatelessWidget {
  const _Shell({required this.child, required this.location});
  final Widget child;
  final String location;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Scaffold(
      extendBody: true,
      body: Aurora(child: child),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
        child: Glass(
          radius: HiredRadii.tabBar,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: [
              for (final (path, label, icon) in _tabs)
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => context.go(path),
                    child: SizedBox(
                      height: 56,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, size: 22, color: location == path ? c.ember : c.text3),
                          const SizedBox(height: 3),
                          Text(
                            label,
                            style: HiredText.small.copyWith(
                              fontSize: 10.5,
                              fontWeight: location == path ? FontWeight.w600 : FontWeight.w500,
                              color: location == path ? c.text : c.text3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

final router = GoRouter(
  initialLocation: '/home',
  routes: [
    ShellRoute(
      builder: (context, state, child) => _Shell(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/resume', builder: (_, __) => const ResumeInputScreen()),
        GoRoute(path: '/resume/analysing', builder: (_, __) => const AnalysingScreen()),
        GoRoute(path: '/resume/result', builder: (_, __) => const ResultScreen()),
        GoRoute(path: '/interview', builder: (_, __) => const _Pending('Mock interview', 'A06 to A08')),
        GoRoute(path: '/tracker', builder: (_, __) => const _Pending('Applications', 'C05')),
        GoRoute(path: '/progress', builder: (_, __) => const _Pending('Progress', 'C07')),
        GoRoute(path: '/intro', builder: (_, __) => const _Pending('Self-intro', 'C01 and C02')),
        GoRoute(path: '/presence', builder: (_, __) => const _Pending('Presence check', 'C03 and C04')),
      ],
    ),
  ],
);
