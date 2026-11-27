import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what2eat_starter/features/student/customer_dashboard_page.dart';
import 'package:what2eat_starter/features/student/models/customer_discovery_models.dart';
import 'package:what2eat_starter/features/student/vendor_profile_page.dart';
import 'package:what2eat_starter/features/student/vendor_session_menu_page.dart';

import 'support/customer_menu_fixture.dart';

void main() {
  testWidgets('Session status fits narrow screens with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: VendorProfilePage(
          vendor: menuVendor,
          universities: const [],
          initialDate: DateTime.now(),
          menus: [menuWindow(offset: 3)],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Not open yet'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });
  test('Opening is inclusive and closing exclusive', () {
    final menu = menuWindow();
    expect(menu.isOpenAt(menu.orderOpeningAt), isTrue);
    expect(menu.isOpenAt(menu.orderClosingAt), isFalse);
    expect(
      menu.statusAt(menu.orderOpeningAt.subtract(const Duration(seconds: 1))),
      MenuOrderStatus.notOpenYet,
    );
  });

  testWidgets(
    'Dashboard opens only open sessions, menu filters and selected food details',
    (tester) async {
      final repo = FakeMenuRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerDashboardPage(
            name: 'Ali',
            repository: MenuDiscoveryFixture(),
            menuRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Campus Kitchen'));
      await tester.pumpAndSettle();
      final future = find.byKey(const ValueKey('profile-menu-future-menu'));
      await tester.ensureVisible(future);
      await tester.tap(future);
      await tester.pumpAndSettle();
      expect(find.byType(VendorSessionMenuPage), findsNothing);
      expect(repo.calls, 0);
      final open = find.byKey(const ValueKey('profile-menu-open-menu'));
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(repo.calls, 1);
      expect(find.text('Lunch Menu'), findsOneWidget);
      expect(find.text('Chicken rice'), findsOneWidget);
      expect(find.text('Lemon tea'), findsOneWidget);
      expect(find.text('Sold out'), findsOneWidget);
      expect(find.text('Estimated delivery 12:00 – 13:00'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilterChip, 'Rice'));
      await tester.pumpAndSettle();
      expect(find.text('Lemon tea'), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('menu-food-rice')));
      await tester.tap(find.byKey(const ValueKey('menu-food-rice')));
      await tester.pumpAndSettle();
      expect(repo.foodCalls, 1);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Steamed rice with roast chicken'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.byTooltip('Close food details'));
      await tester.pumpAndSettle();
      expect(find.text('Lemon tea'), findsNothing);
      expect(find.text('View Customized Selections'), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);
    },
  );

  testWidgets('Closed sessions cannot navigate', (tester) async {
    final repo = FakeMenuRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: VendorProfilePage(
          vendor: menuVendor,
          universities: const [],
          menus: [menuWindow(id: 'closed-menu', offset: -3)],
          menuRepository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tile = find.byKey(const ValueKey('profile-menu-closed-menu'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byType(VendorSessionMenuPage), findsNothing);
    expect(repo.calls, 0);
  });

  testWidgets('Load failure retries without substituting sample food', (
    tester,
  ) async {
    final repo = FakeMenuRepository()..fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: VendorSessionMenuPage(
          vendor: menuVendor,
          menu: menuWindow(),
          repository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chicken rice'), findsNothing);
    expect(
      find.text('Could not load this menu. Please try again.'),
      findsOneWidget,
    );
    repo.fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Chicken rice'), findsOneWidget);
  });

  testWidgets('Empty published menu has clear empty state', (tester) async {
    final repo = FakeMenuRepository()..items = [];
    await tester.pumpWidget(
      MaterialApp(
        home: VendorSessionMenuPage(
          vendor: menuVendor,
          menu: menuWindow(),
          repository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No dishes published for this meal session yet.'),
      findsOneWidget,
    );
  });

  for (final size in [
    (320.0, 700.0, 1.0),
    (375.0, 812.0, 2.0),
    (812.0, 375.0, 1.0),
  ]) {
    testWidgets('Menu fits ${size.$1} at ${size.$3} text scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(size.$1, size.$2);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(size.$3)),
            child: child!,
          ),
          home: VendorSessionMenuPage(
            vendor: menuVendor,
            menu: menuWindow(),
            repository: FakeMenuRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('menu-food-rice')));
      await tester.tap(find.byKey(const ValueKey('menu-food-rice')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
