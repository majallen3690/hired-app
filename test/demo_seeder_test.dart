import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hired/core/storage/app_dir.dart';
import 'package:hired/features/demo/demo_seeder.dart';
import 'package:hired/features/home/scores_provider.dart';
import 'package:hired/features/interview/data/session_store.dart';
import 'package:hired/features/interview/domain/evaluation_models.dart';
import 'package:hired/features/intro/domain/intro_models.dart';
import 'package:hired/features/tracker/domain/application_models.dart';

/// A bundle of small, plainly synthetic inputs shaped like the real demo assets, so the seeder's own logic is tested
/// without depending on what Gemini returned on a given day.
class _Bundle extends CachingAssetBundle {
  _Bundle(this.files);
  final Map<String, Object> files;

  @override
  Future<ByteData> load(String key) async {
    final f = files[key];
    if (f == null) throw FlutterError('no asset $key');
    final bytes = f is String ? utf8.encode(f) : f as List<int>;
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}

Dimension _d(int s) => Dimension(score: s, evidence: null);

QuestionEval _q(int s) => QuestionEval(
      question: 'Q',
      structure: _d(s),
      relevance: _d(s),
      depth: _d(s),
      clarity: _d(s),
      situation: true,
      task: true,
      action: true,
      result: s > 3,
      good: 'Clear opening',
      fix: 'Add a number',
      modelAnswer: 'x',
    );

Map<String, dynamic> _session(String id, int daysAgo, int rating, {int words = 40}) => {
      'id': id,
      'daysAgo': daysAgo,
      'hour': 18,
      'durationMs': 60000,
      'config': {'role': 'SDE', 'company': 'Acme', 'round': 'technical', 'questionCount': 1},
      'turns': [
        {'speaker': 'interviewer', 'text': 'Tell me about a project.', 'startMs': 1000, 'endMs': 4000},
        {
          'speaker': 'candidate',
          'text': List.filled(words, 'word').join(' '),
          'startMs': 5000,
          'endMs': 5000 + words * 400,
        },
      ],
      'rating': rating,
    };

void main() {
  late Directory tmp;
  late _Bundle bundle;
  final now = DateTime(2026, 11, 3, 12);

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tmp = await Directory.systemTemp.createTemp('hired-demo-test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp.path,
    );
    AppDir.demo = true;

    final sessions = [_session('demo-s1', 19, 2), _session('demo-s2', 2, 4)];
    final intro = {'id': 'demo-i1', 'daysAgo': 5, 'hour': 21, 'durationMs': 30000, 'target': 'SDE'};
    IntroEvaluation introEval() => IntroEvaluation(
          headline: 'h',
          clarity: _d(4),
          structure: _d(4),
          confidence: _d(4),
          who: const PartCheck(covered: true, evidence: null, note: ''),
          what: const PartCheck(covered: true, evidence: null, note: ''),
          why: const PartCheck(covered: false, note: 'missing'),
          good: 'g',
          fix: 'f',
          stronger: 's',
        );
    final fixtures = {
      'resumeMatches': {
        'v1': {'role': 'SDE', 'overall': 41},
        'v2': {'role': 'SDE', 'overall': 58},
        'v3': {'role': 'Software Development Engineer I', 'overall': 74},
      },
      'sessions': {
        for (final s in sessions)
          s['id'] as String: {
            'evaluation': InterviewEvaluation(
              headline: 'h',
              questions: [_q(s['rating'] as int)],
              topFixes: const ['a', 'b', 'c'],
            ).toJson(),
            'pauses': [
              {'startMs': 9000, 'endMs': 14000},
            ],
          },
      },
      'intros': {
        'demo-i1': {
          'transcript': 'hello there',
          'delivery': null,
          'evaluation': introEval().toJson(),
        },
      },
      'autofill': {
        for (final k in ['razorpay', 'zoho', 'swiggy', 'flipkart', 'freshworks'])
          k: {
            'company': k,
            'role': 'Engineer',
            'skills': ['Java'],
          },
      },
    };
    bundle = _Bundle({
      'assets/demo/fixtures.json': jsonEncode(fixtures),
      'assets/demo/resumes.json': jsonEncode({
        'v3': {'name': 'Ishita Rao'},
      }),
      'assets/demo/sessions.json': jsonEncode(sessions),
      'assets/demo/intros.json': jsonEncode([intro]),
      for (final k in ['razorpay', 'zoho', 'swiggy', 'flipkart', 'freshworks']) 'assets/demo/jds/$k.txt': 'JD for $k',
      'assets/demo/audio/demo-s1.wav': [1, 2, 3],
      'assets/demo/audio/demo-s2.wav': [4, 5, 6],
      'assets/demo/audio/demo-i1.wav': [7, 8, 9],
    });
  });

  tearDown(() async {
    AppDir.demo = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), null);
    await tmp.delete(recursive: true);
  });

  test('writes into the demo folder and leaves the real one alone', () async {
    await DemoSeeder(bundle: bundle, now: now).seed();
    expect(File('${tmp.path}/demo/scores.json').existsSync(), isTrue);
    expect(File('${tmp.path}/demo/applications.json').existsSync(), isTrue);
    expect(File('${tmp.path}/scores.json').existsSync(), isFalse);
    expect(Directory('${tmp.path}/sessions').existsSync(), isFalse);
  });

  test('refuses to write unless demo mode is on', () async {
    AppDir.demo = false;
    expect(DemoSeeder(bundle: bundle, now: now).seed(), throwsStateError);
  });

  test('the home scores are worked out from the saved results, newest result last', () async {
    await DemoSeeder(bundle: bundle, now: now).seed();
    final scores = MeasuredScores.fromJson(
      jsonDecode(await File('${tmp.path}/demo/scores.json').readAsString()) as Map<String, dynamic>,
    );
    // Latest resume match, and the newer of the two sessions (all ratings 4 -> 80).
    expect(scores.resume, 74);
    expect(scores.interview, 80);
    expect(scores.presence, isNull);
    expect(scores.communication, isNotNull);
  });

  test('the resume history climbs and every date is in the past', () async {
    await DemoSeeder(bundle: bundle, now: now).seed();
    final events = jsonDecode(await File('${tmp.path}/demo/resume_events.json').readAsString()) as List;
    final values = [for (final e in events) e['value'] as int];
    expect(values, [41, 58, 74]);
    final times = [for (final e in events) DateTime.parse(e['at'] as String)];
    expect(times.every((t) => t.isBefore(now)), isTrue);
    expect(times, [...times]..sort());
  });

  test('sessions are saved with their recording and a rating note per answer', () async {
    await DemoSeeder(bundle: bundle, now: now).seed();
    final store = SessionStore();
    final list = await store.list();
    expect(list.map((s) => s.id), ['demo-s2', 'demo-s1']);
    final s = list.first;
    expect(s.startedAt.toLocal(), DateTime(2026, 11, 1, 18));
    expect(s.signals.single.quality, 4);
    expect(s.signals.single.atMs, s.turns.last.endMs);
    expect(s.pauses.single.lengthMs, 5000);
    expect(await File((await store.audioPath(s))!).readAsBytes(), [4, 5, 6]);
  });

  test('the tracker has eight applications, two with upcoming interviews and one overdue for a follow-up', () async {
    await DemoSeeder(bundle: bundle, now: now).seed();
    final apps = [
      for (final a in jsonDecode(await File('${tmp.path}/demo/applications.json').readAsString()) as List)
        JobApplication.fromJson(a as Map<String, dynamic>),
    ];
    expect(apps, hasLength(8));
    expect(apps.where((a) => a.interviewAt != null && a.interviewAt!.isAfter(now)), hasLength(2));
    expect(apps.map((a) => a.stage).toSet(), containsAll([Stage.wishlist, Stage.applied, Stage.oa, Stage.interview, Stage.rejected]));
    final swiggy = apps.firstWhere((a) => a.id == 'demo-app-swiggy');
    expect(now.difference(swiggy.stageChangedAt).inDays, greaterThanOrEqualTo(5));
  });

  test('seeding again replaces the old persona instead of adding to it', () async {
    await DemoSeeder(bundle: bundle, now: now).seed();
    await DemoSeeder(bundle: bundle, now: now.add(const Duration(days: 2))).seed();
    expect(await SessionStore().list(), hasLength(2));
    final events = jsonDecode(await File('${tmp.path}/demo/resume_events.json').readAsString()) as List;
    expect(events, hasLength(3));
  });

  test('wiping clears the data but keeps the settings file', () async {
    final prefs = File('${tmp.path}/prefs.json')..writeAsStringSync('{}');
    await DemoSeeder(bundle: bundle, now: now).seed();
    await AppDir.wipe(await AppDir.root());
    expect(File('${tmp.path}/demo/scores.json').existsSync(), isFalse);
    expect(prefs.existsSync(), isTrue);
  });
}
