import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Where the app keeps its data. Demo mode points this at a folder of its own, so the sample persona never mixes
/// with a real user's results and switching back finds everything exactly as it was.
class AppDir {
  const AppDir._();

  static bool demo = false;

  /// What the stores read and write: the real folder, or the demo folder inside it.
  static Future<Directory> root() async {
    final base = await getApplicationDocumentsDirectory();
    if (!demo) return base;
    final d = Directory('${base.path}/demo');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// Always the real folder: settings that must survive a switch between real and demo data live here.
  static Future<Directory> real() => getApplicationDocumentsDirectory();

  /// Everything the app saves about its user. Deleting these (and only these) clears the data in [root].
  static const dataEntries = [
    'scores.json',
    'resume.json',
    'resume_events.json',
    'applications.json',
    'sessions',
    'intros',
    'presence',
  ];

  static Future<void> wipe(Directory dir) async {
    for (final name in dataEntries) {
      final path = '${dir.path}/$name';
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.directory) await Directory(path).delete(recursive: true);
      if (type == FileSystemEntityType.file) await File(path).delete();
    }
  }
}
