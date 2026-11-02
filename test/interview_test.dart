import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hired/features/interview/audio/pcm_mixer.dart';
import 'package:hired/features/interview/data/interview_ai.dart';
import 'package:hired/features/interview/domain/evaluation_models.dart';
import 'package:hired/features/interview/domain/interview_models.dart';
import 'package:hired/features/interview/domain/speech_metrics.dart';

TranscriptTurn said(String text, {int start = 0, int end = 10000, Speaker who = Speaker.candidate}) =>
    TranscriptTurn(speaker: who, text: text, startMs: start, endMs: end);

Dimension dim(int score, [String? ev]) => Dimension(score: score, evidence: ev);

QuestionEval q(Dimension d, {String question = 'Tell me about your project'}) => QuestionEval(
      question: question,
      structure: d,
      relevance: d,
      depth: d,
      clarity: d,
      situation: true,
      task: true,
      action: true,
      result: false,
      good: 'g',
      fix: 'f',
      modelAnswer: 'm',
    );

void main() {
  group('fillers', () {
    test('finds fillers case-insensitively and whole words only', () {
      final hits = findFillers('Um, so basically I built it. Actually the umbrella app was fine, you know');
      expect(hits.map((h) => h.word), ['um', 'basically', 'actually', 'you know']);
    });

    test('longest phrase wins so "you know" is one filler', () {
      expect(findFillers('you know what').length, 1);
    });

    test('hinglish fillers are caught', () {
      expect(findFillers('matlab yaani we cached it').map((h) => h.word), ['matlab', 'yaani']);
    });

    test('counts words', () {
      expect(wordCount('  one two   three '), 3);
      expect(wordCount(''), 0);
    });
  });

  group('pace and communication score', () {
    test('pace needs enough speech to mean anything', () {
      expect(paceWpm(5, 20000), isNull);
      expect(paceWpm(40, 2000), isNull);
      expect(paceWpm(60, 30000), 120);
    });

    test('summary uses only the candidate\'s turns', () {
      final turns = [
        said('What did you build and why did you choose that stack for it', who: Speaker.interviewer),
        said('Um I built an attendance app with Flutter and basically Firebase for the backend sync', end: 30000),
      ];
      final s = summariseSpeech(turns);
      expect(s.words, 15);
      expect(s.fillerCount, 2);
      expect(s.topFillers.keys, containsAll(['um', 'basically']));
    });

    test('typed answers are left out of pace and filler measurements', () {
      final typed = TranscriptTurn(
          speaker: Speaker.candidate, text: 'um basically typed answer here', startMs: 0, endMs: 1000, typed: true);
      final s = summariseSpeech([typed]);
      expect(s.words, 0);
      expect(s.fillerCount, 0);
      expect(TranscriptTurn.fromJson(typed.toJson()).typed, isTrue);
    });

    test('too little speech gives no score instead of a made-up one', () {
      expect(communicationScore(summariseSpeech([said('Hello there')])), isNull);
    });

    test('steady pace with no fillers scores 100', () {
      final text = List.filled(40, 'word').join(' ');
      final s = summariseSpeech([said(text, end: 18000)]); // 40 words in 18s = 133 wpm
      expect(communicationScore(s), 100);
    });

    test('a fast, filler-heavy answer with long pauses scores lower', () {
      final text = '${List.filled(30, 'um').join(' ')} ${List.filled(60, 'word').join(' ')}';
      final s = summariseSpeech([said(text, end: 20000)], pauses: const [Pause(startMs: 0, endMs: 5000)]);
      expect(communicationScore(s)!, lessThan(60));
    });
  });

  group('pauses', () {
    List<AmplitudeSample> quiet(int from, int to) =>
        [for (var ms = from; ms <= to; ms += 100) AmplitudeSample(ms, -60)];
    List<AmplitudeSample> loud(int from, int to) =>
        [for (var ms = from; ms <= to; ms += 100) AmplitudeSample(ms, -20)];

    test('a long silence inside the candidate window is a pause', () {
      final samples = [...loud(0, 1000), ...quiet(1100, 7000), ...loud(7100, 9000)];
      final p = findLongPauses(samples, [(startMs: 0, endMs: 9000)]);
      expect(p.single.lengthMs, greaterThanOrEqualTo(4000));
    });

    test('a short think is not a pause', () {
      final samples = [...loud(0, 1000), ...quiet(1100, 3000), ...loud(3100, 9000)];
      expect(findLongPauses(samples, [(startMs: 0, endMs: 9000)]), isEmpty);
    });

    test('silence while the interviewer talks is ignored', () {
      final samples = quiet(0, 8000);
      expect(findLongPauses(samples, [(startMs: 20000, endMs: 30000)]), isEmpty);
    });

    test('a window where the candidate only typed is not a place to find pauses', () {
      final turns = [
        said('Q1', start: 0, end: 4000, who: Speaker.interviewer),
        TranscriptTurn(speaker: Speaker.candidate, text: 'typed', startMs: 9000, endMs: 9000, typed: true),
        said('Q2', start: 21000, end: 25000, who: Speaker.interviewer),
        said('spoken', start: 26000, end: 30000),
      ];
      final w = candidateWindows(turns, 60000);
      expect(w.length, 1);
      expect(w.single.startMs, 25000);
    });

    test('candidate windows run from one interviewer turn to the next', () {
      final turns = [
        said('Q1', start: 0, end: 4000, who: Speaker.interviewer),
        said('A1', start: 4500, end: 20000),
        said('Q2', start: 21000, end: 25000, who: Speaker.interviewer),
        said('A2', start: 26000, end: 40000),
      ];
      final w = candidateWindows(turns, 60000);
      expect(w.first, (startMs: 4000, endMs: 21000));
      expect(w.last, (startMs: 25000, endMs: 60000));
    });
  });

  group('markers', () {
    test('questions, fillers and pauses land on the timeline in order', () {
      final turns = [
        said('Tell me about your project', start: 0, end: 4000, who: Speaker.interviewer),
        said('Um it was an app', start: 5000, end: 9000),
      ];
      final m = buildMarkers(turns, const [Pause(startMs: 12000, endMs: 17000)]);
      expect(m.map((e) => e.kind), [MarkerKind.question, MarkerKind.filler, MarkerKind.pause]);
      expect(m[1].atMs, inInclusiveRange(5000, 6000));
      expect(m.first.label, 'Q1');
      expect(m.last.evidence, contains('microphone'));
    });
  });

  group('evaluation', () {
    test('interview score is the mean rating scaled to 100', () {
      final e = InterviewEvaluation(headline: 'h', questions: [q(dim(4)), q(dim(2))], topFixes: const []);
      expect(e.interviewScore, 60);
    });

    test('empty evaluation scores zero', () {
      expect(const InterviewEvaluation(headline: '', questions: [], topFixes: []).interviewScore, 0);
    });

    test('a quote that is really in the answer keeps its rating', () {
      final e = InterviewEvaluation(
        headline: 'h',
        topFixes: const [],
        questions: [q(dim(5, 'we cached each check-in locally first'))],
      ).withVerifiedEvidence('So we cached each check-in locally first and synced it later');
      expect(e.questions.single.clarity.score, 5);
      expect(e.questions.single.clarity.evidence, isNotNull);
    });

    test('an invented quote is dropped and the rating is capped at 3', () {
      final e = InterviewEvaluation(
        headline: 'h',
        topFixes: const [],
        questions: [q(dim(5, 'I scaled it to a million users with Kafka'))],
      ).withVerifiedEvidence('So we cached each check-in locally first and synced it later');
      expect(e.questions.single.depth.score, 3);
      expect(e.questions.single.depth.evidence, isNull);
    });

    test('a low rating is not raised when its quote is missing', () {
      final e = InterviewEvaluation(headline: 'h', topFixes: const [], questions: [q(dim(2, 'nonsense words here'))])
          .withVerifiedEvidence('something else entirely');
      expect(e.questions.single.depth.score, 2);
    });
  });

  group('interviewer persona', () {
    const resume = {
      'name': 'Ishita Rao',
      'skills': ['Java', 'Flutter'],
      'education': ['PES University'],
      'certifications': ['NPTEL DSA'],
      'projects': [
        {'name': 'Campus Attendance App', 'tech': ['Flutter', 'Firebase'], 'bullets': ['Built QR check-in']},
      ],
      'experience': [
        {'company': 'Brightlabs', 'role': 'Software Intern', 'bullets': ['Wrote SQL queries']},
      ],
    };

    test('the digest carries the facts an interviewer would ask about', () {
      final d = resumeDigest(resume);
      expect(d, contains('Campus Attendance App'));
      expect(d, contains('Built QR check-in'));
      expect(d, contains('Software Intern at Brightlabs'));
      expect(d, contains('NPTEL DSA'));
    });

    test('the persona names the role, company, round and question count', () {
      final p = buildPersona(
        const InterviewConfig(role: 'SDE-1', company: 'Razorpay', round: InterviewRound.hr),
        resume,
      );
      expect(p, contains('"SDE-1" at Razorpay'));
      expect(p, contains('HR round'));
      expect(p, contains('exactly 5 main questions'));
      expect(p, contains('Campus Attendance App'));
      expect(p, contains('logAnswerSignal'));
      expect(p, contains('endInterview'));
    });

    test('hinglish switches the language instruction', () {
      final p = buildPersona(const InterviewConfig(role: 'SDE-1', language: InterviewLang.hinglish), resume);
      expect(p, contains('Hinglish'));
      expect(buildPersona(const InterviewConfig(role: 'SDE-1'), resume), isNot(contains('Hinglish')));
    });

    test('a transcript is rendered with clock times and speaker labels', () {
      final t = transcriptText([
        said('Tell me about it', start: 5000, who: Speaker.interviewer),
        said('Sure', start: 65000),
      ]);
      expect(t, '[00:05] Interviewer: Tell me about it\n[01:05] Candidate: Sure');
    });
  });

  group('session record', () {
    test('survives a JSON round trip', () {
      final r = SessionRecord(
        id: 's1',
        startedAt: DateTime.utc(2026, 11, 2, 13),
        durationMs: 600000,
        config: const InterviewConfig(role: 'SDE-1', company: 'Razorpay', language: InterviewLang.hinglish),
        mode: SessionMode.live,
        turns: [said('hi', start: 0, end: 1000, who: Speaker.interviewer)],
        signals: const [AnswerSignal(atMs: 5000, quality: 4, note: 'clear')],
        pauses: const [Pause(startMs: 1, endMs: 2)],
        evaluation: InterviewEvaluation(headline: 'h', questions: [q(dim(4, 'x'))], topFixes: const ['a']),
        audioFile: 's1.wav',
        communication: 77,
      );
      final back = SessionRecord.fromJson(r.toJson());
      expect(back.config.title, 'SDE-1 at Razorpay');
      expect(back.config.language, InterviewLang.hinglish);
      expect(back.evaluation!.interviewScore, 80);
      expect(back.communication, 77);
      expect(back.signals.single.quality, 4);
      expect(back.turns.single.speaker, Speaker.interviewer);
    });
  });

  group('audio mixing', () {
    Uint8List bytesOf(List<int> samples) => Int16List.fromList(samples).buffer.asUint8List();

    test('wav header describes 16-bit mono PCM', () {
      final wav = wavBytes(Int16List.fromList([1, 2, 3, 4]), 24000);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      final b = ByteData.sublistView(wav);
      expect(b.getUint16(22, Endian.little), 1);
      expect(b.getUint32(24, Endian.little), 24000);
      expect(b.getUint32(40, Endian.little), 8);
      expect(wav.length, 44 + 8);
    });

    test('model chunks queue one after another even when they arrive together', () {
      final rec = SessionAudioRecorder();
      final oneSecond = Int16List(modelRate).buffer.asUint8List();
      expect(rec.addModel(0, oneSecond), 0);
      expect(rec.addModel(100, oneSecond), 1000);
      expect(rec.modelCursorMs, 2000);
    });

    test('an interruption trims audio that was queued but never played', () {
      final rec = SessionAudioRecorder();
      final oneSecond = Int16List(modelRate).buffer.asUint8List();
      rec.addModel(0, oneSecond);
      rec.addModel(0, oneSecond);
      rec.interrupt(1500);
      expect(rec.modelCursorMs, 1500);
      expect(rec.clips.last.endMs, lessThanOrEqualTo(1500));
    });

    test('overlapping clips are summed and clamped', () {
      final a = PcmClip(startMs: 0, samples: Int16List.fromList([30000, 30000]), sampleRate: 24000);
      final b = PcmClip(startMs: 0, samples: Int16List.fromList([30000, -100]), sampleRate: 24000);
      final wav = mixToWav([a, b]);
      final data = ByteData.sublistView(wav, 44);
      expect(data.getInt16(0, Endian.little), 32767);
      expect(data.getInt16(2, Endian.little), 29900);
    });

    test('16 kHz mic audio is resampled onto the 24 kHz timeline', () {
      final mic = PcmClip(startMs: 0, samples: Int16List(16000), sampleRate: micRate);
      final wav = mixToWav([mic]);
      final dataBytes = ByteData.sublistView(wav).getUint32(40, Endian.little);
      expect(dataBytes ~/ 2, closeTo(24000, 2));
    });

    test('the mix is at least as long as the session', () {
      final wav = mixToWav(const [], minMs: 2000);
      expect(ByteData.sublistView(wav).getUint32(40, Endian.little) ~/ 2, greaterThanOrEqualTo(48000));
    });

    test('odd byte counts from the socket do not crash', () {
      expect(pcmFromBytes(Uint8List.fromList([1, 0, 2])).length, 1);
    });

    test('recorded candidate audio lands at its start time', () {
      final rec = SessionAudioRecorder()..addCandidate(500, bytesOf([100, 100, 100, 100]));
      expect(rec.clips.single.startMs, 500);
    });
  });
}
