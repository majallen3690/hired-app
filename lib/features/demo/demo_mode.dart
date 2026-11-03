import '../../core/storage/app_dir.dart';
import '../../core/storage/app_prefs.dart';
import 'demo_seeder.dart';

/// Switches between the user's own data and the sample persona. The two live in separate folders, so turning demo
/// mode off returns everything exactly as it was. The caller restarts the app's providers afterwards
/// (`restartApp`), which makes every store read the folder it now points at.
class DemoMode {
  const DemoMode._();

  static bool get isOn => AppDir.demo;

  /// Writes a fresh copy of the persona and points the app at it. Also used to reset: dates move to now.
  static Future<void> turnOn({DemoSeeder? seeder}) async {
    final was = AppDir.demo;
    AppDir.demo = true;
    try {
      await (seeder ?? DemoSeeder()).seed();
    } catch (_) {
      AppDir.demo = was;
      rethrow;
    }
    AppPrefs.demoOn = true;
    await AppPrefs.save();
  }

  static Future<void> turnOff() async {
    AppDir.demo = false;
    AppPrefs.demoOn = false;
    await AppPrefs.save();
  }
}
