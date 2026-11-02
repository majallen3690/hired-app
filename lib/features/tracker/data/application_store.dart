import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/notifications/reminder_service.dart';
import '../domain/application_models.dart';
import '../domain/reminder_rules.dart';
import '../domain/tracker_logic.dart';

/// Every tracked application, kept on the device. The list is loading until the file has been read, so the screen
/// never flashes an empty state at someone who has applications.
class ApplicationsNotifier extends AsyncNotifier<List<JobApplication>> {
  @override
  Future<List<JobApplication>> build() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        final list = jsonDecode(await f.readAsString()) as List;
        return [for (final e in list) JobApplication.fromJson(e as Map<String, dynamic>)];
      }
    } catch (e) {
      debugPrint('Could not read applications: $e');
    }
    return const [];
  }

  Future<File> _file() async => File('${(await getApplicationDocumentsDirectory()).path}/applications.json');

  List<JobApplication> get _now => state.asData?.value ?? const [];

  Future<void> _set(List<JobApplication> next) async {
    state = AsyncData(next);
    // The first time a reminder exists is the moment to ask, with the reason in front of the user.
    if (buildReminders(next, DateTime.now()).isNotEmpty) ReminderService.instance.ensurePermission();
    try {
      await (await _file()).writeAsString(jsonEncode([for (final a in next) a.toJson()]), flush: true);
    } catch (e) {
      debugPrint('Could not save applications: $e');
    }
  }

  Future<JobApplication> add({
    required String company,
    required String role,
    required Stage stage,
    String jd = '',
    List<String> skills = const [],
  }) async {
    final now = DateTime.now();
    final a = JobApplication(
      id: 'app-${now.microsecondsSinceEpoch}',
      company: company.trim(),
      role: role.trim(),
      stage: stage,
      createdAt: now,
      stageChangedAt: now,
      jd: jd.trim(),
      skills: skills,
    );
    await _set([a, ..._now]);
    return a;
  }

  Future<void> edit(String id, JobApplication Function(JobApplication) change) =>
      _set([for (final a in _now) a.id == id ? change(a) : a]);

  Future<void> move(String id, Stage stage) {
    final now = DateTime.now();
    return edit(id, (a) => moveTo(a, stage, now));
  }

  Future<void> remove(String id) => _set(_now.where((a) => a.id != id).toList());
}

final applicationsProvider = AsyncNotifierProvider<ApplicationsNotifier, List<JobApplication>>(ApplicationsNotifier.new);

final applicationProvider = Provider.family<JobApplication?, String>(
  (ref, id) => (ref.watch(applicationsProvider).asData?.value ?? const []).where((a) => a.id == id).firstOrNull,
);

/// Keeps the scheduled notifications in step with the applications: any change rebuilds the whole set.
final reminderSyncProvider = Provider<void>((ref) {
  ref.listen(applicationsProvider, (_, next) {
    final apps = next.asData?.value;
    if (apps != null) ReminderService.instance.sync(buildReminders(apps, DateTime.now()));
  }, fireImmediately: true);
});
