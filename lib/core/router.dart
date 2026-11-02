import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/interview/ui/coach_replay_screen.dart';
import '../features/intro/ui/intro_recorder_screen.dart';
import '../features/intro/ui/intro_result_screen.dart';
import '../features/presence/ui/presence_camera_screen.dart';
import '../features/presence/ui/presence_result_screen.dart';
import '../features/progress/ui/progress_screen.dart';
import '../features/tracker/ui/add_application_screen.dart';
import '../features/tracker/ui/application_detail_screen.dart';
import '../features/tracker/ui/tracker_screen.dart';
import '../features/interview/ui/interview_live_screen.dart';
import '../features/interview/ui/interview_report_screen.dart';
import '../features/interview/ui/interview_setup_screen.dart';
import '../features/resume/ui/analysing_screen.dart';
import '../features/resume/ui/result_screen.dart';
import '../features/resume/ui/resume_input_screen.dart';
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
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
                            Icon(
                              icon,
                              size: 22,
                              color: location == path ? c.ember : c.text3,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              label,
                              style: HiredText.small.copyWith(
                                fontSize: 10.5,
                                fontWeight: location == path
                                    ? FontWeight.w600
                                    : FontWeight.w500,
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
      ),
    );
  }
}

final router = GoRouter(
  initialLocation: '/home',
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          _Shell(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/resume', builder: (_, __) => const ResumeInputScreen()),
        GoRoute(
          path: '/resume/analysing',
          builder: (_, __) => const AnalysingScreen(),
        ),
        GoRoute(
          path: '/resume/result',
          builder: (_, __) => const ResultScreen(),
        ),
        GoRoute(
          path: '/interview',
          builder: (_, __) => const InterviewSetupScreen(),
        ),
        GoRoute(path: '/tracker', builder: (_, __) => const TrackerScreen()),
        GoRoute(
          path: '/progress',
          builder: (_, __) => const ProgressScreen(),
        ),
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
