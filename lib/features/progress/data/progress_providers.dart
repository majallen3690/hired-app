import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/scoring/readiness.dart';
import '../../../core/storage/app_dir.dart';
import '../../interview/data/session_store.dart';
import '../../intro/data/intro_store.dart';
import '../../presence/data/presence_store.dart';
import '../domain/progress_models.dart';

/// Every resume match, kept on the device. Interview results are not stored here: each saved session already holds
/// its own scores and time, so the chart reads them straight from there and can never disagree with a report.
class ResumeEvents extends Notifier<List<ScoreEvent>> {
  @override
  List<ScoreEvent> build() {
    _load();
    return const [];
  }

  Future<Directory> _dir() => AppDir.root();

  Future<void> _load() async {
    try {
      final dir = await _dir();
      final f = File('${dir.path}/resume_events.json');
      if (await f.exists()) {
        final list = jsonDecode(await f.readAsString()) as List;
        state = [
          for (final e in list) ScoreEvent.fromJson(e as Map<String, dynamic>),
        ];
        return;
      }
    } catch (e) {
      debugPrint('Could not read resume history: $e');
    }
  }

  Future<void> _save() async {
    try {
      final f = File('${(await _dir()).path}/resume_events.json');
      await f.writeAsString(
        jsonEncode([for (final e in state) e.toJson()]),
        flush: true,
      );
    } catch (e) {
      debugPrint('Could not save resume history: $e');
    }
  }

  void add(int score) {
    final now = DateTime.now();
    state = [
      ...state,
      ScoreEvent(
        id: 'resume-${now.millisecondsSinceEpoch}',
        at: now,
        area: SubScore.resume,
        value: score,
      ),
    ];
    _save();
  }
}

final resumeEventsProvider = NotifierProvider<ResumeEvents, List<ScoreEvent>>(
  ResumeEvents.new,
);

/// Resume matches, the interview and speaking score of every scored session, every spoken intro and every saved
/// presence check.
final scoreEventsProvider = Provider<List<ScoreEvent>>((ref) {
  final resume = ref.watch(resumeEventsProvider);
  final sessions = ref.watch(sessionsProvider).asData?.value ?? const [];
  final fromSessions = <ScoreEvent>[];
  for (final s in sessions) {
    final eval = s.evaluation;
    if (eval == null) continue;
    final at = s.startedAt.add(Duration(milliseconds: s.durationMs));
    fromSessions.add(
      ScoreEvent(
        id: '${s.id}-interview',
        at: at,
        area: SubScore.interview,
        value: eval.interviewScore,
      ),
    );
    final speaking = s.communication;
    if (speaking != null) {
      fromSessions.add(
        ScoreEvent(
          id: '${s.id}-speaking',
          at: at,
          area: SubScore.communication,
          value: speaking,
        ),
      );
    }
  }
  final intros = ref.watch(introsProvider).asData?.value ?? const [];
  final fromIntros = [
    for (final i in intros)
      if (i.countsAsSpeaking)
        ScoreEvent(
          id: '${i.id}-intro',
          at: i.startedAt.add(Duration(milliseconds: i.durationMs)),
          area: SubScore.communication,
          value: i.score!,
        ),
  ];
  final presence = ref.watch(presenceRecordsProvider).asData?.value ?? const [];
  final fromPresence = [
    for (final p in presence)
      if (p.countsTowardsScore) ScoreEvent(id: '${p.id}-presence', at: p.at, area: SubScore.presence, value: p.score!),
  ];
  return [...resume, ...fromSessions, ...fromIntros, ...fromPresence];
});

final progressProvider = Provider<ProgressSummary>(
  (ref) =>
      summariseProgress(ref.watch(scoreEventsProvider), now: DateTime.now()),
);
