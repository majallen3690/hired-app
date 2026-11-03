import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/scoring/readiness.dart';
import '../../core/storage/app_dir.dart';
import '../progress/data/progress_providers.dart';

/// The latest result per area. An area nobody has measured yet is null and shown as "–", never as a made-up number.
class MeasuredScores {
  const MeasuredScores({this.resume, this.interview, this.communication, this.presence});

  final int? resume;
  final int? interview;
  final int? communication;
  final int? presence;

  int? operator [](SubScore s) => switch (s) {
        SubScore.resume => resume,
        SubScore.interview => interview,
        SubScore.communication => communication,
        SubScore.presence => presence,
      };

  bool get isEmpty => SubScore.values.every((k) => this[k] == null);
  int get measuredCount => SubScore.values.where((k) => this[k] != null).length;

  /// Unmeasured areas count as zero, so readiness only rises as the user actually does the work.
  SubScores toScores() =>
      SubScores(resume: resume ?? 0, interview: interview ?? 0, communication: communication ?? 0, presence: presence ?? 0);

  MeasuredScores copyWith({int? resume, int? interview, int? communication, int? presence, bool clearPresence = false}) =>
      MeasuredScores(
        resume: resume ?? this.resume,
        interview: interview ?? this.interview,
        communication: communication ?? this.communication,
        presence: clearPresence ? null : (presence ?? this.presence),
      );

  Map<String, dynamic> toJson() =>
      {'resume': resume, 'interview': interview, 'communication': communication, 'presence': presence};

  factory MeasuredScores.fromJson(Map<String, dynamic> j) => MeasuredScores(
        resume: j['resume'] as int?,
        interview: j['interview'] as int?,
        communication: j['communication'] as int?,
        presence: j['presence'] as int?,
      );
}

/// Nothing is seeded: a new install honestly starts empty. Scores are kept on the device between launches.
class LatestScores extends Notifier<MeasuredScores> {
  @override
  MeasuredScores build() {
    _load();
    return const MeasuredScores();
  }

  Future<File> _file() async => File('${(await AppDir.root()).path}/scores.json');

  Future<void> _load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        state = MeasuredScores.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('Could not read saved scores: $e');
    }
  }

  Future<void> _save() async {
    try {
      await (await _file()).writeAsString(jsonEncode(state.toJson()), flush: true);
    } catch (e) {
      debugPrint('Could not save scores: $e');
    }
  }

  void setResume(int score) {
    state = state.copyWith(resume: score);
    _save();
    ref.read(resumeEventsProvider.notifier).add(score);
  }

  /// Communication is measured from the voice, so it is null when there was too little speech to judge.
  void setInterview(int interview, int? communication) {
    state = state.copyWith(interview: interview, communication: communication);
    _save();
  }

  /// A scored spoken intro measures speaking too, so the latest one sets the speaking score.
  void setCommunication(int score) {
    state = state.copyWith(communication: score);
    _save();
  }

  /// The latest saved presence check. Null clears it, for when the last saved photo is deleted.
  void setPresence(int? score) {
    state = score == null ? state.copyWith(clearPresence: true) : state.copyWith(presence: score);
    _save();
  }

  void clear() {
    state = const MeasuredScores();
    _save();
  }
}

final latestScoresProvider = NotifierProvider<LatestScores, MeasuredScores>(LatestScores.new);
