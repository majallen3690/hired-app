import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/tick_dial.dart';
import '../auth/auth_service.dart';

/// Three short slides: the promise, how the score is made, and what the app will ask for and why.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingState();
}

class _OnboardingState extends State<OnboardingScreen> {
  final _page = PageController();
  var _index = 0;
  static const _count = 3;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await session.finishOnboarding();
    if (mounted) context.go('/sign-in');
  }

  void _next() {
    if (_index == _count - 1) {
      _finish();
    } else {
      _page.nextPage(duration: const Duration(milliseconds: 420), curve: HiredMotion.drawer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final last = _index == _count - 1;
    return Scaffold(
      backgroundColor: c.ink,
      body: Aurora(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: AnimatedOpacity(
                  duration: HiredMotion.quick,
                  opacity: last ? 0 : 1,
                  child: TextAction(label: 'Skip', onPressed: last ? null : _finish),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _page,
                  onPageChanged: (i) {
                    Haptics.select();
                    setState(() => _index = i);
                  },
                  children: const [_Promise(), _Weights(), _Privacy()],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _count; i++)
                    AnimatedContainer(
                      duration: HiredMotion.quick,
                      curve: HiredMotion.easeOut,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _index ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _index ? c.ember : c.track,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(HiredSpace.screen, HiredSpace.xl, HiredSpace.screen, HiredSpace.xl),
                child: PrimaryButton(
                  label: last ? 'Get started' : 'Next',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: _next,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.art, required this.title, required this.body});
  final Widget art;
  final Widget title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HiredSpace.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Center(child: art)),
          title,
          const SizedBox(height: HiredSpace.md),
          Text(body, style: HiredText.body.copyWith(color: c.text2)),
          const SizedBox(height: HiredSpace.lg),
        ],
      ),
    );
  }
}

class _Promise extends StatelessWidget {
  const _Promise();

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return _Slide(
      art: Stack(
        alignment: Alignment.center,
        children: [
          TickDial(
            size: 250,
            values: const [74, 58, 66, 44],
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('62', style: HiredText.num(76).copyWith(color: c.text)),
              Text('readiness', style: HiredText.italic.copyWith(color: c.text3)),
            ]),
          ),
          Positioned(top: -6, right: -14, child: const Tag('Example', tone: TagTone.signal)),
        ],
      ),
      title: Text.rich(TextSpan(style: HiredText.h1.copyWith(color: c.text), children: [
        const TextSpan(text: 'One number for\n'),
        TextSpan(text: 'how ready', style: HiredText.h1Em),
        const TextSpan(text: ' you are.'),
      ])),
      body: 'Hired turns your resume, interviews and presence into a score, then shows you the fastest way to raise it.',
    );
  }
}

class _Weights extends StatelessWidget {
  const _Weights();

  static const _rows = [
    (Icons.description_rounded, 'Resume', 'Match to real job descriptions', 0.30),
    (Icons.mic_rounded, 'Interview', 'Answers in live AI mocks', 0.35),
    (Icons.record_voice_over_rounded, 'Speaking', 'Pace, fillers and clarity', 0.20),
    (Icons.photo_camera_rounded, 'Presence', 'Framing, eye line and posture', 0.15),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return _Slide(
      art: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (icon, name, line, w) in _rows)
            Padding(
              padding: const EdgeInsets.only(bottom: HiredSpace.md),
              child: Glass(
                padding: const EdgeInsets.symmetric(horizontal: HiredSpace.lg, vertical: 14),
                child: Column(children: [
                  Row(children: [
                    Icon(icon, color: c.ember, size: 22),
                    const SizedBox(width: HiredSpace.md),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: HiredText.body.copyWith(color: c.text, fontWeight: FontWeight.w600)),
                        Text(line, style: HiredText.tiny.copyWith(color: c.text3)),
                      ]),
                    ),
                    Text('${(w * 100).round()}%', style: HiredText.body.copyWith(color: c.text, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 10),
                  AnimatedBar(value: w / 0.35, color: c.ember, backgroundColor: c.track),
                ]),
              ),
            ),
        ],
      ),
      title: Text.rich(TextSpan(style: HiredText.h1.copyWith(color: c.text), children: [
        const TextSpan(text: 'Four things\n'),
        TextSpan(text: 'recruiters', style: HiredText.h1Em),
        const TextSpan(text: ' notice.'),
      ])),
      body: 'Each one updates the moment you practise. Your score always uses your latest attempt, and every number comes with the evidence behind it.',
    );
  }
}

class _Privacy extends StatelessWidget {
  const _Privacy();

  static const _rows = [
    (Icons.mic_rounded, 'Microphone', 'For mock interviews and your spoken intro. Asked the first time you record.'),
    (Icons.photo_camera_rounded, 'Camera', 'Only for the optional presence check. You can skip it.'),
    (Icons.notifications_rounded, 'Notifications', 'Follow-ups and interview reminders. Asked when you first set one.'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return _Slide(
      art: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (icon, name, line) in _rows)
            Padding(
              padding: const EdgeInsets.only(bottom: HiredSpace.md),
              child: Glass(
                padding: const EdgeInsets.all(HiredSpace.lg),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: c.ember.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(HiredRadii.tile)),
                    child: Icon(icon, color: c.ember, size: 20),
                  ),
                  const SizedBox(width: HiredSpace.md),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: HiredText.body.copyWith(color: c.text, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(line, style: HiredText.small.copyWith(color: c.text2)),
                    ]),
                  ),
                ]),
              ),
            ),
        ],
      ),
      title: Text.rich(TextSpan(style: HiredText.h1.copyWith(color: c.text), children: [
        const TextSpan(text: 'Your data stays\n'),
        TextSpan(text: 'on your phone.', style: HiredText.h1Em),
      ])),
      body: 'Nothing is uploaded except what you send for scoring. We ask for each permission only when you first need it.',
    );
  }
}
