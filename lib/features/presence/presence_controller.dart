import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/structured.dart';
import '../home/scores_provider.dart';
import 'data/presence_ai.dart';
import 'data/presence_store.dart';
import 'domain/presence_models.dart';
import 'domain/presence_record.dart';

enum PresencePhase { idle, analysing, failed }

class PresenceState {
  const PresenceState({this.phase = PresencePhase.idle, this.error, this.notice, this.resultId});

  final PresencePhase phase;
  final String? error;

  /// A gentle message on the camera screen, such as "we could not see a face".
  final String? notice;

  /// Set once a check is analysed and saved, so the camera screen can open its result.
  final String? resultId;
}

class PresenceController extends Notifier<PresenceState> {
  final _ai = const PresenceAi();

  @override
  PresenceState build() => const PresenceState();

  PresenceStore get _store => ref.read(presenceStoreProvider);

  void notice(String message) => state = PresenceState(notice: message);
  void clearNotice() => state = const PresenceState();

  Future<bool> hasConsent() => _store.hasConsent();
  Future<void> grantConsent() => _store.grantConsent();

  /// Saves the photo and the on-phone measurements first, so nothing is lost if the model cannot be reached, then asks
  /// the model to read the photo. The check does not count towards the score until the user saves it.
  Future<void> analyse({required Uint8List jpeg, required Occasion occasion, required FaceFrame frame}) async {
    state = const PresenceState(phase: PresencePhase.analysing);
    final now = DateTime.now();
    final id = 'presence-${now.millisecondsSinceEpoch}';
    var record = PresenceRecord(id: id, at: now, occasion: occasion, photoFile: '$id.jpg', frame: frame);
    await _store.save(record, photo: jpeg);
    try {
      record = record.copyWith(evaluation: await _ai.evaluate(jpeg, occasion));
    } on AiException catch (e) {
      record = record.copyWith(failed: e.message);
    }
    await _store.save(record);
    ref.invalidate(presenceRecordsProvider);
    state = PresenceState(resultId: id);
  }

  /// The result screen's "Try again" after the model could not be reached.
  Future<String?> retry(String id) async {
    final r = await _store.load(id);
    final photo = r == null ? null : await _store.photoBytes(r);
    if (r == null || photo == null) return 'This photo was not found.';
    try {
      final scored = r.copyWith(evaluation: await _ai.evaluate(photo, r.occasion), clearFailed: true);
      await _store.save(scored);
      ref.invalidate(presenceRecordProvider(id));
      ref.invalidate(presenceRecordsProvider);
      return null;
    } on AiException catch (e) {
      return e.message;
    }
  }

  /// "Save to my score": from now on this check counts.
  Future<void> save(String id) async {
    final r = await _store.load(id);
    if (r == null || r.score == null) return;
    await _store.save(r.copyWith(saved: true));
    ref.invalidate(presenceRecordProvider(id));
    ref.invalidate(presenceRecordsProvider);
    ref.read(latestScoresProvider.notifier).setPresence(r.score!);
  }

  /// Removes a check and its photo. If it was the newest saved one, the presence score steps back to the one before.
  Future<void> delete(String id) async {
    final r = await _store.load(id);
    if (r == null) return;
    await _store.delete(r);
    final remaining = (await _store.list()).where((x) => x.countsTowardsScore).toList();
    ref.invalidate(presenceRecordsProvider);
    ref.invalidate(presenceRecordProvider(id));
    if (r.saved) ref.read(latestScoresProvider.notifier).setPresence(remaining.firstOrNull?.score);
  }

  void reset() => state = const PresenceState();
}

final presenceControllerProvider = NotifierProvider.autoDispose<PresenceController, PresenceState>(PresenceController.new);
