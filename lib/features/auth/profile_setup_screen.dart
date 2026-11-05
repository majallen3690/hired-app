import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion/motion.dart';
import '../../core/storage/app_prefs.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/fields.dart';
import '../../core/widgets/glass.dart';

const _suggested = ['Google', 'Microsoft', 'Razorpay', 'Zoho', 'Swiggy', 'Atlassian', 'Freshworks', 'Flipkart'];

/// Where the user is headed. It is only used to pre-fill the interview setup and greet them; skipping costs nothing.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, this.editing = false});

  /// Opened from Settings rather than straight after sign-up.
  final bool editing;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupState();
}

class _ProfileSetupState extends State<ProfileSetupScreen> {
  late final _role = TextEditingController(text: AppPrefs.targetRole);
  late final _branch = TextEditingController(text: AppPrefs.branch);
  final _company = TextEditingController();
  late int? _year = AppPrefs.gradYear;
  late final List<String> _companies = [...AppPrefs.dreamCompanies];

  @override
  void dispose() {
    _role.dispose();
    _branch.dispose();
    _company.dispose();
    super.dispose();
  }

  List<int> get _years {
    final y = DateTime.now().year;
    return [y, y + 1, y + 2, y + 3];
  }

  void _addCompany(String name) {
    final t = name.trim();
    if (t.isEmpty || _companies.any((c) => c.toLowerCase() == t.toLowerCase()) || _companies.length >= 8) return;
    Haptics.select();
    setState(() => _companies.add(t));
    _company.clear();
  }

  Future<void> _save() async {
    AppPrefs.targetRole = _role.text.trim();
    AppPrefs.branch = _branch.text.trim();
    AppPrefs.gradYear = _year;
    AppPrefs.dreamCompanies = _companies;
    AppPrefs.profileDone = true;
    await AppPrefs.save();
    Haptics.success();
    if (!mounted) return;
    widget.editing ? context.pop() : context.go('/home');
  }

  Future<void> _skip() async {
    AppPrefs.profileDone = true;
    await AppPrefs.save();
    if (mounted) widget.editing ? context.pop() : context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Scaffold(
      backgroundColor: c.ink,
      body: Aurora(
        child: SafeArea(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(HiredSpace.screen, HiredSpace.md, HiredSpace.screen, HiredSpace.xxl),
            children: [
              Row(children: [
                if (widget.editing) IconAction(icon: Icons.arrow_back_rounded, label: 'Back', onPressed: () => context.pop()),
                const Spacer(),
                TextAction(label: widget.editing ? 'Cancel' : 'Skip', onPressed: _skip),
              ]),
              const SizedBox(height: HiredSpace.md),
              Text.rich(TextSpan(style: HiredText.h1.copyWith(color: c.text), children: [
                const TextSpan(text: "Tell us where you're\n"),
                TextSpan(text: 'headed', style: HiredText.h1Em),
              ])),
              const SizedBox(height: HiredSpace.sm),
              Text('This pre-fills your mock interviews. You can change it any time.',
                  style: HiredText.body.copyWith(color: c.text2)),
              const SizedBox(height: HiredSpace.xl),
              HiredField(
                controller: _role,
                label: 'Target role',
                hint: 'Software Engineer',
                icon: Icons.work_outline_rounded,
                capitalize: TextCapitalization.words,
                action: TextInputAction.next,
              ),
              const SizedBox(height: HiredSpace.lg),
              HiredField(
                controller: _branch,
                label: 'Degree and branch',
                hint: 'B.Tech Computer Science',
                icon: Icons.school_outlined,
                capitalize: TextCapitalization.words,
                action: TextInputAction.done,
              ),
              const SizedBox(height: HiredSpace.xl),
              const SectionLabel('Graduating in'),
              const SizedBox(height: HiredSpace.sm),
              Wrap(spacing: HiredSpace.sm, runSpacing: HiredSpace.sm, children: [
                for (final y in _years)
                  HiredChip(label: '$y', selected: _year == y, onTap: () => setState(() => _year = _year == y ? null : y)),
              ]),
              const SizedBox(height: HiredSpace.xl),
              const SectionLabel('Dream companies'),
              const SizedBox(height: HiredSpace.sm),
              if (_companies.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: HiredSpace.md),
                  child: Wrap(spacing: HiredSpace.sm, runSpacing: HiredSpace.sm, children: [
                    for (final co in _companies)
                      HiredChip(
                        label: co,
                        selected: true,
                        icon: Icons.close_rounded,
                        onTap: () => setState(() => _companies.remove(co)),
                      ),
                  ]),
                ),
              Row(children: [
                Expanded(
                  child: HiredField(
                    controller: _company,
                    hint: 'Add a company',
                    capitalize: TextCapitalization.words,
                    action: TextInputAction.done,
                    onSubmitted: _addCompany,
                  ),
                ),
                const SizedBox(width: HiredSpace.sm),
                IconAction(icon: Icons.add_rounded, label: 'Add company', onPressed: () => _addCompany(_company.text)),
              ]),
              const SizedBox(height: HiredSpace.md),
              Text('Popular with students', style: HiredText.tiny.copyWith(color: c.text3)),
              const SizedBox(height: HiredSpace.sm),
              Wrap(spacing: HiredSpace.sm, runSpacing: HiredSpace.sm, children: [
                for (final co in _suggested.where((s) => !_companies.contains(s)))
                  HiredChip(label: co, onTap: () => _addCompany(co)),
              ]),
              const SizedBox(height: HiredSpace.xxl),
              PrimaryButton(label: widget.editing ? 'Save' : 'Continue', icon: Icons.arrow_forward_rounded, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
