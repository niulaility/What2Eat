import 'package:flutter/material.dart';

void main() => runApp(const What2EatStarter());

class What2EatStarter extends StatelessWidget {
  const What2EatStarter({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'What2Eat Starter',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('What2Eat Starter')),
        body: const Center(child: Text('Ready to build')),
      ),
    );
  }
}
