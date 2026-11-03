import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../core/scoring/readiness.dart';
import '../../core/storage/app_dir.dart';
import '../home/scores_provider.dart';
import '../interview/data/session_store.dart';
import '../interview/domain/evaluation_models.dart';
import '../interview/domain/interview_models.dart';
import '../interview/domain/speech_metrics.dart';
import '../intro/data/intro_store.dart';
import '../intro/domain/intro_models.dart';
import '../progress/domain/progress_models.dart';
import '../tracker/domain/application_models.dart';

/// When her three resume versions were matched to the payments job, in days before the demo starts.
const _resumeMatchDays = {'v1': (20, 19), 'v2': (11, 20), 'v3': (3, 18)};

/// Writes the demo persona's three weeks into the demo data folder.
///
/// Every number comes from somewhere real. The ratings, quotes, transcripts and skill lists are what Gemini returned
/// when `lib/dev/demo_forge.dart` ran the app's pipelines on the authored inputs (`assets/demo/fixtures.json`).
/// Scores, pauses, speaking measurements and the latest readiness figures are worked out here from those results
/// by the same code the app uses for a real session. Dates are relative to now, so the three weeks always end this
/// week.
class DemoSeeder {
  DemoSeeder({AssetBundle? bundle, DateTime? now}) : _bundle = bundle ?? rootBundle, _now = now ?? DateTime.now();

  final AssetBundle _bundle;
  final DateTime _now;

  DateTime _at(int daysAgo, int hour) => DateTime(_now.year, _now.month, _now.day - daysAgo, hour);

  Future<dynamic> _json(String path) async {
    try {
      return jsonDecode(await _bundle.loadString(path));
    } catch (e) {
      throw StateError('Demo data is missing ($path). Run the forge described in docs/DEMO.md. $e');
    }
  }

  Future<void> seed() async {
    if (!AppDir.demo) throw StateError('Demo data is only written while demo mode is on.');
    final root = await AppDir.root();
    final fx = await _json('assets/demo/fixtures.json') as Map<String, dynamic>;
    final resumes = await _json('assets/demo/resumes.json') as Map<String, dynamic>;
    final sessionScripts = await _json('assets/demo/sessions.json') as List;
    final introScripts = await _json('assets/demo/intros.json') as List;

    await AppDir.wipe(root);

    final sessions = await _sessions(sessionScripts, fx['sessions'] as Map<String, dynamic>);
    final intros = await _intros(introScripts, fx['intros'] as Map<String, dynamic>);
    final matches = fx['resumeMatches'] as Map<String, dynamic>;

    // The saved resume is her latest version, the one the app would have kept after her last match.
    await File('${root.path}/resume.json').writeAsString(
      jsonEncode({'resume': resumes['v3'], 'role': (matches['v3'] as Map)['role']}),
      flush: true,
    );

    final events = [
      for (final e in _resumeMatchDays.entries)
        ScoreEvent(
          id: 'resume-demo-${e.key}',
          at: _at(e.value.$1, e.value.$2),
          area: SubScore.resume,
          value: (matches[e.key] as Map)['overall'] as int,
        ),
    ];
    await File('${root.path}/resume_events.json').writeAsString(
      jsonEncode([for (final e in events) e.toJson()]),
      flush: true,
    );

    await File('${root.path}/scores.json').writeAsString(
      jsonEncode(_latest(events, sessions, intros).toJson()),
      flush: true,
    );

    await File('${root.path}/applications.json').writeAsString(
      jsonEncode([for (final a in await _applications(fx['autofill'] as Map<String, dynamic>)) a.toJson()]),
      flush: true,
    );
  }

  Future<List<SessionRecord>> _sessions(List scripts, Map<String, dynamic> fixtures) async {
    final store = SessionStore();
    final out = <SessionRecord>[];
    for (final raw in scripts) {
      final s = raw as Map<String, dynamic>;
      final id = s['id'] as String;
      final f = fixtures[id] as Map<String, dynamic>;
      final turns = [
        for (final t in s['turns'] as List)
          TranscriptTurn(
            speaker: t['speaker'] == 'candidate' ? Speaker.candidate : Speaker.interviewer,
            text: t['text'] as String,
            startMs: t['startMs'] as int,
            endMs: t['endMs'] as int,
          ),
      ];
      final pauses = [for (final p in f['pauses'] as List) Pause.fromJson(p as Map<String, dynamic>)];
      final evaluation = InterviewEvaluation.fromJson(f['evaluation'] as Map<String, dynamic>);

      // A live interviewer logs a quick quality note after each answer. Here each note is the evaluator's own
      // rating and "what went well" for that answer, placed where the answer ended.
      final answers = turns.where((t) => t.speaker == Speaker.candidate).toList();
      final signals = <AnswerSignal>[
        for (var i = 0; i < evaluation.questions.length && i < answers.length; i++)
          AnswerSignal(
            atMs: answers[i].endMs,
            quality: evaluation.questions[i].score.round().clamp(1, 5),
            note: evaluation.questions[i].good,
          ),
      ];

      final record = SessionRecord(
        id: id,
        startedAt: _at(s['daysAgo'] as int, s['hour'] as int),
        durationMs: s['durationMs'] as int,
        config: InterviewConfig.fromJson(s['config'] as Map<String, dynamic>),
        mode: SessionMode.live,
        turns: turns,
        signals: signals,
        pauses: pauses,
        evaluation: evaluation,
        audioFile: '$id.wav',
        communication: communicationScore(summariseSpeech(turns, pauses: pauses)),
      );
      await store.save(record, wav: (await _bundle.load('assets/demo/audio/$id.wav')).buffer.asUint8List());
      out.add(record);
    }
    return out;
  }

  Future<List<IntroRecord>> _intros(List scripts, Map<String, dynamic> fixtures) async {
    final store = IntroStore();
    final out = <IntroRecord>[];
    for (final raw in scripts) {
      final i = raw as Map<String, dynamic>;
      final id = i['id'] as String;
      final f = fixtures[id] as Map<String, dynamic>;
      final record = IntroRecord(
        id: id,
        startedAt: _at(i['daysAgo'] as int, i['hour'] as int),
        durationMs: i['durationMs'] as int,
        mode: IntroMode.spoken,
        transcript: f['transcript'] as String,
        target: i['target'] as String,
        delivery: f['delivery'] == null ? null : IntroDelivery.fromJson(f['delivery'] as Map<String, dynamic>),
        evaluation: IntroEvaluation.fromJson(f['evaluation'] as Map<String, dynamic>),
        audioFile: '$id.wav',
      );
      await store.save(record, wav: (await _bundle.load('assets/demo/audio/$id.wav')).buffer.asUint8List());
      out.add(record);
    }
    return out;
  }

  /// The home screen's four numbers as the app itself would have left them after the last thing she did. Presence is
  /// left unmeasured on purpose: it is the one check worth doing live in front of an audience.
  MeasuredScores _latest(List<ScoreEvent> resume, List<SessionRecord> sessions, List<IntroRecord> intros) {
    final byTime = [...resume]..sort((a, b) => a.at.compareTo(b.at));
    final finished = [for (final s in sessions) if (s.evaluation != null) s]
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    // The speaking score is whichever measured result came last, a mock interview or a spoken intro.
    final speaking = <(DateTime, int)>[
      for (final s in finished)
        if (s.communication != null) (s.startedAt.add(Duration(milliseconds: s.durationMs)), s.communication!),
      for (final i in intros)
        if (i.countsAsSpeaking) (i.startedAt.add(Duration(milliseconds: i.durationMs)), i.score!),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    return MeasuredScores(
      resume: byTime.isEmpty ? null : byTime.last.value,
      interview: finished.isEmpty ? null : finished.last.evaluation!.interviewScore,
      communication: speaking.isEmpty ? null : speaking.last.$2,
    );
  }

  Future<List<JobApplication>> _applications(Map<String, dynamic> autofill) async {
    Future<String> jd(String key) => _bundle.loadString('assets/demo/jds/$key.txt');

    Future<JobApplication> app(
      String key, {
      required String id,
      required Stage stage,
      required int created,
      required int changed,
      DateTime? interviewAt,
      String notes = '',
    }) async {
      final read = autofill[key] as Map<String, dynamic>;
      return JobApplication(
        id: 'demo-app-$id',
        company: read['company'] as String,
        role: read['role'] as String,
        stage: stage,
        createdAt: _at(created, 10),
        stageChangedAt: _at(changed, 10),
        jd: (await jd(key)).trim(),
        skills: [for (final s in read['skills'] as List) s as String],
        notes: notes,
        interviewAt: interviewAt,
      );
    }

    JobApplication bare(
      String id,
      String company,
      String role,
      Stage stage, {
      required int created,
      required int changed,
      String notes = '',
    }) =>
        JobApplication(
          id: 'demo-app-$id',
          company: company,
          role: role,
          stage: stage,
          createdAt: _at(created, 10),
          stageChangedAt: _at(changed, 10),
          notes: notes,
        );

    return [
      await app(
        'razorpay',
        id: 'razorpay',
        stage: Stage.interview,
        created: 12,
        changed: 4,
        interviewAt: DateTime(_now.year, _now.month, _now.day + 1, 11),
        notes: 'Round 1 cleared. Next is the technical round with the payments team. Revise idempotency keys and the '
            'Seat Finder query story.',
      ),
      await app(
        'zoho',
        id: 'zoho',
        stage: Stage.oa,
        created: 9,
        changed: 2,
        interviewAt: DateTime(_now.year, _now.month, _now.day + 3, 15),
        notes: 'Online test: three coding problems in 90 minutes. Practise arrays and strings.',
      ),
      await app('swiggy', id: 'swiggy', stage: Stage.applied, created: 6, changed: 6, notes: 'Referred by a senior. No reply yet.'),
      await app('freshworks', id: 'freshworks', stage: Stage.applied, created: 4, changed: 4),
      await app('flipkart', id: 'flipkart', stage: Stage.applied, created: 2, changed: 2),
      bare('google', 'Google', 'Software Engineer, University Graduate', Stage.wishlist, created: 7, changed: 7),
      bare('atlassian', 'Atlassian', 'Graduate Software Engineer', Stage.wishlist, created: 5, changed: 5),
      bare(
        'paytm',
        'Paytm',
        'Software Development Engineer I',
        Stage.rejected,
        created: 15,
        changed: 8,
        notes: 'Rejected after the online test. Practise dynamic programming.',
      ),
    ];
  }
}
