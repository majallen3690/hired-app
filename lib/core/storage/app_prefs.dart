import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;

import 'app_dir.dart';

/// Small settings that outlive a switch between real and demo data: the theme, whether the hidden demo tools have
/// been unlocked, and whether demo mode is on. Read once before the first frame.
class AppPrefs {
  const AppPrefs._();

  static ThemeMode theme = ThemeMode.dark;
  static bool demoUnlocked = false;
  static bool demoOn = false;

  static Future<File> _file() async => File('${(await AppDir.real()).path}/prefs.json');

  static Future<void> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      theme = ThemeMode.values.firstWhere((m) => m.name == j['theme'], orElse: () => ThemeMode.dark);
      demoUnlocked = (j['demoUnlocked'] as bool?) ?? false;
      demoOn = (j['demoOn'] as bool?) ?? false;
    } catch (e) {
      debugPrint('Could not read preferences: $e');
    }
  }

  static Future<void> save() async {
    try {
      await (await _file()).writeAsString(
        jsonEncode({'theme': theme.name, 'demoUnlocked': demoUnlocked, 'demoOn': demoOn}),
        flush: true,
      );
    } catch (e) {
      debugPrint('Could not save preferences: $e');
    }
  }
}
