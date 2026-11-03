import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/app_dir.dart';
import '../domain/presence_record.dart';

/// Photos and their results stay on the device. Nothing here is uploaded except the one photo sent for analysis.
class PresenceStore {
  Future<Directory> _dir() async {
    final base = await AppDir.root();
    final d = Directory('${base.path}/presence');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<File> _consentFile() async => File('${(await _dir()).path}/consent');

  /// The user has agreed to send photos for analysis.
  Future<bool> hasConsent() async => (await _consentFile()).exists();

  Future<void> grantConsent() async => (await _consentFile()).writeAsString('yes', flush: true);

  Future<void> save(PresenceRecord r, {Uint8List? photo}) async {
    final d = await _dir();
    if (photo != null) await File('${d.path}/${r.photoFile}').writeAsBytes(photo, flush: true);
    await File('${d.path}/${r.id}.json').writeAsString(jsonEncode(r.toJson()), flush: true);
  }

  Future<PresenceRecord?> load(String id) async {
    final f = File('${(await _dir()).path}/$id.json');
    if (!await f.exists()) return null;
    return PresenceRecord.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
  }

  /// Newest first. A damaged file is skipped, never fatal.
  Future<List<PresenceRecord>> list() async {
    final out = <PresenceRecord>[];
    await for (final e in (await _dir()).list()) {
      if (e is! File || !e.path.endsWith('.json')) continue;
      try {
        out.add(PresenceRecord.fromJson(jsonDecode(await e.readAsString()) as Map<String, dynamic>));
      } catch (_) {}
    }
    out.sort((a, b) => b.at.compareTo(a.at));
    return out;
  }

  Future<String> photoPath(PresenceRecord r) async => '${(await _dir()).path}/${r.photoFile}';

  Future<Uint8List?> photoBytes(PresenceRecord r) async {
    final f = File(await photoPath(r));
    return await f.exists() ? f.readAsBytes() : null;
  }

  /// Removes the record and its photo.
  Future<void> delete(PresenceRecord r) async {
    final d = await _dir();
    for (final name in [r.photoFile, '${r.id}.json']) {
      final f = File('${d.path}/$name');
      if (await f.exists()) await f.delete();
    }
  }
}

final presenceStoreProvider = Provider<PresenceStore>((_) => PresenceStore());

final presenceRecordsProvider = FutureProvider<List<PresenceRecord>>((ref) => ref.watch(presenceStoreProvider).list());

final presenceRecordProvider = FutureProvider.family<PresenceRecord?, String>(
  (ref, id) => ref.watch(presenceStoreProvider).load(id),
);
