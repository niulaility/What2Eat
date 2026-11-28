import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what2eat_starter/features/authentication/forgot_password_page.dart';

void main() {
  testWidgets('validates email and throttles successful reset requests', (
    tester,
  ) async {
    final emails = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ForgotPasswordPage(sendReset: (email) async => emails.add(email)),
      ),
    );
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(emails, isEmpty);
    await tester.enterText(
      find.byType(TextFormField),
      ' Customer@Example.com ',
    );
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(emails, ['customer@example.com']);
    expect(find.textContaining('If an account exists'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'connection failure allows retry without claiming email was sent',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ForgotPasswordPage(
            sendReset: (_) async => throw Exception('private backend detail'),
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField),
        'customer@example.com',
      );
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not connect.'), findsOneWidget);
      expect(find.textContaining('If an account exists'), findsNothing);
      expect(find.textContaining('private backend detail'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    },
  );
}
