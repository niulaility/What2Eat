import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what2eat_starter/features/student/customer_dashboard_page.dart';
import 'package:what2eat_starter/features/student/data/customer_discovery_repository.dart';
import 'package:what2eat_starter/features/student/models/customer_discovery_models.dart';

class _UniversityFixture extends CustomerDiscoveryRepository {
  @override
  Future<CustomerDiscoveryData> loadDiscoveryData() async {
    final data = await super.loadDiscoveryData();
    return CustomerDiscoveryData(
      universities: [
        ...data.universities,
        const UniversityOption(
          id: 'other',
          code: 'other',
          name: 'Other / not listed',
        ),
      ],
      vendors: data.vendors,
      defaultUniversityId: data.defaultUniversityId,
      menuSessions: data.menuSessions,
    );
  }
}

void main() {
  testWidgets('Only vendors serving the selected university are listed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerDashboardPage(
          name: 'Ali',
          repository: _UniversityFixture(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('What2Eat'), findsOneWidget);
    expect(find.text('Welcome back, Ali! 👋'), findsOneWidget);
    expect(find.byKey(const ValueKey('customer-navigation')), findsOneWidget);
    expect(find.byTooltip('Account options'), findsOneWidget);
    expect(find.text('Meal Date'), findsOneWidget);

    // Default university is UTM: Warung Kopi does not serve UTM.
    expect(find.text('3 found'), findsOneWidget);
    expect(find.text('Mama Siti Kitchen'), findsOneWidget);
    expect(find.text('Wok & Bowl Express'), findsOneWidget);
    expect(find.text('Warung Kopi & Roti'), findsNothing);

    // Switch to UM: Wok & Bowl Express does not serve UM.
    await tester.tap(find.text('UTM • Universiti Teknologi Malaysia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Universiti Malaya'));
    await tester.pumpAndSettle();
    expect(find.text('Wok & Bowl Express'), findsNothing);
    expect(find.text('Mama Siti Kitchen'), findsOneWidget);
    expect(find.text('Warung Kopi & Roti'), findsOneWidget);

    // "Other" is a university row that has no vendors serving it.
    await tester.tap(find.text('UM • Universiti Malaya'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Other / not listed'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Other / not listed'));
    await tester.pumpAndSettle();
    expect(find.text('0 found'), findsOneWidget);
    expect(find.textContaining('No vendors have a menu on'), findsOneWidget);
  });

  testWidgets(
    'Customer dashboard supports university filter, search, and vendor sessions',
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

      // Tap Mama Siti Kitchen -> opens vendor profile where meal sessions are shown vertically
      await tester.tap(find.text('Mama Siti Kitchen'));
      await tester.pumpAndSettle();

      expect(find.text('Meal Sessions'), findsOneWidget);
      expect(find.text('Breakfast'), findsOneWidget);
      expect(find.text('Lunch'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Dinner'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Dinner'), findsOneWidget);

      // Offline sessions have no confirmed ordering window and cannot open.
      expect(find.text('View Customized Selections'), findsNothing);
    },
  );
}
