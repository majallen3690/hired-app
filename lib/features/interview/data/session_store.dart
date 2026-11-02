import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/evaluation_models.dart';

/// Saves every finished session on the device: one JSON file and, for live sessions, one WAV.
/// Reopening a past report and its Coach Replay needs no network.
class SessionStore {
  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/sessions');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<void> save(SessionRecord r, {Uint8List? wav}) async {
    final d = await _dir();
    if (wav != null && r.audioFile != null) {
      await File('${d.path}/${r.audioFile}').writeAsBytes(wav, flush: true);
    }
    await File('${d.path}/${r.id}.json').writeAsString(jsonEncode(r.toJson()), flush: true);
  }

  Future<SessionRecord?> load(String id) async {
    final f = File('${(await _dir()).path}/$id.json');
    if (!await f.exists()) return null;
    return SessionRecord.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
  }

  /// Newest first. A damaged file is skipped, never fatal.
  Future<List<SessionRecord>> list() async {
    final out = <SessionRecord>[];
    await for (final e in (await _dir()).list()) {
      if (e is! File || !e.path.endsWith('.json')) continue;
      try {
        out.add(SessionRecord.fromJson(jsonDecode(await e.readAsString()) as Map<String, dynamic>));
      } catch (_) {}
    }
    out.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return out;
  }

  Future<String?> audioPath(SessionRecord r) async {
    final name = r.audioFile;
    if (name == null) return null;
    final f = File('${(await _dir()).path}/$name');
    return await f.exists() ? f.path : null;
  }
}

final sessionStoreProvider = Provider<SessionStore>((_) => SessionStore());

final sessionsProvider = FutureProvider<List<SessionRecord>>((ref) => ref.watch(sessionStoreProvider).list());

final sessionProvider = FutureProvider.family<SessionRecord?, String>(
  (ref, id) => ref.watch(sessionStoreProvider).load(id),
);
