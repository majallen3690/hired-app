import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hired/core/route_gate.dart';
import 'package:hired/core/storage/app_prefs.dart';
import 'package:hired/features/auth/auth_service.dart';

class _FakeGateway implements AuthGateway {
  var signedOut = false;
  @override
  Future<AuthUser> signIn(String email, String password) async => AuthUser(uid: 'u', email: email);
  @override
  Future<AuthUser> signUp(String email, String password, String name) async => AuthUser(uid: 'u', email: email, name: name);
  @override
  Future<void> sendPasswordReset(String email) async {}
  @override
  Future<void> signOut() async => signedOut = true;
}

String? go(String at, {bool demo = false, bool onboarded = true, bool authed = true}) =>
    gateRedirect(location: at, demo: demo, onboarded: onboarded, authed: authed);

void main() {
  group('route gate', () {
    test('a first launch sees the slides before anything else', () {
      expect(go('/home', onboarded: false, authed: false), '/onboarding');
      expect(go('/onboarding', onboarded: false, authed: false), isNull);
      expect(go('/splash', onboarded: false, authed: false), isNull);
    });

    test('after the slides, someone who is not signed in is held at sign-in', () {
      expect(go('/home', authed: false), '/sign-in');
      expect(go('/tracker/abc', authed: false), '/sign-in');
      expect(go('/sign-in', authed: false), isNull);
    });

    test('a signed-in user or guest goes straight through and never lands on the entry screens', () {
      expect(go('/home'), isNull);
      expect(go('/sign-in'), '/home');
      expect(go('/onboarding'), '/home');
      expect(go('/profile-setup'), isNull);
    });

    test('demo mode skips the gate completely', () {
      expect(go('/home', demo: true, onboarded: false, authed: false), isNull);
      expect(go('/sign-in', demo: true, onboarded: false, authed: false), '/home');
    });
  });

  group('sign-in messages and checks', () {
    test('known codes become plain language and unknown ones a generic line', () {
      expect(friendlyAuthError('wrong-password'), contains('not right'));
      expect(friendlyAuthError('invalid-credential'), friendlyAuthError('user-not-found'));
      expect(friendlyAuthError('email-already-in-use'), contains('signing in'));
      expect(friendlyAuthError('operation-not-allowed'), contains('guest'));
      expect(friendlyAuthError('something-new'), contains('try again'));
    });

    test('email and password are checked before anything is sent', () {
      expect(validateEmail(''), isNotNull);
      expect(validateEmail('ishita@'), isNotNull);
      expect(validateEmail(' ishita@pes.edu '), isNull);
      expect(validatePassword(''), isNotNull);
      expect(validatePassword('12345'), isNotNull);
      expect(validatePassword('123456'), isNull);
    });
  });

  group('session', () {
    late Directory tmp;
    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      tmp = await Directory.systemTemp.createTemp('hired-auth-test');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => tmp.path,
      );
      AppPrefs.accountEmail = null;
      AppPrefs.accountName = null;
      AppPrefs.guest = false;
      AppPrefs.onboarded = false;
    });
    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), null);
      await tmp.delete(recursive: true);
    });

    test('signing in is remembered across a restart, and the first name comes from the account', () async {
      final s = Session(_FakeGateway());
      expect(s.authed, isFalse);
      await s.signedInAs(const AuthUser(uid: 'u', email: 'ishita@pes.edu', name: 'Ishita Rao'));
      expect(s.authed, isTrue);
      expect(AppPrefs.firstName, 'Ishita');

      AppPrefs.accountEmail = null;
      AppPrefs.accountName = null;
      await AppPrefs.load();
      expect(AppPrefs.accountEmail, 'ishita@pes.edu');
    });

    test('a guest is let in, and signing out forgets the account but keeps the slides seen', () async {
      final gw = _FakeGateway();
      final s = Session(gw);
      await s.finishOnboarding();
      await s.continueAsGuest();
      expect(s.authed, isTrue);
      await s.signedInAs(const AuthUser(uid: 'u', email: 'a@b.co'));
      await s.signOut();
      expect(gw.signedOut, isTrue);
      expect(s.authed, isFalse);
      expect(AppPrefs.onboarded, isTrue);
    });
  });
}
