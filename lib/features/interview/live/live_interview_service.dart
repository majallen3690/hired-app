import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:record/record.dart';

import '../../../core/boot.dart';
import '../../../core/config/ai_config.dart';
import '../audio/pcm_mixer.dart';
import '../data/interview_ai.dart';
import '../domain/interview_models.dart';
import '../domain/speech_metrics.dart';

sealed class LiveEvent {}

class LiveConnected extends LiveEvent {
  LiveConnected(this.model);
  final String model;
}

/// Who currently has the floor, for the orb and wave.
class LiveFloor extends LiveEvent {
  LiveFloor({required this.interviewer});
  final bool interviewer;
}

class LiveTurnsChanged extends LiveEvent {}

class LiveSignalLogged extends LiveEvent {
  LiveSignalLogged(this.signal);
  final AnswerSignal signal;
}

/// Microphone level 0 to 1, for the wave.
class LiveLevel extends LiveEvent {
  LiveLevel(this.level);
  final double level;
}

class LiveReconnecting extends LiveEvent {}

class LiveMicUnavailable extends LiveEvent {
  LiveMicUnavailable(this.reason);
  final String reason;
}

/// The interviewer finished (called endInterview) or the connection could not be kept.
class LiveFinished extends LiveEvent {
  LiveFinished({required this.completed, this.message});
  final bool completed;
  final String? message;
}

class LiveCapture {
  const LiveCapture({
    required this.turns,
    required this.signals,
    required this.pauses,
    required this.durationMs,
    required this.wav,
  });
  final List<TranscriptTurn> turns;
  final List<AnswerSignal> signals;
  final List<Pause> pauses;
  final int durationMs;
  final Uint8List wav;
}

/// One Gemini Live interview: microphone in, interviewer voice out, transcript and tool calls on the side.
/// Everything is timestamped on one clock so Coach Replay can line it all up.
class LiveInterviewService {
  LiveInterviewService({required this.config, required this.persona});

  final InterviewConfig config;
  final String persona;

  final _events = StreamController<LiveEvent>.broadcast();
  Stream<LiveEvent> get events => _events.stream;

  final _clock = Stopwatch();
  int get nowMs => _clock.elapsedMilliseconds;

  final recorder = SessionAudioRecorder();
  final List<TranscriptTurn> turns = [];
  final List<AnswerSignal> signals = [];
  final List<AmplitudeSample> _amplitude = [];

  LiveSession? _session;
  AudioRecorder? _mic;
  StreamSubscription<Uint8List>? _micSub;
  StreamSubscription<Amplitude>? _ampSub;
  StreamSubscription<LiveServerResponse>? _msgSub;
  Timer? _floorTimer;
  Completer<void>? _setupDone;

  TranscriptTurn? _open;
  int? _modelTurnStartMs;
  bool _modelTurnDone = false;
  bool _endRequested = false;
  bool _ending = false;
  bool _interviewerHasFloor = false;
  bool _playerReady = false;
  int _reconnects = 0;
  String _modelName = AiConfig.liveModel;

  Future<void> start() async {
    _clock.start();
    await _connect();
    await _startPlayer();
    await _startMic();
    _floorTimer = Timer.periodic(const Duration(milliseconds: 150), (_) => _updateFloor());
    _session?.sendTextRealtime('The candidate has joined the call. Greet them and begin the interview.');
  }

  /// Tries the main live model, then the fallback, before giving up.
  Future<void> _connect({String? recap}) async {
    Object? lastError;
    await firebaseReady;
    for (final name in [AiConfig.liveModel, AiConfig.liveModelFallback]) {
      try {
        final model = FirebaseAI.googleAI().liveGenerativeModel(
          model: name,
          systemInstruction: Content.system(persona),
          tools: interviewTools(),
          liveGenerationConfig: LiveGenerationConfig(
            responseModalities: [ResponseModalities.audio],
            speechConfig: SpeechConfig(voiceName: 'Charon'),
            inputAudioTranscription: AudioTranscriptionConfig(),
            outputAudioTranscription: AudioTranscriptionConfig(),
          ),
        );
        _setupDone = Completer<void>();
        final session = await model.connect().timeout(const Duration(seconds: 15));
        _session = session;
        await _msgSub?.cancel();
        _msgSub = session.receive().listen(_onResponse, onError: _onStreamError, onDone: _onStreamDone);
        await _setupDone!.future.timeout(const Duration(seconds: 15));
        _modelName = name;
        _events.add(LiveConnected(name));
        if (recap != null) session.sendTextRealtime(recap);
        return;
      } catch (e) {
        lastError = e;
        debugPrint('Live connect failed for $name: $e');
        await _msgSub?.cancel();
        await _session?.close();
        _session = null;
      }
    }
    throw lastError ?? StateError('Live connection failed');
  }

  Future<void> _startPlayer() async {
    try {
      await FlutterPcmSound.setup(sampleRate: modelRate, channelCount: 1);
      _playerReady = true;
    } catch (e) {
      debugPrint('Audio output unavailable: $e');
    }
  }

  Future<void> _startMic() async {
    try {
      final mic = AudioRecorder();
      if (!await mic.hasPermission()) {
        _events.add(LiveMicUnavailable('Microphone permission was denied. You can still type your answers.'));
        await mic.dispose();
        return;
      }
      _mic = mic;
      final stream = await mic.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: micRate,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        androidConfig: AndroidRecordConfig(audioSource: AndroidAudioSource.voiceCommunication),
      ));
      _micSub = stream.listen((data) {
        if (data.isEmpty || _ending) return;
        final chunkMs = (data.length / 2 * 1000 / micRate).round();
        recorder.addCandidate(math.max(0, nowMs - chunkMs), data);
        try {
          _session?.sendAudioRealtime(InlineDataPart('audio/pcm;rate=$micRate', data));
        } catch (_) {
          // The socket is closing; the done handler deals with it.
        }
      });
      _ampSub = mic.onAmplitudeChanged(const Duration(milliseconds: 200)).listen((a) {
        _amplitude.add(AmplitudeSample(nowMs, a.current));
        _events.add(LiveLevel(((a.current + 60) / 60).clamp(0.0, 1.0)));
      });
    } catch (e) {
      debugPrint('Microphone failed: $e');
      _events.add(LiveMicUnavailable('The microphone could not start. You can still type your answers.'));
    }
  }

  void _updateFloor() {
    final speaking = recorder.modelCursorMs > nowMs;
    if (speaking != _interviewerHasFloor) {
      _interviewerHasFloor = speaking;
      _events.add(LiveFloor(interviewer: speaking));
    }
    if (_endRequested && !speaking && !_ending) {
      _endRequested = false;
      _events.add(LiveFinished(completed: true));
    }
  }

  void _onResponse(LiveServerResponse r) {
    final m = r.message;
    // The first thing the server sends after our setup message is its setup-complete acknowledgement.
    if (_setupDone?.isCompleted == false) _setupDone!.complete();
    switch (m) {
      case LiveServerContent():
        _onContent(m);
      case LiveServerToolCall():
        _onToolCall(m);
      default:
        break;
    }
  }

  void _onContent(LiveServerContent c) {
    if (c.interrupted == true) {
      _onInterrupted();
    }
    for (final part in c.modelTurn?.parts ?? const <Part>[]) {
      if (part is InlineDataPart && part.mimeType.startsWith('audio/')) _onModelAudio(part.bytes);
    }
    final said = c.inputTranscription?.text;
    if (said != null && said.isNotEmpty) _appendTranscript(Speaker.candidate, said);
    final asked = c.outputTranscription?.text;
    if (asked != null && asked.isNotEmpty) _appendTranscript(Speaker.interviewer, asked);
    if (c.turnComplete == true) {
      _modelTurnDone = true;
      final open = _open;
      if (open != null && open.speaker == Speaker.interviewer) {
        _replaceOpen(open.copyWith(endMs: math.max(open.endMs, recorder.modelCursorMs)));
      }
    }
  }

  void _onModelAudio(Uint8List bytes) {
    if (_modelTurnDone) {
      _open = null;
      _modelTurnDone = false;
      _modelTurnStartMs = null;
    }
    final start = recorder.addModel(nowMs, bytes);
    _modelTurnStartMs ??= start;
    if (_open?.speaker == Speaker.candidate) _open = null;
    if (_playerReady) {
      final samples = pcmFromBytes(bytes);
      FlutterPcmSound.feed(PcmArrayInt16(bytes: ByteData.sublistView(samples)));
    }
  }

  Future<void> _onInterrupted() async {
    recorder.interrupt(nowMs);
    final open = _open;
    if (open != null && open.speaker == Speaker.interviewer) {
      _replaceOpen(open.copyWith(endMs: math.min(open.endMs, nowMs)));
    }
    _open = null;
    _modelTurnDone = false;
    _modelTurnStartMs = null;
    if (_playerReady) {
      // Drop whatever is still queued so the interviewer stops talking at once.
      await FlutterPcmSound.release();
      await _startPlayer();
    }
  }

  void _appendTranscript(Speaker who, String text) {
    final open = _open;
    if (open != null && open.speaker == who) {
      _replaceOpen(open.copyWith(
        text: open.text + text,
        endMs: who == Speaker.interviewer ? math.max(open.endMs, recorder.modelCursorMs) : nowMs,
      ));
    } else {
      final int start;
      if (who == Speaker.interviewer) {
        start = _modelTurnStartMs ?? math.max(nowMs, recorder.modelCursorMs);
      } else {
        // The transcript trails the speech, so back-date the start a little.
        final lastEnd = turns.isEmpty ? 0 : turns.last.endMs;
        start = math.max(lastEnd, nowMs - 2000);
      }
      final turn = TranscriptTurn(
        speaker: who,
        text: text,
        startMs: start,
        endMs: who == Speaker.interviewer ? math.max(start, recorder.modelCursorMs) : nowMs,
      );
      turns.add(turn);
      _open = turn;
    }
    _events.add(LiveTurnsChanged());
  }

  void _replaceOpen(TranscriptTurn t) {
    final i = turns.lastIndexWhere((x) => identical(x, _open));
    if (i >= 0) turns[i] = t;
    _open = t;
    _events.add(LiveTurnsChanged());
  }

  void _onToolCall(LiveServerToolCall call) {
    final responses = <FunctionResponse>[];
    for (final fc in call.functionCalls ?? const <FunctionCall>[]) {
      switch (fc.name) {
        case 'logAnswerSignal':
          final q = (fc.args['quality'] as num?)?.round().clamp(1, 5) ?? 3;
          final signal = AnswerSignal(atMs: nowMs, quality: q, note: (fc.args['note'] as String?) ?? '');
          signals.add(signal);
          _events.add(LiveSignalLogged(signal));
        case 'endInterview':
          _endRequested = true;
      }
      responses.add(FunctionResponse(fc.name, {'ok': true}, id: fc.id));
    }
    try {
      _session?.sendToolResponse(responses);
    } catch (e) {
      debugPrint('Tool response failed: $e');
    }
  }

  /// A typed answer: the same session, so the interviewer reacts exactly as it would to speech.
  void sendText(String text) {
    final clean = text.trim();
    if (clean.isEmpty || _ending) return;
    _open = null;
    turns.add(TranscriptTurn(speaker: Speaker.candidate, text: clean, startMs: nowMs, endMs: nowMs, typed: true));
    _events.add(LiveTurnsChanged());
    try {
      _session?.sendTextRealtime(clean);
    } catch (e) {
      debugPrint('sendText failed: $e');
    }
  }

  void _onStreamError(Object e) {
    debugPrint('Live stream error: $e');
    final setup = _setupDone;
    if (setup != null && !setup.isCompleted) {
      setup.completeError(e); // the model name was rejected: let _connect try the fallback
      return;
    }
    _dropped();
  }

  void _onStreamDone() {
    final setup = _setupDone;
    if (setup != null && !setup.isCompleted) {
      setup.completeError(StateError('closed before setup'));
      return;
    }
    _dropped();
  }

  Future<void> _dropped() async {
    if (_ending) return;
    if (_reconnects >= 1) {
      _events.add(LiveFinished(completed: false, message: 'The connection dropped. Your answers so far are saved.'));
      return;
    }
    _reconnects++;
    _events.add(LiveReconnecting());
    try {
      final lastQuestion = turns.lastWhere(
        (t) => t.speaker == Speaker.interviewer,
        orElse: () => const TranscriptTurn(speaker: Speaker.interviewer, text: '', startMs: 0, endMs: 0),
      );
      await _connect(
        recap: 'The connection dropped for a moment. Carry on naturally without greeting again. '
            '${signals.length} of ${config.questionCount} questions are answered. '
            '${lastQuestion.text.isEmpty ? '' : 'Your last words were: "${lastQuestion.text}".'}',
      );
    } catch (e) {
      _events.add(LiveFinished(completed: false, message: 'The connection dropped. Your answers so far are saved.'));
    }
  }

  /// Stops everything and hands back what was captured.
  Future<LiveCapture> end() async {
    _ending = true;
    _floorTimer?.cancel();
    final duration = nowMs;
    _clock.stop();
    await _micSub?.cancel();
    await _ampSub?.cancel();
    try {
      await _mic?.stop();
      await _mic?.dispose();
    } catch (_) {}
    await _msgSub?.cancel();
    await _session?.close();
    if (_playerReady) {
      try {
        await FlutterPcmSound.release();
      } catch (_) {}
    }
    final cleaned = [
      for (final t in turns) t.copyWith(text: t.text.trim().replaceAll(RegExp(r'\s+'), ' ')),
    ].where((t) => t.text.isNotEmpty).toList();
    final pauses = findLongPauses(_amplitude, candidateWindows(cleaned, duration));
    final wav = mixToWav(recorder.clips, minMs: duration);
    await _events.close();
    return LiveCapture(turns: cleaned, signals: signals, pauses: pauses, durationMs: duration, wav: wav);
  }

  String get modelName => _modelName;
}
