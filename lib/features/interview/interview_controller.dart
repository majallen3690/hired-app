import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/structured.dart';
import '../home/scores_provider.dart';
import 'data/interview_ai.dart';
import 'data/session_store.dart';
import 'domain/evaluation_models.dart';
import 'domain/interview_models.dart';
import 'domain/speech_metrics.dart';
import 'live/live_interview_service.dart';

enum InterviewPhase { idle, connecting, live, wrapping, done, failed }

class InterviewState {
  const InterviewState({
    this.phase = InterviewPhase.idle,
    this.config,
    this.mode = SessionMode.live,
    this.turns = const [],
    this.signals = const [],
    this.interviewerSpeaking = false,
    this.level = 0,
    this.notice,
    this.reconnecting = false,
    this.questions = const [],
    this.questionIndex = 0,
    this.startedAt,
    this.savedId,
    this.error,
    this.wrapStep = '',
  });

  final InterviewPhase phase;
  final InterviewConfig? config;
  final SessionMode mode;
  final List<TranscriptTurn> turns;
  final List<AnswerSignal> signals;
  final bool interviewerSpeaking;
  final double level;

  /// A calm one-liner such as "Standard mode" or "Microphone denied, type your answers".
  final String? notice;
  final bool reconnecting;

  /// Standard mode only.
  final List<String> questions;
  final int questionIndex;

  final DateTime? startedAt;
  final String? savedId;
  final String? error;
  final String wrapStep;

  InterviewState copyWith({
    InterviewPhase? phase,
    InterviewConfig? config,
    SessionMode? mode,
    List<TranscriptTurn>? turns,
    List<AnswerSignal>? signals,
    bool? interviewerSpeaking,
    double? level,
    String? notice,
    bool? reconnecting,
    List<String>? questions,
    int? questionIndex,
    DateTime? startedAt,
    String? savedId,
    String? error,
    String? wrapStep,
    bool clearNotice = false,
  }) =>
      InterviewState(
        phase: phase ?? this.phase,
        config: config ?? this.config,
        mode: mode ?? this.mode,
        turns: turns ?? this.turns,
        signals: signals ?? this.signals,
        interviewerSpeaking: interviewerSpeaking ?? this.interviewerSpeaking,
        level: level ?? this.level,
        notice: clearNotice ? null : (notice ?? this.notice),
        reconnecting: reconnecting ?? this.reconnecting,
        questions: questions ?? this.questions,
        questionIndex: questionIndex ?? this.questionIndex,
        startedAt: startedAt ?? this.startedAt,
        savedId: savedId ?? this.savedId,
        error: error ?? this.error,
        wrapStep: wrapStep ?? this.wrapStep,
      );

  int get answered => signals.length.clamp(0, config?.questionCount ?? 5);
}

class InterviewController extends Notifier<InterviewState> {
  final _ai = const InterviewAi();
  LiveInterviewService? _svc;
  StreamSubscription<LiveEvent>? _sub;
  Map<String, dynamic>? _resume;
  final _stdClock = Stopwatch();
  final List<TranscriptTurn> _stdTurns = [];

  @override
  InterviewState build() {
    ref.onDispose(() => _sub?.cancel());
    return const InterviewState();
  }

  Future<void> start(InterviewConfig config, Map<String, dynamic> resume) async {
    _resume = resume;
    _stdTurns.clear();
    state = InterviewState(phase: InterviewPhase.connecting, config: config, startedAt: DateTime.now());
    final svc = LiveInterviewService(config: config, persona: buildPersona(config, resume));
    _svc = svc;
    _sub = svc.events.listen(_onEvent);
    try {
      await svc.start();
      state = state.copyWith(phase: InterviewPhase.live, mode: SessionMode.live);
    } catch (e) {
      debugPrint('Live interview unavailable, switching to standard mode: $e');
      await _sub?.cancel();
      try {
        await svc.end();
      } catch (_) {}
      _svc = null;
      await _startStandard(config, resume);
    }
  }

  /// The quiet fallback: same evaluation, just question by question.
  Future<void> _startStandard(InterviewConfig config, Map<String, dynamic> resume) async {
    try {
      final qs = await _ai.planQuestions(config: config, resume: resume);
      _stdClock
        ..reset()
        ..start();
      state = state.copyWith(
        phase: InterviewPhase.live,
        mode: SessionMode.standard,
        questions: qs,
        questionIndex: 0,
        notice: 'Standard mode',
      );
    } on AiException catch (e) {
      state = state.copyWith(phase: InterviewPhase.failed, error: e.message);
    }
  }

  void _onEvent(LiveEvent e) {
    final svc = _svc;
    switch (e) {
      case LiveConnected():
        state = state.copyWith(clearNotice: true, reconnecting: false);
      case LiveFloor():
        state = state.copyWith(interviewerSpeaking: e.interviewer);
      case LiveTurnsChanged():
        if (svc != null) state = state.copyWith(turns: List.of(svc.turns));
      case LiveSignalLogged():
        state = state.copyWith(signals: List.of(svc?.signals ?? const []));
      case LiveLevel():
        state = state.copyWith(level: e.level);
      case LiveReconnecting():
        state = state.copyWith(reconnecting: true, notice: 'Reconnecting…');
      case LiveMicUnavailable():
        state = state.copyWith(notice: e.reason);
      case LiveFinished():
        finish(note: e.message);
    }
  }

  /// A typed answer, in live mode (same session) or standard mode (next question).
  void sendText(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return;
    if (state.mode == SessionMode.live) {
      _svc?.sendText(clean);
      return;
    }
    final now = _stdClock.elapsedMilliseconds;
    final q = state.questions[state.questionIndex];
    _stdTurns
      ..add(TranscriptTurn(speaker: Speaker.interviewer, text: q, startMs: now, endMs: now))
      ..add(TranscriptTurn(speaker: Speaker.candidate, text: clean, startMs: now, endMs: now, typed: true));
    final next = state.questionIndex + 1;
    state = state.copyWith(turns: List.of(_stdTurns), questionIndex: next);
    if (next >= state.questions.length) finish();
  }

  /// Ends the session, saves it, then evaluates. Safe to call twice.
  Future<void> finish({String? note}) async {
    if (state.phase == InterviewPhase.wrapping || state.phase == InterviewPhase.done) return;
    final config = state.config;
    final resume = _resume;
    if (config == null || resume == null) return;
    state = state.copyWith(phase: InterviewPhase.wrapping, wrapStep: 'Saving your session', notice: note);

    final live = _svc;
    LiveCapture? capture;
    if (live != null) {
      capture = await live.end();
      _svc = null;
    }
    final turns = capture?.turns ?? List.of(_stdTurns);
    final duration = capture?.durationMs ?? _stdClock.elapsedMilliseconds;
    final pauses = capture?.pauses ?? const <Pause>[];
    final signals = capture?.signals ?? const <AnswerSignal>[];

    if (!turns.any((t) => t.speaker == Speaker.candidate)) {
      state = state.copyWith(
        phase: InterviewPhase.failed,
        error: 'No answers were captured, so there is nothing to score yet.',
      );
      return;
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final communication = communicationScore(summariseSpeech(turns, pauses: pauses));
    var record = SessionRecord(
      id: id,
      startedAt: state.startedAt ?? DateTime.now(),
      durationMs: duration,
      config: config,
      mode: capture != null ? SessionMode.live : SessionMode.standard,
      turns: turns,
      signals: signals,
      pauses: pauses,
      audioFile: capture != null ? '$id.wav' : null,
      communication: communication,
    );
    final store = ref.read(sessionStoreProvider);
    await store.save(record, wav: capture?.wav);

    state = state.copyWith(wrapStep: 'Reading your answers');
    try {
      final eval = await _ai.evaluate(config: config, resume: resume, turns: turns);
      record = record.copyWith(evaluation: eval);
      await store.save(record);
      ref.read(latestScoresProvider.notifier).setInterview(eval.interviewScore, communication);
    } on AiException catch (e) {
      record = record.copyWith(failedEvaluation: e.message);
      await store.save(record);
    }
    ref.invalidate(sessionsProvider);
    state = state.copyWith(phase: InterviewPhase.done, savedId: id);
  }

  /// From the report: try the evaluation again on a saved session.
  Future<String?> retryEvaluation(String id) async {
    final store = ref.read(sessionStoreProvider);
    final record = await store.load(id);
    final resume = _resume;
    if (record == null || resume == null) return 'Open the Resume tab once so the interview knows your resume.';
    try {
      final eval = await _ai.evaluate(config: record.config, resume: resume, turns: record.turns);
      await store.save(record.copyWith(evaluation: eval));
      ref.read(latestScoresProvider.notifier).setInterview(eval.interviewScore, record.communication);
      ref.invalidate(sessionProvider(id));
      ref.invalidate(sessionsProvider);
      return null;
    } on AiException catch (e) {
      return e.message;
    }
  }

  void setResume(Map<String, dynamic> resume) => _resume = resume;

  void reset() {
    _sub?.cancel();
    _svc = null;
    state = const InterviewState();
  }
}

final interviewControllerProvider =
    NotifierProvider<InterviewController, InterviewState>(InterviewController.new);
