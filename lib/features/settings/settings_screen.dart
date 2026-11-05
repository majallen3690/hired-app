import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_epoch.dart';
import '../../core/config/app_info.dart';
import '../../core/motion/motion.dart';
import '../../core/storage/app_dir.dart';
import '../../core/storage/app_prefs.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/glass.dart';
import '../auth/auth_service.dart';
import '../demo/demo_mode.dart';
import '../resume/resume_flow.dart';

/// Taps on the version number needed to unlock the demo tools, and the longest gap allowed between two of them.
const demoUnlockTaps = 7;
const _tapWindow = Duration(milliseconds: 1500);

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.clock = DateTime.now});

  /// Tests supply their own clock; widget tests do not move `DateTime.now`.
  final DateTime Function() clock;

  @override
  ConsumerState<SettingsScreen> createState() => _State();
}

class _State extends ConsumerState<SettingsScreen> {
  var _taps = 0;
  DateTime? _lastTap;
  var _busy = false;

  void _tapVersion() {
    if (AppPrefs.demoUnlocked) return;
    final now = widget.clock();
    _taps = _lastTap != null && now.difference(_lastTap!) <= _tapWindow ? _taps + 1 : 1;
    _lastTap = now;
    Haptics.select();
    if (_taps >= demoUnlockTaps) {
      _taps = 0;
      AppPrefs.demoUnlocked = true;
      AppPrefs.save();
      Haptics.success();
      setState(() {});
      _say('Demo tools unlocked');
    } else if (_taps >= 3) {
      final left = demoUnlockTaps - _taps;
      _say('$left more ${left == 1 ? 'tap' : 'taps'} to unlock demo tools');
    }
  }

  void _say(String text) {
    final m = ScaffoldMessenger.of(context);
    m
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(milliseconds: 1400)));
  }

  /// Runs [work], then restarts the app's providers so every store reads the folder it now points at.
  Future<void> _switch(Future<void> Function() work, String failure) async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await work();
      restartApp(router);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(failure)));
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accountAction() async {
    final router = GoRouter.of(context);
    if (!AppPrefs.signedIn) {
      // A guest becomes a member by going back through sign-in.
      await session.leaveGuest();
      router.go('/sign-in');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Your resume, mocks and applications stay on this phone. You can sign back in any time.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    await session.signOut();
    router.go('/sign-in');
  }

  Future<void> _deleteData() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete my data?'),
        content: const Text(
          'This clears your resume, mock interviews, intros, applications and scores from this phone. '
          'It cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _switch(() async => AppDir.wipe(await AppDir.root()), 'Could not delete your data.');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final demo = AppDir.demo;
    final name = (AppPrefs.accountName ?? ref.watch(resumeFlowProvider).resume?['name'] as String?)?.trim();
    final theme = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: c.ink,
      body: Aurora(
        child: SafeArea(
          child: RevealListView(
            padding: const EdgeInsets.fromLTRB(HiredSpace.screen, HiredSpace.sm, HiredSpace.screen, HiredSpace.xxl),
            children: [
              Row(children: [
                IconAction(icon: Icons.arrow_back_rounded, label: 'Back', onPressed: () => context.pop()),
                const SizedBox(width: HiredSpace.xs),
                Text('Settings', style: HiredText.h1.copyWith(color: c.text)),
              ]),
              const SizedBox(height: HiredSpace.xl),
              Glass(
                padding: const EdgeInsets.symmetric(horizontal: HiredSpace.lg, vertical: 14),
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.ember, shape: BoxShape.circle),
                    child: Text(_initials(name), style: HiredText.label.copyWith(color: c.onEmber, fontSize: 16)),
                  ),
                  const SizedBox(width: HiredSpace.md),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name == null || name.isEmpty ? 'Your profile' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HiredText.h2.copyWith(color: c.text)),
                      Text(
                        AppPrefs.signedIn
                            ? AppPrefs.accountEmail!
                            : AppPrefs.guest
                                ? 'Guest · everything stays on this phone'
                                : (name == null || name.isEmpty ? 'Add your resume to fill this in' : 'Taken from your saved resume'),
                        style: HiredText.small.copyWith(color: c.text3),
                      ),
                    ]),
                  ),
                  if (demo) const Tag('Demo data', tone: TagTone.signal),
                ]),
              ),
              const SizedBox(height: HiredSpace.xl),
              const SectionLabel('Account'),
              const SizedBox(height: HiredSpace.sm),
              _Row(
                icon: Icons.flag_outlined,
                title: 'Edit your profile',
                subtitle: AppPrefs.targetRole.isEmpty ? 'Target role, branch, dream companies' : AppPrefs.targetRole,
                onTap: () => context.push('/profile-setup?edit=1'),
              ),
              const SizedBox(height: HiredSpace.sm),
              if (!demo)
                _Row(
                  icon: AppPrefs.signedIn ? Icons.logout_rounded : Icons.person_add_alt_1_rounded,
                  title: AppPrefs.signedIn ? 'Sign out' : 'Create an account',
                  subtitle: AppPrefs.signedIn ? 'Your data stays on this phone' : 'Sign in on this phone with an email',
                  onTap: _busy ? null : _accountAction,
                ),
              const SizedBox(height: HiredSpace.xl),
              const SectionLabel('Preferences'),
              const SizedBox(height: HiredSpace.sm),
              Glass(
                padding: const EdgeInsets.symmetric(horizontal: HiredSpace.lg, vertical: 10),
                child: Row(children: [
                  Icon(Icons.vibration_rounded, color: c.text2),
                  const SizedBox(width: HiredSpace.md),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Haptics', style: HiredText.body.copyWith(color: c.text, fontWeight: FontWeight.w500)),
                      Text('Gentle taps on buttons, tabs and scores', style: HiredText.small.copyWith(color: c.text3)),
                    ]),
                  ),
                  Switch(
                    value: Haptics.enabled,
                    activeTrackColor: c.ember,
                    activeThumbColor: c.onEmber,
                    onChanged: (v) {
                      Haptics.enabled = v;
                      AppPrefs.haptics = v;
                      AppPrefs.save();
                      if (v) Haptics.success();
                      setState(() {});
                    },
                  ),
                ]),
              ),
              const SizedBox(height: HiredSpace.xl),
              const SectionLabel('Appearance'),
              const SizedBox(height: HiredSpace.sm),
              Segmented<ThemeMode>(
                options: const {ThemeMode.dark: 'Dark', ThemeMode.light: 'Light', ThemeMode.system: 'System'},
                value: theme,
                onChanged: ref.read(themeModeProvider.notifier).set,
              ),
              if (!demo) ...[
                const SizedBox(height: HiredSpace.xl),
                const SectionLabel('Your data'),
                const SizedBox(height: HiredSpace.sm),
                Glass(
                  onTap: _busy ? null : _deleteData,
                  padding: const EdgeInsets.symmetric(horizontal: HiredSpace.lg, vertical: 16),
                  child: Row(children: [
                    Icon(Icons.delete_outline_rounded, color: c.bad),
                    const SizedBox(width: HiredSpace.md),
                    Expanded(child: Text('Delete my data', style: HiredText.body.copyWith(color: c.bad, fontWeight: FontWeight.w500))),
                  ]),
                ),
                const SizedBox(height: HiredSpace.xs),
                Text('Everything Hired saves stays on this phone. Nothing is uploaded except what you send for scoring.',
                    style: HiredText.tiny.copyWith(color: c.text3)),
              ],
              if (AppPrefs.demoUnlocked) ...[
                const SizedBox(height: HiredSpace.xl),
                const SectionLabel('Demo'),
                const SizedBox(height: HiredSpace.sm),
                Glass(
                  padding: const EdgeInsets.symmetric(horizontal: HiredSpace.lg, vertical: 14),
                  child: Column(children: [
                    Row(children: [
                      Icon(Icons.theater_comedy_rounded, color: c.text2),
                      const SizedBox(width: HiredSpace.md),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Demo mode', style: HiredText.body.copyWith(color: c.text, fontWeight: FontWeight.w500)),
                          Text(
                            _busy
                                ? 'Setting up the demo…'
                                : 'A sample student with three weeks of practice. Your own data is kept apart and comes back when this is off.',
                            style: HiredText.small.copyWith(color: c.text3),
                          ),
                        ]),
                      ),
                      Switch(
                        value: demo,
                        activeTrackColor: c.ember,
                        activeThumbColor: c.onEmber,
                        onChanged: _busy
                            ? null
                            : (on) => _switch(
                                  on ? DemoMode.turnOn : DemoMode.turnOff,
                                  on ? 'Could not set up the demo data.' : 'Could not switch back.',
                                ),
                      ),
                    ]),
                    if (demo) ...[
                      const SizedBox(height: HiredSpace.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextAction(
                          label: 'Reset demo data',
                          onPressed: _busy ? null : () => _switch(DemoMode.turnOn, 'Could not reset the demo data.'),
                        ),
                      ),
                    ],
                  ]),
                ),
              ],
              const SizedBox(height: HiredSpace.xl),
              _Row(
                icon: Icons.auto_awesome_rounded,
                title: 'Hired Pro',
                subtitle: 'A preview of what could come next',
                onTap: () => context.push('/pro'),
              ),
              const SizedBox(height: HiredSpace.xl),
              Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _tapVersion,
                  child: Padding(
                    padding: const EdgeInsets.all(HiredSpace.md),
                    child: Text('Version $appVersion', style: HiredText.label.copyWith(color: c.text3, fontSize: 12)),
                  ),
                ),
              ),
            ].revealed(),
          ),
        ),
      ),
    );
  }
}

String _initials(String? name) {
  final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'H';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}


/// A tappable settings row: icon, title, a line under it, and a chevron.
class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Glass(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: HiredSpace.lg, vertical: 14),
      child: Row(children: [
        Icon(icon, color: c.text2),
        const SizedBox(width: HiredSpace.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: HiredText.body.copyWith(color: c.text, fontWeight: FontWeight.w500)),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: HiredText.small.copyWith(color: c.text3)),
          ]),
        ),
        Icon(Icons.chevron_right_rounded, color: c.text3),
      ]),
    );
  }
}
