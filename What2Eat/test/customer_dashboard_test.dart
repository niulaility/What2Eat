import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what2eat_starter/features/student/customer_dashboard_page.dart';
import 'package:what2eat_starter/features/student/data/customer_discovery_repository.dart';

void main() {
  testWidgets('Vendor meal badges match offered sessions and selected date', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerDashboardPage(
          name: 'Ali',
          repository: CustomerDiscoveryRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('What2Eat'), findsOneWidget);
    expect(find.text('Welcome back, Ali! 👋'), findsOneWidget);
    expect(find.byKey(const ValueKey('customer-navigation')), findsOneWidget);
    expect(find.byTooltip('Account options'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('vendor-sample-wok-station-session-lunch')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('vendor-sample-wok-station-session-dinner')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('vendor-sample-wok-station-session-breakfast')),
      findsNothing,
    );
    await tester.ensureVisible(find.textContaining('Tomorrow ('));
    await tester.tap(find.textContaining('Tomorrow ('));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('vendor-sample-wok-station-session-lunch')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('vendor-sample-wok-station-session-supper')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('vendor-sample-wok-station-session-dinner')),
      findsNothing,
    );
  });

  testWidgets(
    'Customer dashboard supports university filter, search, date grouping, and menu customization',
    (tester) async {
      final repo = CustomerDiscoveryRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: CustomerDashboardPage(name: 'Ali', repository: repo),
        ),
      );

      await tester.pumpAndSettle();

      // Default university is UTM, showing Mama Siti Kitchen, Wok & Bowl Express, The Green Bento Co.
      expect(find.text('Mama Siti Kitchen'), findsOneWidget);
      expect(find.text('Wok & Bowl Express'), findsOneWidget);

      // Search for a vendor by name
      await tester.enterText(find.byType(TextField), 'Mama Siti');
      await tester.pumpAndSettle();

      expect(find.text('Mama Siti Kitchen'), findsOneWidget);
      expect(find.text('Wok & Bowl Express'), findsNothing);

      // Clear search
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      // Select Today meal date -> filters vendors available on that date
      await tester.tap(find.textContaining('Today ('));
      await tester.pumpAndSettle();

      expect(find.text('Mama Siti Kitchen'), findsOneWidget);

      // Tap Mama Siti Kitchen -> opens vendor profile where meal sessions are shown vertically
      await tester.tap(find.text('Mama Siti Kitchen'));
      await tester.pumpAndSettle();

      expect(find.text('Choose Meal Session'), findsOneWidget);
      expect(find.text('Breakfast'), findsOneWidget);
      expect(find.text('Lunch'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Dinner'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Dinner'), findsOneWidget);

      // Tap Breakfast session -> opens dedicated menu page
      await tester.ensureVisible(find.text('Breakfast'));
      await tester.tap(find.text('Breakfast'));
      await tester.pumpAndSettle();

      expect(find.text('Breakfast Menu'), findsOneWidget);
      expect(find.text('Nasi Lemak Ayam Berempah'), findsOneWidget);

      // Select food card -> opens details & customization options
      final foodFinder = find.text('Nasi Lemak Ayam Berempah');
      await tester.ensureVisible(foodFinder);
      await tester.tap(foodFinder);
      await tester.pumpAndSettle();

      // Scroll inside the FoodItemDetailSheet to reveal customization groups
      await tester.drag(find.byType(ListView).last, const Offset(0, -250));
      await tester.pumpAndSettle();

      expect(find.text('Sambal Spice Level'), findsOneWidget);

      await tester.drag(find.byType(ListView).last, const Offset(0, -250));
      await tester.pumpAndSettle();

      expect(find.text('Add-ons & Extras'), findsOneWidget);

      // Base price is RM 9.50; add Sunny-Side Up Egg (+RM 1.50) -> RM 11.00
      await tester.drag(find.byType(ListView).last, const Offset(0, -150));
      await tester.pumpAndSettle();
      final eggFinder = find.text('Sunny-Side Up Egg');
      await tester.tap(eggFinder);
      await tester.pumpAndSettle();

      expect(find.text('Add • RM 11.00'), findsOneWidget);

      // Confirm selection
      await tester.tap(find.text('Add • RM 11.00'));
      await tester.pumpAndSettle();

      expect(find.text('View Customized Selections'), findsOneWidget);
    },
  );
}
