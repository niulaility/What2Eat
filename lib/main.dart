import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/authentication/auth_page.dart';
import 'features/authentication/password_reset_page.dart';

final _appNavigatorKey = GlobalKey<NavigatorState>();
StreamSubscription<AuthState>? _authStateSubscription;
bool _openingPasswordRecovery = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://kkrmdpwwruhttzxeghty.supabase.co',
    ),
    anonKey: const String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: 'sb_publishable_bzL-uzqf6Iu6kPGnSqaHxA_06Fbbl4N',
    ),
  );

  _authStateSubscription?.cancel();
  _authStateSubscription =
      Supabase.instance.client.auth.onAuthStateChange.listen(
    (state) {
      if (state.event != AuthChangeEvent.passwordRecovery ||
          state.session == null ||
          _openingPasswordRecovery) {
        return;
      }

      _openingPasswordRecovery = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigator = _appNavigatorKey.currentState;
        if (navigator == null) {
          _openingPasswordRecovery = false;
          return;
        }
        navigator
            .push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const PasswordResetPage(),
              ),
            )
            .whenComplete(() => _openingPasswordRecovery = false);
      });
    },
    onError: (Object error, StackTrace stackTrace) {
      debugPrint('Supabase auth state stream failed: $error');
    },
  );

  runApp(const What2EatStarter());
}

class What2EatStarter extends StatelessWidget {
  const What2EatStarter({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        navigatorKey: _appNavigatorKey,
        title: 'What2Eat',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFFFFCF5),
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF344B35)),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        home: const AuthPage(),
      );
}
