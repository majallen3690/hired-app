import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/ai/structured.dart';
import '../home/scores_provider.dart';
import 'data/resume_ai.dart';
import 'domain/match_models.dart';

enum FlowStage { idle, reading, comparing, writing, done, failed }

class ResumeFlow {
  const ResumeFlow({
    this.stage = FlowStage.idle,
    this.pdfName,
    this.pdf,
    this.jd = '',
    this.resume,
    this.match,
    this.error,
    this.targetRole,
  });

  final FlowStage stage;
  final String? pdfName;
  final Uint8List? pdf;
  final String jd;
  final Map<String, dynamic>? resume;
  final MatchResult? match;
  final String? error;

  /// The role from the last match, kept so a mock interview can start from it.
  final String? targetRole;

  bool get canRun => pdf != null && jd.trim().length >= 40;

  ResumeFlow copyWith({
    FlowStage? stage,
    String? pdfName,
    Uint8List? pdf,
    String? jd,
    Map<String, dynamic>? resume,
    MatchResult? match,
    String? error,
    String? targetRole,
    bool clearError = false,
  }) =>
      ResumeFlow(
        stage: stage ?? this.stage,
        pdfName: pdfName ?? this.pdfName,
        pdf: pdf ?? this.pdf,
        jd: jd ?? this.jd,
        resume: resume ?? this.resume,
        match: match ?? this.match,
        error: clearError ? null : (error ?? this.error),
        targetRole: targetRole ?? this.targetRole,
      );

  /// Every bullet in the parsed resume, for the tap-to-rewrite list.
  List<String> get bullets {
    final r = resume;
    if (r == null) return const [];
    final out = <String>[];
    for (final key in ['experience', 'projects']) {
      for (final item in (r[key] as List? ?? const [])) {
        out.addAll([for (final b in ((item as Map)['bullets'] as List? ?? const [])) b as String]);
      }
    }
    return out;
  }
}

class ResumeFlowNotifier extends Notifier<ResumeFlow> {
  final _ai = const ResumeAi();

  @override
  ResumeFlow build() {
    _loadSaved();
    return const ResumeFlow();
  }

  Future<File> _savedFile() async => File('${(await getApplicationDocumentsDirectory()).path}/resume.json');

  /// The parsed resume and role survive a restart, so the interview can start without redoing the match.
  Future<void> _loadSaved() async {
    try {
      final f = await _savedFile();
      if (!await f.exists()) return;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      if (state.resume == null) {
        state = state.copyWith(resume: j['resume'] as Map<String, dynamic>, targetRole: j['role'] as String?);
      }
    } catch (e) {
      debugPrint('Could not read the saved resume: $e');
    }
  }

  Future<void> _saveParsed(Map<String, dynamic> resume, String role) async {
    try {
      await (await _savedFile()).writeAsString(jsonEncode({'resume': resume, 'role': role}), flush: true);
    } catch (e) {
      debugPrint('Could not save the resume: $e');
    }
  }

  Future<void> pickPdf() async {
    final res = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
    final f = res?.files.single;
    if (f?.bytes == null) return;
    // A different file invalidates the previous parse.
    state = ResumeFlow(pdfName: f!.name, pdf: f.bytes, jd: state.jd);
  }

  void setJd(String v) => state = state.copyWith(jd: v);

  Future<void> run() async {
    if (!state.canRun) return;
    try {
      var resume = state.resume;
      if (resume == null) {
        state = state.copyWith(stage: FlowStage.reading, clearError: true);
        resume = await _ai.parse(state.pdf!);
        state = state.copyWith(resume: resume);
      }
      state = state.copyWith(stage: FlowStage.comparing);
      final matchFuture = _ai.match(resume, state.jd);
      // The third stage label is honest: the fixes come back inside the same response.
      final result = await matchFuture;
      state = state.copyWith(stage: FlowStage.writing);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      state = state.copyWith(stage: FlowStage.done, match: result, targetRole: result.role);
      ref.read(latestScoresProvider.notifier).setResume(result.overall);
      _saveParsed(resume, result.role);
    } on AiException catch (e) {
      state = state.copyWith(stage: FlowStage.failed, error: e.message);
    }
  }

  Future<List<Rewrite>> rewrite(String bullet) => _ai.rewrite(bullet, state.jd);

  void reset() => state = const ResumeFlow();
}

final resumeFlowProvider = NotifierProvider<ResumeFlowNotifier, ResumeFlow>(ResumeFlowNotifier.new);
