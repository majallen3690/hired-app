import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/fields.dart';
import '../../core/widgets/glass.dart';
import 'auth_service.dart';

enum _Mode { signIn, signUp }

/// Sign in, create an account, or carry on as a guest. A guest loses nothing: the data lives on the phone either way.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, this.gateway});

  /// Tests pass a fake; the app uses the real one.
  final AuthGateway? gateway;

  @override
  State<SignInScreen> createState() => _SignInState();
}

class _SignInState extends State<SignInScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _mode = _Mode.signIn;
  var _busy = false;
  var _show = false;
  String? _emailError, _passwordError, _formError, _info;

  AuthGateway get _gateway => widget.gateway ?? session.gateway;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _setMode(_Mode m) {
    setState(() {
      _mode = m;
      _emailError = _passwordError = _formError = _info = null;
    });
  }

  bool _validate() {
    final e = validateEmail(_email.text);
    final p = validatePassword(_password.text);
    setState(() {
      _emailError = e;
      _passwordError = p;
      _formError = null;
      _info = null;
    });
    if (e != null || p != null) Haptics.error();
    return e == null && p == null;
  }

  Future<void> _submit() async {
    if (_busy || !_validate()) return;
    setState(() => _busy = true);
    try {
      final signingUp = _mode == _Mode.signUp;
      final user = signingUp
          ? await _gateway.signUp(_email.text, _password.text, _name.text)
          : await _gateway.signIn(_email.text, _password.text);
      await session.signedInAs(user);
      Haptics.success();
      if (mounted) context.go(signingUp ? '/profile-setup' : '/home');
    } on AuthException catch (e) {
      Haptics.error();
      if (mounted) setState(() => _formError = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final e = validateEmail(_email.text);
    if (e != null) {
      setState(() {
        _emailError = 'Enter your email above first.';
        _info = null;
      });
      Haptics.error();
      return;
    }
    setState(() => _busy = true);
    try {
      await _gateway.sendPasswordReset(_email.text);
      if (mounted) setState(() => _info = 'If an account exists for that email, a reset link is on its way.');
    } on AuthException catch (err) {
      if (mounted) setState(() => _formError = err.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _guest() async {
    await session.continueAsGuest();
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final signingUp = _mode == _Mode.signUp;
    return Scaffold(
      backgroundColor: c.ink,
      body: Aurora(
        child: SafeArea(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(HiredSpace.screen, HiredSpace.xxl, HiredSpace.screen, HiredSpace.xxl),
            children: [
              Text.rich(TextSpan(style: HiredText.label.copyWith(color: c.text2, fontSize: 22), children: [
                const TextSpan(text: 'hired'),
                TextSpan(text: '.', style: TextStyle(color: c.ember)),
              ])),
              const SizedBox(height: HiredSpace.xxl),
              Text.rich(TextSpan(style: HiredText.h1.copyWith(color: c.text), children: [
                TextSpan(text: signingUp ? 'Create your\n' : "Let's get you\n"),
                TextSpan(text: signingUp ? 'account.' : 'hired.', style: HiredText.h1Em),
              ])),
              const SizedBox(height: HiredSpace.sm),
              Text(
                signingUp
                    ? 'Free, and your practice stays on your phone.'
                    : 'Sign in to pick up where you left off.',
                style: HiredText.body.copyWith(color: c.text2),
              ),
              const SizedBox(height: HiredSpace.xl),
              Segmented<_Mode>(
                options: const {_Mode.signIn: 'Sign in', _Mode.signUp: 'Create account'},
                value: _mode,
                onChanged: _busy ? (_) {} : _setMode,
              ),
              const SizedBox(height: HiredSpace.xl),
              AnimatedSize(
                duration: HiredMotion.quick,
                curve: HiredMotion.easeOut,
                alignment: Alignment.topCenter,
                child: signingUp
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: HiredSpace.lg),
                        child: HiredField(
                          controller: _name,
                          label: 'Your name',
                          hint: 'Ishita Rao',
                          icon: Icons.person_outline_rounded,
                          capitalize: TextCapitalization.words,
                          action: TextInputAction.next,
                          autofill: const [AutofillHints.name],
                          enabled: !_busy,
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              HiredField(
                controller: _email,
                label: 'Email',
                hint: 'you@college.edu',
                icon: Icons.mail_outline_rounded,
                keyboard: TextInputType.emailAddress,
                action: TextInputAction.next,
                autofill: const [AutofillHints.email],
                error: _emailError,
                enabled: !_busy,
                onChanged: (_) {
                  if (_emailError != null) setState(() => _emailError = null);
                },
              ),
              const SizedBox(height: HiredSpace.lg),
              HiredField(
                controller: _password,
                label: 'Password',
                hint: signingUp ? 'At least 6 characters' : 'Your password',
                icon: Icons.lock_outline_rounded,
                obscure: !_show,
                action: TextInputAction.done,
                autofill: [signingUp ? AutofillHints.newPassword : AutofillHints.password],
                error: _passwordError,
                enabled: !_busy,
                onSubmitted: (_) => _submit(),
                onChanged: (_) {
                  if (_passwordError != null) setState(() => _passwordError = null);
                },
                suffix: IconButton(
                  tooltip: _show ? 'Hide password' : 'Show password',
                  icon: Icon(_show ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: c.text3, size: 20),
                  onPressed: () => setState(() => _show = !_show),
                ),
              ),
              if (!signingUp)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextAction(label: 'Forgot password?', onPressed: _busy ? null : _forgot),
                ),
              if (_formError != null) ...[
                const SizedBox(height: HiredSpace.md),
                _Banner(text: _formError!, color: c.bad, icon: Icons.error_outline_rounded),
              ],
              if (_info != null) ...[
                const SizedBox(height: HiredSpace.md),
                _Banner(text: _info!, color: c.ok, icon: Icons.mark_email_read_rounded),
              ],
              const SizedBox(height: HiredSpace.xl),
              _busy
                  ? SizedBox(
                      height: 52,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2.2, color: c.ember)),
                    )
                  : PrimaryButton(
                      label: signingUp ? 'Create account' : 'Sign in',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: _submit,
                    ),
              const SizedBox(height: HiredSpace.md),
              Row(children: [
                Expanded(child: Divider(color: c.hair)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: HiredSpace.md),
                  child: Text('or', style: HiredText.small.copyWith(color: c.text3)),
                ),
                Expanded(child: Divider(color: c.hair)),
              ]),
              const SizedBox(height: HiredSpace.md),
              OutlineAction(label: 'Continue as guest', icon: Icons.person_outline_rounded, onPressed: _busy ? null : _guest),
              const SizedBox(height: HiredSpace.lg),
              Text(
                'A guest can use everything. Create an account any time from Settings.',
                textAlign: TextAlign.center,
                style: HiredText.tiny.copyWith(color: c.text3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color, required this.icon});
  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(HiredSpace.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(HiredRadii.button),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: HiredSpace.sm),
          Expanded(child: Text(text, style: HiredText.small.copyWith(color: context.hc.text))),
        ]),
      );
}
