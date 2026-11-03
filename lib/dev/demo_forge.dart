import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../core/ai/structured.dart';
import '../core/audio/wav_amplitude.dart';
import '../core/config/ai_config.dart';
import '../features/interview/data/interview_ai.dart';
import '../features/interview/domain/interview_models.dart';
import '../features/interview/domain/speech_metrics.dart';
import '../features/intro/data/intro_ai.dart';
import '../features/intro/domain/intro_analysis.dart';
import '../features/resume/data/resume_ai.dart';
import '../features/tracker/data/tracker_ai.dart';

/// Run with `--dart-define=FORGE_DEMO=true`. Gives the demo persona her history by running the app's own pipelines
/// on the authored inputs in `assets/demo/`, and saves what they return to `demo_fixtures.json` in the app's
/// external files folder. Nothing in that file is typed by hand: the ratings and quotes are Gemini's, the
/// transcripts of the intros are Gemini's transcription of the recordings, and the pauses and delivery numbers are
/// measured from the audio by the same functions a live session uses.
const forgeDemo = bool.fromEnvironment('FORGE_DEMO');

const _jdKeys = ['razorpay', 'zoho', 'swiggy', 'flipkart', 'freshworks'];

/// Which version of her resume she had when each thing happened.
const _sessionResume = {'demo-s1': 'v1', 'demo-s2': 'v2', 'demo-s3': 'v3'};
const _introResume = {'demo-i1': 'v1', 'demo-i2': 'v2'};

void _log(String m) => debugPrint('FORGE $m');

/// The free tier rate-limits; wait and try again rather than lose a run.
Future<T> _patient<T>(String what, Future<T> Function() call) async {
  for (var attempt = 1;; attempt++) {
    try {
      return await call();
    } on AiException catch (e) {
      if (attempt >= 5) rethrow;
      _log('$what failed (${e.message}), waiting before attempt ${attempt + 1}');
      await Future<void>.delayed(const Duration(seconds: 25));
    }
  }
}

Future<void> runDemoForge() async {
  try {
    final dir = await getExternalStorageDirectory();
    if (dir == null) throw StateError('no external storage');
    final file = File('${dir.path}/demo_fixtures.json');
    // A rerun continues from what an earlier run already saved, so a rate limit never costs finished work.
    final out = file.existsSync()
        ? jsonDecode(await file.readAsString()) as Map<String, dynamic>
        : <String, dynamic>{};
    Future<void> save() => file.writeAsString(const JsonEncoder.withIndent(' ').convert(out), flush: true);

    out['generatedAt'] = DateTime.now().toUtc().toIso8601String();
    out['textModel'] = AiConfig.textModel;
    out['fastModel'] = AiConfig.fastModel;

    final resumes = jsonDecode(await rootBundle.loadString('assets/demo/resumes.json')) as Map<String, dynamic>;
    final jds = {for (final k in _jdKeys) k: await rootBundle.loadString('assets/demo/jds/$k.txt')};

    // 1. The same job, three versions of the resume: the score the progress chart climbs along.
    final matches = (out['resumeMatches'] as Map<String, dynamic>?) ?? {};
    out['resumeMatches'] = matches;
    for (final v in ['v1', 'v2', 'v3']) {
      if (matches.containsKey(v)) continue;
      _log('matching resume $v to the payments job');
      final r = await _patient('match $v', () => const ResumeAi().match(resumes[v] as Map<String, dynamic>, jds['razorpay']!));
      matches[v] = {
        'role': r.role,
        'overall': r.overall,
        'keyword': r.keywordScore,
        'semantic': r.semanticScore,
        'rubric': r.rubricScore,
        'requirements': r.requirements.length,
        'matched': r.requirements.where((q) => q.matched).length,
      };
      await save();
      _log('  $v -> ${r.overall}');
    }

    // 2. The three mock interviews: ratings from the evaluator, pauses measured from the recording.
    final sessions = jsonDecode(await rootBundle.loadString('assets/demo/sessions.json')) as List;
    final evaluated = (out['sessions'] as Map<String, dynamic>?) ?? {};
    out['sessions'] = evaluated;
    for (final raw in sessions) {
      final s = raw as Map<String, dynamic>;
      final id = s['id'] as String;
      if (evaluated.containsKey(id)) continue;
      final turns = [
        for (final t in s['turns'] as List)
          TranscriptTurn(
            speaker: t['speaker'] == 'candidate' ? Speaker.candidate : Speaker.interviewer,
            text: t['text'] as String,
            startMs: t['startMs'] as int,
            endMs: t['endMs'] as int,
          ),
      ];
      final wav = (await rootBundle.load('assets/demo/audio/$id.wav')).buffer.asUint8List();
      final amplitude = wavAmplitude(wav);
      final duration = s['durationMs'] as int;
      final pauses = findLongPauses(amplitude, candidateWindows(turns, duration));
      _log('evaluating $id (${pauses.length} long pauses)');
      final eval = await _patient(
        'evaluate $id',
        () => const InterviewAi().evaluate(
          config: InterviewConfig.fromJson(s['config'] as Map<String, dynamic>),
          resume: resumes[_sessionResume[id]!] as Map<String, dynamic>,
          turns: turns,
        ),
      );
      evaluated[id] = {'evaluation': eval.toJson(), 'pauses': [for (final p in pauses) p.toJson()]};
      await save();
      _log('  $id -> interview ${eval.interviewScore}');
    }

    // 3. The two spoken intros go through the real path: transcribe the recording, measure it, then rate the words.
    final intros = jsonDecode(await rootBundle.loadString('assets/demo/intros.json')) as List;
    final scored = (out['intros'] as Map<String, dynamic>?) ?? {};
    out['intros'] = scored;
    for (final raw in intros) {
      final i = raw as Map<String, dynamic>;
      final id = i['id'] as String;
      if (scored.containsKey(id)) continue;
      final wav = (await rootBundle.load('assets/demo/audio/$id.wav')).buffer.asUint8List();
      final amplitude = wavAmplitude(wav);
      final span = detectSpeech(amplitude);
      if (span == null) throw StateError('$id: no speech found in the recording');
      _log('transcribing $id');
      final transcript = await _patient('transcribe $id', () => const IntroAi().transcribe(wav));
      final words = wordCount(transcript);
      if (words < minIntroWords || !transcriptMatchesAudio(words, span.lengthMs)) {
        throw StateError('$id: transcript does not fit the recording ($words words)');
      }
      final delivery = measureDelivery(transcript: transcript, durationMs: i['durationMs'] as int, amplitude: amplitude);
      final eval = await _patient(
        'rate $id',
        () => const IntroAi().evaluate(
          transcript: transcript,
          target: i['target'] as String,
          resume: resumes[_introResume[id]!] as Map<String, dynamic>,
        ),
      );
      scored[id] = {
        'transcript': transcript,
        'delivery': delivery?.toJson(),
        'evaluation': eval.toJson(),
      };
      await save();
      _log('  $id -> content ${eval.contentScore}, delivery ${delivery?.score}');
    }

    // 4. What the tracker reads out of each pasted job description.
    final autofill = (out['autofill'] as Map<String, dynamic>?) ?? {};
    out['autofill'] = autofill;
    for (final k in _jdKeys) {
      if (autofill.containsKey(k)) continue;
      _log('reading the $k job description');
      final a = await _patient('autofill $k', () => const TrackerAi().autofill(jds[k]!));
      autofill[k] = {'company': a.company, 'role': a.role, 'skills': a.skills};
      await save();
    }

    _log('DONE ${file.path}');
  } catch (e, st) {
    _log('FAILED $e\n$st');
  }
}
