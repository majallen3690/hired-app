import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ai/structured.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/glass.dart';
import '../data/application_store.dart';
import '../data/tracker_ai.dart';
import '../domain/application_models.dart';
import '../domain/tracker_logic.dart';

const _minJd = 40;

class AddApplicationScreen extends ConsumerStatefulWidget {
  const AddApplicationScreen({super.key, this.manual = false});

  /// Skips straight to the fields, for someone with no description to paste.
  final bool manual;

  @override
  ConsumerState<AddApplicationScreen> createState() => _State();
}

class _State extends ConsumerState<AddApplicationScreen> {
  final _jd = TextEditingController();
  final _company = TextEditingController();
  final _role = TextEditingController();
  final _skill = TextEditingController();
  final _skills = <String>[];
  var _stage = Stage.wishlist;
  var _filling = false;
  String? _fillNote;
  var _saving = false;

  @override
  void dispose() {
    _jd.dispose();
    _company.dispose();
    _role.dispose();
    _skill.dispose();
    super.dispose();
  }

  Future<void> _fill() async {
    setState(() {
      _filling = true;
      _fillNote = null;
    });
    String? note;
    try {
      final r = await const TrackerAi().autofill(_jd.text);
      if (!mounted) return;
      if (r.company.isNotEmpty) _company.text = r.company;
      if (r.role.isNotEmpty) _role.text = r.role;
      setState(() {
        _skills
          ..clear()
          ..addAll(r.skills);
      });
      final missing = [if (r.company.isEmpty) 'company', if (r.role.isEmpty) 'job title'];
      if (missing.isNotEmpty) note = 'The text does not say the ${missing.join(' or ')}. Add it below.';
    } on AiException catch (e) {
      note = e.message;
    }
    if (mounted) {
      setState(() {
        _filling = false;
        _fillNote = note;
      });
    }
  }

  void _addSkill(String s) {
    final t = s.trim();
    if (t.isEmpty || _skills.any((k) => k.toLowerCase() == t.toLowerCase()) || _skills.length >= maxSkills) return;
    setState(() => _skills.add(t));
    _skill.clear();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(applicationsProvider.notifier).add(
          company: _company.text,
          role: _role.text,
          stage: _stage,
          jd: _jd.text,
          skills: List.of(_skills),
        );
    if (mounted) context.go('/tracker');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final apps = ref.watch(applicationsProvider).asData?.value ?? const [];
    return Scaffold(
      backgroundColor: c.ink,
      resizeToAvoidBottomInset: true,
      body: Aurora(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(HiredSpace.screen, HiredSpace.sm, HiredSpace.screen, HiredSpace.xxl),
            children: [
              Row(children: [
                IconButton(icon: Icon(Icons.close_rounded, color: c.text2), tooltip: 'Close', onPressed: () => context.pop()),
                Expanded(child: Center(child: Text('Add application', style: HiredText.body.copyWith(color: c.text, fontWeight: FontWeight.w600)))),
                const SizedBox(width: 48),
              ]),
              const SizedBox(height: HiredSpace.md),
              if (!widget.manual) ...[
                const SectionLabel('Job description'),
                const SizedBox(height: HiredSpace.sm),
                TextField(
                  controller: _jd,
                  minLines: 5,
                  maxLines: 9,
                  style: HiredText.body.copyWith(color: c.text),
                  onChanged: (_) => setState(() {}),
                  decoration: _decoration(c, 'Paste the job description, then fill it in'),
                ),
                const SizedBox(height: HiredSpace.md),
                OutlineAction(
                  label: _filling ? 'Reading it…' : 'Fill it in',
                  icon: Icons.auto_awesome_rounded,
                  onPressed: _filling || _jd.text.trim().length < _minJd ? null : _fill,
                ),
                if (_fillNote != null) ...[
                  const SizedBox(height: HiredSpace.sm),
                  Text(_fillNote!, style: HiredText.small.copyWith(color: c.warn)),
                ],
                const SizedBox(height: HiredSpace.xl),
              ],
              const SectionLabel('Company'),
              const SizedBox(height: HiredSpace.sm),
              TextField(
                controller: _company,
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.words,
                style: HiredText.body.copyWith(color: c.text),
                decoration: _decoration(c, 'For example Razorpay', icon: Icons.apartment_rounded),
              ),
              const SizedBox(height: HiredSpace.md),
              const SectionLabel('Role'),
              const SizedBox(height: HiredSpace.sm),
              TextField(
                controller: _role,
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.words,
                style: HiredText.body.copyWith(color: c.text),
                decoration: _decoration(c, 'For example SDE-1, Payments', icon: Icons.work_outline_rounded),
              ),
              const SizedBox(height: HiredSpace.xl),
              const SectionLabel('Stage'),
              const SizedBox(height: HiredSpace.sm),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final s in Stage.values) HiredChip(label: s.label, selected: _stage == s, onTap: () => setState(() => _stage = s)),
              ]),
              const SizedBox(height: HiredSpace.xl),
              const SectionLabel('Key skills'),
              const SizedBox(height: HiredSpace.sm),
              if (_skills.isNotEmpty)
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final s in _skills) HiredChip(label: '$s  ✕', onTap: () => setState(() => _skills.remove(s))),
                ]),
              if (_skills.isNotEmpty) const SizedBox(height: HiredSpace.sm),
              TextField(
                controller: _skill,
                onSubmitted: _addSkill,
                textInputAction: TextInputAction.done,
                style: HiredText.body.copyWith(color: c.text),
                decoration: _decoration(c, 'Add a skill and press done', icon: Icons.add_rounded),
              ),
              const SizedBox(height: HiredSpace.xxl),
              Builder(builder: (context) {
                final dup = _company.text.trim().isNotEmpty && isDuplicate(apps, _company.text, _role.text);
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (dup) ...[
                    Glass(
                      child: Row(children: [
                        Icon(Icons.info_outline_rounded, color: c.warn, size: 20),
                        const SizedBox(width: HiredSpace.md),
                        Expanded(child: Text('You already track this role at ${_company.text.trim()}.', style: HiredText.body.copyWith(color: c.text))),
                      ]),
                    ),
                    const SizedBox(height: HiredSpace.md),
                  ],
                  PrimaryButton(
                    label: 'Save',
                    icon: Icons.check_rounded,
                    onPressed: _company.text.trim().isEmpty || dup || _saving ? null : _save,
                  ),
                ]);
              }),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(HiredPalette c, String hint, {IconData? icon}) => InputDecoration(
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
      );
}
