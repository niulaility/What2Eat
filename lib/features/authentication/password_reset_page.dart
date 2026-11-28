import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_page.dart';
import 'registration_validators.dart';

const _passwordResetRedirect = String.fromEnvironment(
  'PASSWORD_RESET_REDIRECT_URL',
  defaultValue: 'what2eat://login-callback/',
);

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _sending = false;
  DateTime? _nextRequestAt;
  Timer? _cooldownTimer;
  int _secondsRemaining = 0;
  bool _requestSent = false;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (_sending || !_formKey.currentState!.validate()) return;
    if (_nextRequestAt != null && DateTime.now().isBefore(_nextRequestAt!)) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailController.text.trim().toLowerCase(),
        redirectTo: _passwordResetRedirect,
      );

      if (!mounted) return;
      setState(() => _requestSent = true);
      _startCooldown();
    } on AuthException catch (error) {
      debugPrint('Password reset request failed: ${error.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'We could not send a reset link right now. Please wait a moment and try again.',
            ),
          ),
        );
    } catch (error) {
      debugPrint('Password reset request failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'We could not send a reset link right now. Please try again later.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startCooldown() {
    _nextRequestAt = DateTime.now().add(const Duration(seconds: 60));
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      final remaining = _nextRequestAt!.difference(DateTime.now()).inSeconds;
      setState(() => _secondsRemaining = remaining.clamp(0, 60));
      if (remaining <= 0) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.lock_reset_rounded,
                        size: 56, color: Color(0xFF344B35)),
                    const SizedBox(height: 18),
                    Text(
                      _requestSent
                          ? 'Check your email'
                          : 'Forgot your password?',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF253729),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _requestSent
                          ? 'If an account uses this email, we sent a password reset link. Open it on this device to choose a new password.'
                          : 'Enter the email address on your What2Eat account. We will email you a secure link to choose a new password.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        height: 1.5,
                        color: Color(0xFF596451),
                      ),
                    ),
                    const SizedBox(height: 26),
                    TextFormField(
                      controller: _emailController,
                      enabled: !_sending,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: RegistrationValidators.email,
                      onFieldSubmitted: (_) => _sendResetLink(),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _sending || _secondsRemaining > 0
                          ? null
                          : _sendResetLink,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD85C),
                        foregroundColor: const Color(0xFF253729),
                        minimumSize: const Size.fromHeight(54),
                      ),
                      child: _sending
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _requestSent
                                  ? _secondsRemaining > 0
                                      ? 'Send again in $_secondsRemaining seconds'
                                      : 'Send another reset link'
                                  : 'Send reset link',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
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
      ),
    );
  }
}

class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({super.key});

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _saving = false;
  bool _passwordVisible = false;
  bool _confirmationVisible = false;
  bool _completed = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _saveNewPassword() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) {
      setState(() => _error =
          'This reset link is invalid or has expired. Request a new link and open it on this device.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      await client.auth.signOut();
      if (!mounted) return;
      setState(() => _completed = true);
    } on AuthException catch (error) {
      debugPrint('Password update failed: ${error.message}');
      if (!mounted) return;
      setState(() => _error =
          'We could not update your password. The reset link may have expired; request a new one and try again.');
    } catch (error) {
      debugPrint('Password update failed: $error');
      if (!mounted) return;
      setState(() => _error =
          'We could not update your password. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recoverySession =
        Supabase.instance.client.auth.currentSession != null;
    if (_completed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Password updated')),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 64, color: Color(0xFF344B35)),
                    const SizedBox(height: 18),
                    const Text(
                      'Password updated successfully',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF253729),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Sign in with your new password to continue.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF596451)),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () =>
                          Navigator.of(context).pushAndRemoveUntil<void>(
                        MaterialPageRoute<void>(
                            builder: (_) => const AuthPage()),
                        (route) => false,
                      ),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a new password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.password_rounded,
                        size: 54, color: Color(0xFF344B35)),
                    const SizedBox(height: 18),
                    const Text(
                      'Create a new password',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF253729),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      recoverySession
                          ? 'Choose a strong password you have not used before.'
                          : 'This reset link is invalid or has expired. Request a new reset link from the sign-in page.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        height: 1.5,
                        color: Color(0xFF596451),
                      ),
                    ),
                    if (recoverySession) ...[
                      const SizedBox(height: 26),
                      TextFormField(
                        controller: _passwordController,
                        enabled: !_saving,
                        obscureText: !_passwordVisible,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'New password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _passwordVisible
                                ? 'Hide password'
                                : 'Show password',
                            onPressed: () => setState(
                                () => _passwordVisible = !_passwordVisible),
                            icon: Icon(_passwordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                          ),
                        ),
                        validator: RegistrationValidators.password,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirmationController,
                        enabled: !_saving,
                        obscureText: !_confirmationVisible,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'Confirm new password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _confirmationVisible
                                ? 'Hide password'
                                : 'Show password',
                            onPressed: () => setState(() =>
                                _confirmationVisible = !_confirmationVisible),
                            icon: Icon(_confirmationVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                          ),
                        ),
                        validator: (value) =>
                            RegistrationValidators.confirmation(
                          value,
                          _passwordController.text,
                        ),
                        onFieldSubmitted: (_) => _saveNewPassword(),
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: _saving ? null : _saveNewPassword,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD85C),
                          foregroundColor: const Color(0xFF253729),
                          minimumSize: const Size.fromHeight(54),
                        ),
                        child: _saving
                            ? const SizedBox.square(
                                dimension: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save new password',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
