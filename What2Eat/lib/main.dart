import 'package:flutter/material.dart';

import 'features/authentication/auth_page.dart';

void main() => runApp(const What2EatStarter());

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
