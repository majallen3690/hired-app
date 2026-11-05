import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;

import 'app_dir.dart';

/// Small settings that outlive a switch between real and demo data: the theme, whether the hidden demo tools have
/// been unlocked, whether demo mode is on, and who is using the app. Read once before the first frame.
class AppPrefs {
  const AppPrefs._();

  static ThemeMode theme = ThemeMode.dark;
  static bool demoUnlocked = false;
  static bool demoOn = false;

  /// The first-run slides have been seen.
  static bool onboarded = false;

  /// Using the app without an account. Everything still works; it just stays on this phone.
  static bool guest = false;

  /// The signed-in account, kept so the app can open straight to Home before Firebase has finished starting.
  static String? accountEmail;
  static String? accountName;

  /// Set when the user finishes (or skips) profile setup.
  static bool profileDone = false;
  static String targetRole = '';
  static String branch = '';
  static int? gradYear;
  static List<String> dreamCompanies = [];

  static bool haptics = true;

  /// Widget tests turn this off: real file writes never finish under the test clock.
  @visibleForTesting
  static bool persist = true;

  static bool get signedIn => accountEmail != null;

  static Future<File> _file() async => File('${(await AppDir.real()).path}/prefs.json');

  static Future<void> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      theme = ThemeMode.values.firstWhere((m) => m.name == j['theme'], orElse: () => ThemeMode.dark);
      demoUnlocked = (j['demoUnlocked'] as bool?) ?? false;
      demoOn = (j['demoOn'] as bool?) ?? false;
      onboarded = (j['onboarded'] as bool?) ?? false;
      guest = (j['guest'] as bool?) ?? false;
      accountEmail = j['accountEmail'] as String?;
      accountName = j['accountName'] as String?;
      profileDone = (j['profileDone'] as bool?) ?? false;
      targetRole = (j['targetRole'] as String?) ?? '';
      branch = (j['branch'] as String?) ?? '';
      gradYear = j['gradYear'] as int?;
      dreamCompanies = [for (final c in (j['dreamCompanies'] as List?) ?? const []) '$c'];
      haptics = (j['haptics'] as bool?) ?? true;
    } catch (e) {
      debugPrint('Could not read preferences: $e');
    }
  }

  static Future<void> save() async {
    if (!persist) return;
    try {
      await (await _file()).writeAsString(
        jsonEncode({
          'theme': theme.name,
          'demoUnlocked': demoUnlocked,
          'demoOn': demoOn,
          'onboarded': onboarded,
          'guest': guest,
          'accountEmail': accountEmail,
          'accountName': accountName,
          'profileDone': profileDone,
          'targetRole': targetRole,
          'branch': branch,
          'gradYear': gradYear,
          'dreamCompanies': dreamCompanies,
          'haptics': haptics,
        }),
        flush: true,
      );
    } catch (e) {
      debugPrint('Could not save preferences: $e');
    }
  }

  /// A first name to greet the user with, from the account, then the profile; null when nothing is known.
  static String? get firstName {
    final n = accountName?.trim();
    if (n == null || n.isEmpty) return null;
    return n.split(RegExp(r'\s+')).first;
  }
}
