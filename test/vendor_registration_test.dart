import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what2eat_starter/features/authentication/vendor_registration_page.dart';

void main() {
  testWidgets(
    'Vendor form validates account data and preserves it across steps',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: VendorRegistrationPage()),
      );
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a username.'), findsOneWidget);
      expect(find.text('Account Information'), findsOneWidget);

      final inputs = find.byType(TextFormField);
      const values = [
        'Kitchen Owner',
        'kitchen_01',
        'owner@example.com',
        '0123456789',
        'Kitchen123!',
        'Kitchen123!',
      ];
      for (var i = 0; i < values.length; i++) {
        await tester.ensureVisible(inputs.at(i));
        await tester.enterText(inputs.at(i), values[i]);
      }
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Business Information'), findsOneWidget);
      expect(find.text('Business Logo'), findsOneWidget);
      final logoCard = find.byKey(const ValueKey('upload-logo'));
      expect(tester.widget<InkWell>(logoCard).onTap, isNotNull);
      final logoField = find.ancestor(
        of: logoCard,
        matching: find.byType(FormField<List<Uint8List>>),
      );
      final logoState = tester.state<FormFieldState<List<Uint8List>>>(
        logoField,
      );
      logoState.didChange([
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
        ),
      ]);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byTooltip('Review Business Logo photo 1'),
      );
      await tester.tap(find.byTooltip('Review Business Logo photo 1'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('1 / 1'), findsOneWidget);
      await tester.tap(find.byTooltip('Close preview'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove Business Logo photo 1'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Review Business Logo photo 1'), findsNothing);

      await tester.ensureVisible(find.text('Select universities'));
      await tester.tap(find.text('Select universities'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Universiti Teknologi Malaysia'));
      await tester.tap(find.text('Universiti Malaya'));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);

      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Please add Business Logo.'), findsOneWidget);
      expect(find.text('Business Information'), findsOneWidget);
      await tester.tap(find.byTooltip('Previous step'));
      await tester.pumpAndSettle();
      expect(find.text('Account Information'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(4))
            .controller!
            .text,
        'Kitchen123!',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
