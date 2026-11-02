import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/structured.dart';
import '../home/scores_provider.dart';
import '../interview/domain/speech_metrics.dart';
import '../resume/resume_flow.dart';
import 'audio/intro_recorder.dart';
import 'data/intro_ai.dart';
import 'data/intro_store.dart';
import 'domain/intro_analysis.dart';
import 'domain/intro_models.dart';

enum IntroPhase { idle, recording, transcribing, scoring, failed }

class IntroState {
  const IntroState({
    this.phase = IntroPhase.idle,
    this.elapsedMs = 0,
    this.levels = const [],
    this.notice,
    this.error,
    this.savedId,
  });

  final IntroPhase phase;
  final int elapsedMs;

  /// Recent microphone levels, newest last.
  final List<double> levels;

  /// A gentle message on the setup screen: too short, nothing heard.
  final String? notice;

  /// Why a recording could not be processed; shown with a retry.
  final String? error;
  final String? savedId;

  int get secondsLeft => (introSeconds - elapsedMs / 1000).ceil().clamp(0, introSeconds);

  IntroState copyWith({
    IntroPhase? phase,
    int? elapsedMs,
    List<double>? levels,
    String? notice,
    String? error,
    String? savedId,
    bool clearNotice = false,
    bool clearError = false,
  }) =>
      IntroState(
        phase: phase ?? this.phase,
        elapsedMs: elapsedMs ?? this.elapsedMs,
        levels: levels ?? this.levels,
        notice: clearNotice ? null : (notice ?? this.notice),
        error: clearError ? null : (error ?? this.error),
        savedId: savedId ?? this.savedId,
      );
}

class IntroController extends Notifier<IntroState> {
  final _ai = const IntroAi();
  IntroRecorder? _recorder;
  StreamSubscription<double>? _levelSub;
  Timer? _tick;
  IntroCapture? _pending;
  var _target = '';

  @override
  IntroState build() {
    ref.onDispose(() {
      _tick?.cancel();
      _levelSub?.cancel();
      _recorder?.cancel();
    });
    return const IntroState();
  }

  void setTarget(String t) => _target = t.trim();

  Future<void> start() async {
    if (state.phase == IntroPhase.recording) return;
    final recorder = IntroRecorder();
    final ok = await recorder.start();
    if (!ok) {
      state = state.copyWith(
        notice: 'The microphone is not available. Allow it in Settings, or type your intro instead.',
      );
      return;
    }
    _recorder = recorder;
    state = IntroState(phase: IntroPhase.recording);
    _levelSub = recorder.levels.listen((l) {
      final next = [...state.levels, l];
      state = state.copyWith(levels: next.length > 48 ? next.sublist(next.length - 48) : next);
    });
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final r = _recorder;
      if (r == null) return;
      state = state.copyWith(elapsedMs: r.elapsedMs);
      if (r.elapsedMs >= introSeconds * 1000) stop();
    });
  }

  /// Back to the start, throwing the recording away.
  Future<void> restart() async {
    _tick?.cancel();
    await _levelSub?.cancel();
    await _recorder?.cancel();
    _recorder = null;
    _pending = null;
    state = const IntroState();
  }

  Future<void> stop() async {
    final r = _recorder;
    if (r == null || state.phase != IntroPhase.recording) return;
    _tick?.cancel();
    await _levelSub?.cancel();
    _recorder = null;
    final capture = await r.stop();
    await _process(capture);
  }

  /// Runs the processing again on the recording already made, after a failure.
  Future<void> retryProcessing() async {
    final capture = _pending;
    if (capture == null) return restart();
    await _process(capture);
  }

  void clearNotice() => state = state.copyWith(clearNotice: true);

  Future<void> _process(IntroCapture capture) async {
    _pending = capture;
    if (capture.durationMs < 5000) {
      _pending = null;
      state = IntroState(notice: 'That was too short. Aim for 30 to 60 seconds.');
      return;
    }
    final span = detectSpeech(capture.amplitude);
    if (span == null) {
      _pending = null;
      state = IntroState(notice: 'We could not hear you. Check the microphone, speak closer and try again.');
      return;
    }

    try {
      state = IntroState(phase: IntroPhase.transcribing);
      final transcript = await _ai.transcribe(capture.wav);
      final words = wordCount(transcript);
      if (words < minIntroWords) {
        _pending = null;
        state = IntroState(notice: 'We only caught $words words. Say a bit more and try again.');
        return;
      }
      if (!transcriptMatchesAudio(words, span.lengthMs)) {
        _pending = null;
        state = IntroState(notice: 'The words did not match the recording. Try again somewhere quieter.');
        return;
      }
      final delivery = measureDelivery(
        transcript: transcript,
        durationMs: capture.durationMs,
        amplitude: capture.amplitude,
      );
      final now = DateTime.now();
      final id = 'intro-${now.millisecondsSinceEpoch}';
      final base = IntroRecord(
        id: id,
        startedAt: now.subtract(Duration(milliseconds: capture.durationMs)),
        durationMs: capture.durationMs,
        mode: IntroMode.spoken,
        transcript: transcript,
        target: _target,
        delivery: delivery,
        audioFile: '$id.wav',
      );
      state = IntroState(phase: IntroPhase.scoring);
      await _scoreAndSave(base, wav: capture.wav);
      _pending = null;
    } on AiException catch (e) {
      state = IntroState(phase: IntroPhase.failed, error: e.message);
    }
  }

  /// A typed intro: no voice to measure, so content only.
  Future<void> submitTyped(String text) async {
    final transcript = text.trim();
    final words = wordCount(transcript);
    if (words < minIntroWords) {
      state = IntroState(notice: 'Write at least $minIntroWords words so there is something to judge.');
      return;
    }
    final now = DateTime.now();
    final base = IntroRecord(
      id: 'intro-${now.millisecondsSinceEpoch}',
      startedAt: now,
      durationMs: 0,
      mode: IntroMode.typed,
      transcript: transcript,
      target: _target,
    );
    state = IntroState(phase: IntroPhase.scoring);
    try {
      await _scoreAndSave(base);
    } on AiException catch (e) {
      state = IntroState(phase: IntroPhase.failed, error: e.message);
    }
  }

  /// Scores the words. If scoring fails the transcript and measurements are still saved, so the result screen can offer
  /// a retry without recording again.
  Future<void> _scoreAndSave(IntroRecord base, {Uint8List? wav}) async {
    final store = ref.read(introStoreProvider);
    IntroRecord record;
    try {
      final evaluation = await _ai.evaluate(
        transcript: base.transcript,
        target: base.target,
        resume: ref.read(resumeFlowProvider).resume,
      );
      record = base.copyWith(evaluation: evaluation);
    } on AiException catch (e) {
      record = base.copyWith(failed: e.message);
    }
    await store.save(record, wav: wav);
    _publish(record);
    state = IntroState(savedId: record.id);
  }

  /// The result screen's "Score it now" after a failed scoring.
  Future<String?> retryEvaluation(String id) async {
    final store = ref.read(introStoreProvider);
    final r = await store.load(id);
    if (r == null) return 'This intro was not found.';
    try {
      final evaluation = await _ai.evaluate(
        transcript: r.transcript,
        target: r.target,
        resume: ref.read(resumeFlowProvider).resume,
      );
      final scored = r.copyWith(evaluation: evaluation, clearFailed: true);
      await store.save(scored);
      _publish(scored);
      return null;
    } on AiException catch (e) {
      return e.message;
    }
  }

  void _publish(IntroRecord r) {
    ref.invalidate(introsProvider);
    ref.invalidate(introProvider(r.id));
    if (r.countsAsSpeaking) ref.read(latestScoresProvider.notifier).setCommunication(r.score!);
  }

  void reset() => state = const IntroState();
}

final introControllerProvider = NotifierProvider.autoDispose<IntroController, IntroState>(IntroController.new);
