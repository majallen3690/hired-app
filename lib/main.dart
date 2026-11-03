import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/app_epoch.dart';
import 'core/boot.dart';
import 'core/motion/motion.dart';
import 'core/notifications/reminder_service.dart';
import 'core/router.dart';
import 'core/storage/app_dir.dart';
import 'core/storage/app_prefs.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'dev/demo_forge.dart';
import 'features/interview/interview_prefill.dart';
import 'features/tracker/data/application_store.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fonts ship inside the app, so a missing network can never delay or change the first paint.
  GoogleFonts.config.allowRuntimeFetching = false;
  // A few bytes of settings: which data folder to open and which theme to draw the first frame in.
  await AppPrefs.load();
  AppDir.demo = AppPrefs.demoOn;
  // Neither of these is needed to draw the first screen, so the app opens now and they finish behind it.
  // Gemini calls await `firebaseReady`; reminders await their own init.
  firebaseReady = Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform).then((_) {});
  unawaited(ReminderService.instance.init());
  if (forgeDemo) unawaited(runDemoForge());
  runApp(const AppRoot());
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: appEpoch,
        builder: (_, epoch, __) => ProviderScope(key: ValueKey(epoch), child: const HiredApp()),
      );
}

class HiredApp extends ConsumerStatefulWidget {
  const HiredApp({super.key});

  @override
  ConsumerState<HiredApp> createState() => _HiredAppState();
}

class _HiredAppState extends ConsumerState<HiredApp> {
  @override
  void initState() {
    super.initState();
    ReminderService.instance.onTap = _open;
    // A tap that launched the app from closed is handled once the plugin has finished starting, which is no
    // longer on the path to the first frame.
    ReminderService.instance.init().then((_) {
      final payload = ReminderService.instance.takeLaunchPayload();
      if (payload != null && mounted) _open(payload);
    });
  }

  /// `app:<id>` opens the application; `warmup:<id>` opens a mock interview for it.
  Future<void> _open(String payload) async {
    final at = payload.indexOf(':');
    if (at < 0) return;
    final kind = payload.substring(0, at);
    final id = payload.substring(at + 1);
    final apps = await ref.read(applicationsProvider.future);
    final app = apps.where((a) => a.id == id).firstOrNull;
    if (app == null) {
      router.go('/tracker');
      return;
    }
    if (kind == 'warmup') {
      ref.read(interviewPrefillProvider.notifier).set(role: app.role, company: app.company);
      router.go('/interview');
    } else {
      router.go('/tracker');
      router.push('/tracker/$id');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(reminderSyncProvider);
    return MaterialApp.router(
      title: 'Hired',
      debugShowCheckedModeBanner: false,
      theme: buildHiredTheme(Brightness.light),
      darkTheme: buildHiredTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      scrollBehavior: const HiredScrollBehavior(),
      routerConfig: router,
    );
  }
}
