import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/intro_models.dart';

/// Every scored intro is kept on the device: one JSON file and, for a spoken one, the recording.
/// Reopening a result and comparing with the last try needs no network.
class IntroStore {
  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/intros');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<void> save(IntroRecord r, {Uint8List? wav}) async {
    final d = await _dir();
    if (wav != null && r.audioFile != null) {
      await File('${d.path}/${r.audioFile}').writeAsBytes(wav, flush: true);
    }
    await File('${d.path}/${r.id}.json').writeAsString(jsonEncode(r.toJson()), flush: true);
  }

  Future<IntroRecord?> load(String id) async {
    final f = File('${(await _dir()).path}/$id.json');
    if (!await f.exists()) return null;
    return IntroRecord.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
  }

  /// Newest first. A damaged file is skipped, never fatal.
  Future<List<IntroRecord>> list() async {
    final out = <IntroRecord>[];
    await for (final e in (await _dir()).list()) {
      if (e is! File || !e.path.endsWith('.json')) continue;
      try {
        out.add(IntroRecord.fromJson(jsonDecode(await e.readAsString()) as Map<String, dynamic>));
      } catch (_) {}
    }
    out.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return out;
  }

  Future<String?> audioPath(IntroRecord r) async {
    final name = r.audioFile;
    if (name == null) return null;
    final f = File('${(await _dir()).path}/$name');
    return await f.exists() ? f.path : null;
  }
}

final introStoreProvider = Provider<IntroStore>((_) => IntroStore());

final introsProvider = FutureProvider<List<IntroRecord>>((ref) => ref.watch(introStoreProvider).list());

final introProvider = FutureProvider.family<IntroRecord?, String>(
  (ref, id) => ref.watch(introStoreProvider).load(id),
);
