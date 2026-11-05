import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hired/core/storage/app_prefs.dart';
import 'package:hired/core/theme/app_theme.dart';
import 'package:hired/features/settings/settings_screen.dart';

var _now = DateTime(2026);

/// The screen has grown past the default test viewport, so give it a phone-sized one.
Future<void> tallPhone(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Widget app() => ProviderScope(
      child: MaterialApp.router(
        theme: buildHiredTheme(Brightness.dark),
        routerConfig: GoRouter(routes: [GoRoute(path: '/', builder: (_, __) => SettingsScreen(clock: () => _now))]),
      ),
    );

void main() {
  setUp(() {
    AppPrefs.demoUnlocked = false;
    AppPrefs.demoOn = false;
  });

  testWidgets('seven quick taps on the version number unlock the demo section', (tester) async {
    await tallPhone(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Demo mode'), findsNothing);

    for (var i = 0; i < demoUnlockTaps - 1; i++) {
      await tester.tap(find.text('Version 1.0.0'));
      _now = _now.add(const Duration(milliseconds: 200));
    }
    expect(find.text('Demo mode'), findsNothing);

    await tester.tap(find.text('Version 1.0.0'));
    await tester.pumpAndSettle();
    expect(find.text('Demo mode'), findsOneWidget);
    expect(AppPrefs.demoUnlocked, isTrue);
  });

  testWidgets('slow taps never unlock it', (tester) async {
    await tallPhone(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    for (var i = 0; i < demoUnlockTaps + 2; i++) {
      await tester.tap(find.text('Version 1.0.0'));
      _now = _now.add(const Duration(seconds: 2));
    }
    await tester.pumpAndSettle();
    expect(find.text('Demo mode'), findsNothing);
    expect(AppPrefs.demoUnlocked, isFalse);
  });

  testWidgets('appearance can be switched and own data can be deleted from here', (tester) async {
    await tallPhone(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Delete my data'), findsOneWidget);
  });
}
