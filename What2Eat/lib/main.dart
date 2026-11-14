import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/authentication/auth_page.dart';

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

  runApp(const What2EatStarter());
}

class What2EatStarter extends StatelessWidget {
  const What2EatStarter({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
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
