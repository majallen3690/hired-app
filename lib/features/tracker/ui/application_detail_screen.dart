import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/notifications/reminder_service.dart';
import '../../interview/interview_prefill.dart';
import '../../resume/resume_flow.dart';
import '../data/application_store.dart';
import '../domain/application_models.dart';
import '../domain/reminder_rules.dart';
import '../domain/tracker_logic.dart';
import 'tracker_widgets.dart';
import '../../../core/motion/motion.dart';

/// Matches the resume screen's minimum, so the button is only offered when a match can run.
const _minJd = 40;

class ApplicationDetailScreen extends ConsumerStatefulWidget {
  const ApplicationDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<ApplicationDetailScreen> createState() => _State();
}

class _State extends ConsumerState<ApplicationDetailScreen> {
  late final ApplicationsNotifier _store = ref.read(applicationsProvider.notifier);
  TextEditingController? _company, _role, _notes, _jd;
  Timer? _debounce;

  @override
  void dispose() {
    // A pending edit is written now, so leaving the screen never loses what was just typed.
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      _flush();
    }
    _company?.dispose();
    _role?.dispose();
    _notes?.dispose();
    _jd?.dispose();
    super.dispose();
  }

  void _flush() {
    final company = _company, role = _role, notes = _notes, jd = _jd;
    if (company == null || role == null || notes == null || jd == null) return;
    _store.edit(
      widget.id,
      (a) => a.copyWith(
        company: company.text.trim().isEmpty ? a.company : company.text.trim(),
        role: role.text.trim(),
        notes: notes.text,
        jd: jd.text.trim(),
      ),
    );
  }

  void _edited() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _flush);
    setState(() {});
  }

  Future<void> _pickInterview(JobApplication a) async {
    final now = DateTime.now();
    final start = a.interviewAt?.toLocal() ?? now.add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: start.isBefore(now) ? now : start,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(start));
    if (time == null) return;
    final at = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    await _store.edit(a.id, (x) => x.copyWith(interviewAt: at));
  }

  Future<void> _confirmRemove(JobApplication a) async {
    final c = context.hc;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.ink2,
        title: Text('Remove ${a.company}?', style: HiredText.h2.copyWith(color: c.text)),
        content: Text('It leaves your tracker. This cannot be undone.', style: HiredText.body.copyWith(color: c.text2)),
        actions: [
          TextAction(label: 'Keep it', onPressed: () => Navigator.pop(ctx, false)),
          TextAction(label: 'Remove', onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (ok == true) {
      _debounce?.cancel();
      await _store.remove(a.id);
      if (mounted) context.go('/tracker');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final loaded = ref.watch(applicationsProvider).hasValue;
    final a = ref.watch(applicationProvider(widget.id));
    return Scaffold(
      backgroundColor: c.ink,
      body: Aurora(
        child: SafeArea(
          child: a == null
              ? Center(
                  child: loaded
                      ? Text('This application was not found.', style: HiredText.body.copyWith(color: c.text2))
                      : const DelayedSpinner(),
                )
              : _body(c, a),
        ),
      ),
    );
  }

  Widget _body(HiredPalette c, JobApplication a) {
    _company ??= TextEditingController(text: a.company);
    _role ??= TextEditingController(text: a.role);
    _notes ??= TextEditingController(text: a.notes);
    _jd ??= TextEditingController(text: a.jd);
    final now = DateTime.now();
    final hasJd = _jd!.text.trim().length >= _minJd;

    return RevealListView(
      padding: const EdgeInsets.fromLTRB(HiredSpace.screen, HiredSpace.sm, HiredSpace.screen, HiredSpace.xxl),
      children: [
        Row(children: [
          IconButton(icon: Icon(Icons.arrow_back_rounded, color: c.text2), tooltip: 'Back', onPressed: () => context.pop()),
          const Spacer(),
          IconButton(icon: Icon(Icons.delete_outline_rounded, color: c.text2), tooltip: 'Remove', onPressed: () => _confirmRemove(a)),
        ]),
        const SizedBox(height: HiredSpace.sm),
        Row(children: [
          CompanyTile(a.company, size: 52),
          const SizedBox(width: HiredSpace.lg),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.company, maxLines: 2, overflow: TextOverflow.ellipsis, style: HiredText.h1.copyWith(color: c.text)),
              Text(whenLabel(a, now), style: HiredText.small.copyWith(color: c.text3)),
            ]),
          ),
        ]),
        const SizedBox(height: HiredSpace.xl),
        const SectionLabel('Stage'),
        const SizedBox(height: HiredSpace.sm),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final s in Stage.values)
            HiredChip(label: s.label, selected: a.stage == s, onTap: () => _store.move(a.id, s)),
        ]),
        const SizedBox(height: HiredSpace.xl),
        const SectionLabel('Interview or test time'),
        const SizedBox(height: HiredSpace.sm),
        Glass(
          onTap: () => _pickInterview(a),
          padding: const EdgeInsets.fromLTRB(HiredSpace.lg, 6, 6, 6),
          child: Row(children: [
            Icon(Icons.event_rounded, color: a.interviewAt == null ? c.text2 : c.ember),
            const SizedBox(width: HiredSpace.md),
            Expanded(
              child: Text(
                a.interviewAt == null ? 'Set date and time' : dateTimeLabel(a.interviewAt!),
                style: HiredText.body.copyWith(color: a.interviewAt == null ? c.text2 : c.text, fontWeight: FontWeight.w500),
              ),
            ),
            if (a.interviewAt != null)
              IconButton(
                tooltip: 'Clear',
                icon: Icon(Icons.close_rounded, color: c.text2),
                onPressed: () => _store.edit(a.id, (x) => x.copyWith(clearInterviewAt: true)),
              ),
          ]),
        ),
        ..._reminders(c, a, now),
        const SizedBox(height: HiredSpace.xl),
        const SectionLabel('Next steps'),
        const SizedBox(height: HiredSpace.sm),
        PrimaryButton(
          label: 'Run resume match for this job',
          icon: Icons.description_rounded,
          onPressed: hasJd
              ? () {
                  _flush();
                  ref.read(resumeFlowProvider.notifier).setJd(_jd!.text.trim());
                  context.go('/resume');
                }
              : null,
        ),
        if (!hasJd) ...[
          const SizedBox(height: HiredSpace.xs),
          Text('Add the job description below to run a match.', style: HiredText.tiny.copyWith(color: c.text3)),
        ],
        const SizedBox(height: HiredSpace.sm),
        OutlineAction(
          label: 'Practise interview for ${a.company}',
          icon: Icons.mic_rounded,
          onPressed: () {
            _flush();
            ref.read(interviewPrefillProvider.notifier).set(role: _role!.text.trim(), company: _company!.text.trim());
            context.go('/interview');
          },
        ),
        const SizedBox(height: HiredSpace.xl),
        const SectionLabel('Details'),
        const SizedBox(height: HiredSpace.sm),
        _field(c, _company!, 'Company', Icons.apartment_rounded),
        const SizedBox(height: HiredSpace.md),
        _field(c, _role!, 'Role', Icons.work_outline_rounded),
        if (a.skills.isNotEmpty) ...[
          const SizedBox(height: HiredSpace.xl),
          const SectionLabel('Key skills'),
          const SizedBox(height: HiredSpace.sm),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final s in a.skills) HiredChip(label: s)]),
        ],
        const SizedBox(height: HiredSpace.xl),
        const SectionLabel('Notes'),
        const SizedBox(height: HiredSpace.sm),
        _field(c, _notes!, 'Referral, deadline, contact…', null, lines: 3),
        const SizedBox(height: HiredSpace.xl),
        const SectionLabel('Job description'),
        const SizedBox(height: HiredSpace.sm),
        _field(c, _jd!, 'Paste the job description', null, lines: 4, maxLines: 8),
      ],
    );
  }

  /// The reminders this application will send, so nothing arrives as a surprise.
  List<Widget> _reminders(HiredPalette c, JobApplication a, DateTime now) {
    final upcoming = buildReminders([a], now);
    if (upcoming.isEmpty) return const [];
    return [
      const SizedBox(height: HiredSpace.md),
      Glass(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.notifications_active_outlined, size: 18, color: c.warn),
            const SizedBox(width: HiredSpace.sm),
            Text('Reminders', style: HiredText.small.copyWith(color: c.warn, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: HiredSpace.sm),
          for (final r in upcoming)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(child: Text(r.kind.label, style: HiredText.body.copyWith(color: c.text))),
                Text(dateTimeLabel(r.at), style: HiredText.small.copyWith(color: c.text2)),
              ]),
            ),
          FutureBuilder<bool>(
            future: ReminderService.instance.allowed,
            builder: (context, snap) => snap.data == false
                ? Padding(
                    padding: const EdgeInsets.only(top: HiredSpace.sm),
                    child: Text('Notifications are off for Hired. Turn them on in Android settings to receive these.',
                        style: HiredText.tiny.copyWith(color: c.text3)),
                  )
                : const SizedBox.shrink(),
          ),
        ]),
      ),
    ];
  }

  Widget _field(HiredPalette c, TextEditingController ctl, String hint, IconData? icon, {int lines = 1, int? maxLines}) => TextField(
        controller: ctl,
        onChanged: (_) => _edited(),
        minLines: lines,
        maxLines: maxLines ?? (lines == 1 ? 1 : lines + 3),
        style: HiredText.body.copyWith(color: c.text),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: HiredText.body.copyWith(color: c.text3),
          prefixIcon: icon == null ? null : Icon(icon, color: c.text2),
          filled: true,
          fillColor: c.glassBottom,
          contentPadding: const EdgeInsets.symmetric(horizontal: HiredSpace.lg, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(HiredRadii.button), borderSide: BorderSide(color: c.hair)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(HiredRadii.button), borderSide: BorderSide(color: c.hair)),
          focusedBorder:
              OutlineInputBorder(borderRadius: BorderRadius.circular(HiredRadii.button), borderSide: BorderSide(color: c.ember, width: 1.5)),
        ),
      );
}
