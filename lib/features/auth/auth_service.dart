import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/boot.dart';
import '../../core/storage/app_prefs.dart';

class AuthUser {
  const AuthUser({required this.uid, required this.email, this.name});
  final String uid;
  final String email;
  final String? name;
}

/// A failure with a message that is safe to show as it is.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// What the rest of the app needs from sign-in, so screens and tests never touch Firebase directly.
abstract class AuthGateway {
  Future<AuthUser> signIn(String email, String password);
  Future<AuthUser> signUp(String email, String password, String name);
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();
}

/// Plain-language messages for the ways email sign-in fails. Anything unexpected gets a generic line; the raw code
/// goes to the debug log, never to the user.
String friendlyAuthError(String code) => switch (code) {
      'invalid-email' => 'That email address does not look right.',
      'user-not-found' || 'wrong-password' || 'invalid-credential' || 'invalid-login-credentials' =>
        'Email or password is not right.',
      'user-disabled' => 'This account has been turned off.',
      'email-already-in-use' => 'There is already an account with that email. Try signing in.',
      'weak-password' => 'Pick a longer password: at least 6 characters.',
      'too-many-requests' => 'Too many tries. Wait a few minutes and try again.',
      'network-request-failed' => 'No connection. Check your internet and try again.',
      'operation-not-allowed' => 'Email sign-in is not switched on for this app yet. You can continue as a guest.',
      _ => 'Could not sign you in. Please try again.',
    };

/// Basic checks before anything is sent, so the obvious mistakes never cost a round trip.
String? validateEmail(String v) {
  final t = v.trim();
  if (t.isEmpty) return 'Enter your email.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) return 'That email address does not look right.';
  return null;
}

String? validatePassword(String v) {
  if (v.isEmpty) return 'Enter a password.';
  if (v.length < 6) return 'Use at least 6 characters.';
  return null;
}

class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Future<T> _run<T>(Future<T> Function() work) async {
    await firebaseReady;
    try {
      return await work();
    } on FirebaseAuthException catch (e) {
      debugPrint('Auth failed: ${e.code}');
      throw AuthException(friendlyAuthError(e.code));
    } catch (e) {
      debugPrint('Auth failed: $e');
      throw const AuthException('Could not reach the sign-in service. Please try again.');
    }
  }

  AuthUser _user(User u) => AuthUser(uid: u.uid, email: u.email ?? '', name: u.displayName);

  @override
  Future<AuthUser> signIn(String email, String password) => _run(() async {
        final c = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
        return _user(c.user!);
      });

  @override
  Future<AuthUser> signUp(String email, String password, String name) => _run(() async {
        final c = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
        final u = c.user!;
        if (name.trim().isNotEmpty) await u.updateDisplayName(name.trim());
        return AuthUser(uid: u.uid, email: u.email ?? email.trim(), name: name.trim().isEmpty ? null : name.trim());
      });

  @override
  Future<void> sendPasswordReset(String email) => _run(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> signOut() => _run(() => _auth.signOut());
}

/// Who is using the app, as the router and screens see it. The account is remembered on the device so the app opens
/// straight to Home; Firebase confirms it in the background.
class Session extends ChangeNotifier {
  Session(this.gateway);
  final AuthGateway gateway;

  bool get authed => AppPrefs.signedIn || AppPrefs.guest;

  Future<void> signedInAs(AuthUser u) async {
    AppPrefs.accountEmail = u.email;
    AppPrefs.accountName = u.name;
    AppPrefs.guest = false;
    await AppPrefs.save();
    notifyListeners();
  }

  Future<void> continueAsGuest() async {
    AppPrefs.guest = true;
    await AppPrefs.save();
    notifyListeners();
  }

  /// A guest who wants an account: forget guest mode so the router sends them to sign-in.
  Future<void> leaveGuest() async {
    AppPrefs.guest = false;
    await AppPrefs.save();
    notifyListeners();
  }

  /// Signing out leaves the data on the phone; it only forgets who the user is.
  Future<void> signOut() async {
    try {
      if (AppPrefs.signedIn) await gateway.signOut();
    } catch (e) {
      debugPrint('Sign out: $e');
    }
    AppPrefs.accountEmail = null;
    AppPrefs.accountName = null;
    AppPrefs.guest = false;
    await AppPrefs.save();
    notifyListeners();
  }

  Future<void> finishOnboarding() async {
    AppPrefs.onboarded = true;
    await AppPrefs.save();
    notifyListeners();
  }

  /// Called once Firebase is up: if the account was removed or its token revoked elsewhere, forget it here too.
  Future<void> verify() async {
    if (!AppPrefs.signedIn) return;
    try {
      await firebaseReady;
      final u = FirebaseAuth.instance.currentUser;
      if (u == null) {
        AppPrefs.accountEmail = null;
        AppPrefs.accountName = null;
        await AppPrefs.save();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Could not verify the account: $e');
    }
  }
}

final session = Session(FirebaseAuthGateway());
