import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'registration_validators.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.sendReset});

  final Future<void> Function(String email)? sendReset;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  Timer? _timer;
  bool _busy = false;
  bool _sent = false;
  int _cooldown = 0;
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _cooldown > 0 || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final email = _email.text.trim().toLowerCase();
      if (widget.sendReset != null) {
        await widget.sendReset!(email);
      } else {
        const resetUrl = String.fromEnvironment(
          'PASSWORD_RESET_URL',
          defaultValue: 'https://what2eat-password-reset.vercel.app/',
        );
        final destination = Uri.tryParse(resetUrl);
        if (destination == null ||
            destination.scheme != 'https' ||
            destination.host.isEmpty ||
            destination.userInfo.isNotEmpty ||
            destination.hasQuery ||
            destination.hasFragment) {
          // Never silently fall back to Supabase's localhost Site URL.
          throw const AuthException(
            'Password reset is temporarily unavailable.',
          );
        }
        // The recovery email template owns the destination. Its token hash
        // works in any browser without the app's PKCE verifier or session.
        await Supabase.instance.client.auth.resetPasswordForEmail(
          email,
          redirectTo: resetUrl,
        );
      }
      if (!mounted) return;
      setState(() {
        _sent = true;
        _cooldown = 60;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return timer.cancel();
        setState(() => _cooldown--);
        if (_cooldown == 0) timer.cancel();
      });
    } on AuthException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.statusCode == '429'
              ? 'Too many requests. Please wait a few minutes and try again.'
              : 'Could not request a reset email. Please try again later.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not connect. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reset password')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.mark_email_read_outlined, size: 56),
                const SizedBox(height: 24),
                Text(
                  'Forgot your password?',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Enter your account email. Open the link in your email to choose a new password securely in your browser.',
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _email,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  validator: RegistrationValidators.email,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy || _cooldown > 0 ? null : _submit,
                  child: Text(
                    _busy
                        ? 'Sending…'
                        : _cooldown > 0
                        ? 'Resend in ${_cooldown}s'
                        : 'Send reset link',
                  ),
                ),
                if (_sent) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'If an account exists for this email, you will receive a password reset link. Check your inbox and spam folder. Use the latest email; the link expires and can only be used once.',
                    semanticsLabel:
                        'Reset requested. Check your inbox and spam folder.',
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
