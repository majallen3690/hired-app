import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/interview/ui/coach_replay_screen.dart';
import '../features/intro/ui/intro_recorder_screen.dart';
import '../features/intro/ui/intro_result_screen.dart';
import '../features/presence/ui/presence_camera_screen.dart';
import '../features/presence/ui/presence_result_screen.dart';
import '../features/progress/ui/progress_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/tracker/ui/add_application_screen.dart';
import '../features/tracker/ui/application_detail_screen.dart';
import '../features/tracker/ui/tracker_screen.dart';
import '../features/interview/ui/interview_live_screen.dart';
import '../features/interview/ui/interview_report_screen.dart';
import '../features/interview/ui/interview_setup_screen.dart';
import '../features/resume/ui/analysing_screen.dart';
import '../features/resume/ui/result_screen.dart';
import '../features/resume/ui/resume_input_screen.dart';
import 'motion/motion.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';
import 'widgets/glass.dart';

const _tabs = [
  ('/home', 'Home', Icons.home_rounded),
  ('/resume', 'Resume', Icons.description_rounded),
  ('/interview', 'Interview', Icons.mic_rounded),
  ('/tracker', 'Tracker', Icons.work_rounded),
  ('/progress', 'Progress', Icons.insights_rounded),
];

/// The tab bar and the persistent background. Each tab keeps its own screen, scroll position and half-typed
/// input alive while you visit another, and switching between them is instant.
class _Shell extends StatelessWidget {
  const _Shell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Aurora(child: _TabFade(index: shell.currentIndex, child: shell)),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: _TabBar(
            index: shell.currentIndex,
            // Tapping the tab you are already on returns it to its first screen.
            onSelect: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          ),
        ),
      ),
    );
  }
}

/// The incoming tab eases up into place. The old one is already gone, so this reads as one quick settle rather
/// than a cross-fade that would hold two full screens in memory at once.
class _TabFade extends StatefulWidget {
  const _TabFade({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<_TabFade> createState() => _TabFadeState();
}

class _TabFadeState extends State<_TabFade> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 240), value: 1);
  late final Animation<double> _v = CurvedAnimation(parent: _c, curve: HiredMotion.easeOut);

  @override
  void didUpdateWidget(_TabFade old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index && !MediaQuery.disableAnimationsOf(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _v,
      child: AnimatedBuilder(
        animation: _v,
        child: widget.child,
        builder: (_, child) => Transform.translate(offset: Offset(0, 10 * (1 - _v.value)), child: child),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.onSelect});
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Glass(
      frosted: true,
      radius: HiredRadii.tabBar,
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        height: 56,
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth / _tabs.length;
            return Stack(
              children: [
                // One thumb that glides to the chosen tab, retargeting from wherever it is if you tap again.
                TweenAnimationBuilder<double>(
                  tween: Tween(end: index.toDouble()),
                  duration: HiredMotion.tab,
                  curve: HiredMotion.drawer,
                  builder: (_, v, __) => Transform.translate(
                    offset: Offset(v * w, 0),
                    child: SizedBox(
                      width: w,
                      height: 56,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: c.selected, borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < _tabs.length; i++)
                      Expanded(
                        child: _TabItem(
                          label: _tabs[i].$2,
                          icon: _tabs[i].$3,
                          selected: i == index,
                          onTap: () {
                            if (i != index) Haptics.select();
                            onSelect(i);
                          },
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.label, required this.icon, required this.selected, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: PressScale(
        scale: 0.92,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            height: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: selected ? c.ember : c.text3),
                  duration: HiredMotion.quick,
                  curve: HiredMotion.easeOut,
                  builder: (_, color, __) => AnimatedScale(
                    scale: selected ? 1.08 : 1,
                    duration: HiredMotion.quick,
                    curve: HiredMotion.easeOut,
                    child: Icon(icon, size: 22, color: color),
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: HiredMotion.quick,
                  curve: HiredMotion.easeOut,
                  style: HiredText.small.copyWith(
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? c.text : c.text3,
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final router = GoRouter(
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _Shell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, __) => const HomeScreen())]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/resume',
            builder: (_, __) => const ResumeInputScreen(),
            routes: [
              GoRoute(path: 'analysing', builder: (_, __) => const AnalysingScreen()),
              GoRoute(path: 'result', builder: (_, __) => const ResultScreen()),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [GoRoute(path: '/interview', builder: (_, __) => const InterviewSetupScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/tracker', builder: (_, __) => const TrackerScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/progress', builder: (_, __) => const ProgressScreen())]),
      ],
    ),
    // Full-screen: no tab bar over a live interview, its report or the replay.
    GoRoute(path: '/interview/live', builder: (_, __) => const InterviewLiveScreen()),
    GoRoute(
      path: '/tracker/add',
      builder: (_, state) => AddApplicationScreen(manual: state.uri.queryParameters['manual'] == '1'),
    ),
    GoRoute(
      path: '/tracker/:id',
      builder: (_, state) => ApplicationDetailScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    GoRoute(path: '/presence', builder: (_, __) => const PresenceCameraScreen()),
    GoRoute(
      path: '/presence/result/:id',
      builder: (_, state) => PresenceResultScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(path: '/intro', builder: (_, __) => const IntroRecorderScreen()),
    GoRoute(
      path: '/intro/result/:id',
      builder: (_, state) => IntroResultScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/interview/report/:id',
      builder: (_, state) => InterviewReportScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/interview/replay/:id',
      builder: (_, state) => CoachReplayScreen(id: state.pathParameters['id']!),
    ),
  ],
);
