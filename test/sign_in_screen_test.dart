import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hired/core/storage/app_prefs.dart';
import 'package:hired/core/theme/app_theme.dart';
import 'package:hired/features/auth/auth_service.dart';
import 'package:hired/features/auth/sign_in_screen.dart';
import 'package:hired/features/onboarding/onboarding_screen.dart';

class _Gateway implements AuthGateway {
  _Gateway({this.fail});
  final String? fail;
  final calls = <String>[];

  @override
  Future<AuthUser> signIn(String email, String password) async {
    calls.add('in:$email');
    if (fail != null) throw AuthException(fail!);
    return AuthUser(uid: 'u', email: email.trim(), name: 'Ishita Rao');
  }

  @override
  Future<AuthUser> signUp(String email, String password, String name) async {
    calls.add('up:$email:$name');
    return AuthUser(uid: 'u', email: email.trim(), name: name);
  }

  @override
  Future<void> sendPasswordReset(String email) async => calls.add('reset:$email');
  @override
  Future<void> signOut() async {}
}

Widget host(Widget screen) => ProviderScope(
      child: MaterialApp.router(
        theme: buildHiredTheme(Brightness.dark),
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (_, __) => screen),
          GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('HOME'))),
          GoRoute(path: '/profile-setup', builder: (_, __) => const Scaffold(body: Text('PROFILE'))),
          GoRoute(path: '/sign-in', builder: (_, __) => const Scaffold(body: Text('SIGNIN'))),
        ]),
      ),
    );

void main() {
  setUp(() {
    AppPrefs.persist = false;
    AppPrefs.accountEmail = null;
    AppPrefs.accountName = null;
    AppPrefs.guest = false;
    AppPrefs.onboarded = false;
  });

  tearDown(() => AppPrefs.persist = true);

  testWidgets('empty fields are caught on the device and nothing is sent', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gw = _Gateway();
    await tester.pumpWidget(host(SignInScreen(gateway: gw)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in').last);
    await tester.pumpAndSettle();
    expect(find.text('Enter your email.'), findsOneWidget);
    expect(find.text('Enter a password.'), findsOneWidget);
    expect(gw.calls, isEmpty);
  });

  testWidgets('a refused sign-in shows the plain message and stays on the screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host(SignInScreen(gateway: _Gateway(fail: 'Email or password is not right.'))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'ishita@pes.edu');
    await tester.enterText(find.byType(TextField).at(1), 'secret1');
    await tester.tap(find.text('Sign in').last);
    await tester.pumpAndSettle();
    expect(find.text('Email or password is not right.'), findsOneWidget);
    expect(AppPrefs.signedIn, isFalse);
  });

  testWidgets('a good sign-in remembers the account and opens Home', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gw = _Gateway();
    await tester.pumpWidget(host(SignInScreen(gateway: gw)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'ishita@pes.edu');
    await tester.enterText(find.byType(TextField).at(1), 'secret1');
    await tester.tap(find.text('Sign in').last);
    await tester.pumpAndSettle();
    expect(gw.calls, ['in:ishita@pes.edu']);
    expect(AppPrefs.accountEmail, 'ishita@pes.edu');
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('creating an account sends the name and goes on to profile setup', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gw = _Gateway();
    await tester.pumpWidget(host(SignInScreen(gateway: gw)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create account').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Ishita Rao');
    await tester.enterText(find.byType(TextField).at(1), 'ishita@pes.edu');
    await tester.enterText(find.byType(TextField).at(2), 'secret1');
    await tester.tap(find.text('Create account').last);
    await tester.pumpAndSettle();
    expect(gw.calls, ['up:ishita@pes.edu:Ishita Rao']);
    expect(find.text('PROFILE'), findsOneWidget);
  });

  testWidgets('continue as guest lets the user in without an account', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host(SignInScreen(gateway: _Gateway())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue as guest'));
    await tester.pumpAndSettle();
    expect(AppPrefs.guest, isTrue);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('the slides can be skipped, which records them as seen and moves on to sign-in', (tester) async {
    await tester.pumpWidget(host(const OnboardingScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Skip'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(AppPrefs.onboarded, isTrue);
    expect(find.text('SIGNIN'), findsOneWidget);
  });
}
