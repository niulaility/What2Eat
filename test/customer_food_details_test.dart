import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what2eat_starter/features/student/models/customer_discovery_models.dart';
import 'package:what2eat_starter/features/student/widgets/customer_food_details_sheet.dart';

import 'support/customer_menu_fixture.dart';

Future<void> openDetails(WidgetTester tester, FakeMenuRepository repo) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CustomerFoodDetailsSheet(
          vendorId: 'menu-vendor',
          menuId: 'open-menu',
          foodId: repo.items.first.id,
          repository: repo,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String id) async {
  final control = find.byKey(ValueKey('food-option-$id'));
  await tester.scrollUntilVisible(
    control,
    100,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
  await tester.tap(control);
  await tester.pumpAndSettle();
}

bool? isSelected(WidgetTester tester, String id) => tester
    .widget<Semantics>(
      find
          .descendant(
            of: find.byKey(ValueKey('food-option-$id')),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics && widget.properties.checked != null,
            ),
          )
          .first,
    )
    .properties
    .checked;

MenuItem customized({bool available = true}) => MenuItem(
  id: 'custom',
  vendorId: 'menu-vendor',
  sessionIds: const ['lunch'],
  name: 'Rice bowl',
  description: 'Choose your sides',
  price: 9.5,
  category: 'Rice',
  isAvailable: available,
  customizationGroups: const [
    CustomizationGroup(
      id: 'sides',
      title: 'Sides',
      isRequired: true,
      allowMultiple: true,
      minSelections: 2,
      maxSelections: 2,
      options: [
        CustomizationOption(id: 'egg', name: 'Egg', priceDelta: 1.5),
        CustomizationOption(id: 'salad', name: 'Salad', priceDelta: 2),
        CustomizationOption(id: 'soup', name: 'Soup', priceDelta: .1),
        CustomizationOption(
          id: 'unavailable',
          name: 'Sold out side',
          priceDelta: 3,
          isAvailable: false,
        ),
      ],
    ),
  ],
);

void main() {
  testWidgets(
    'Single choice replaces previous option, clears and updates price without a cart',
    (tester) async {
      await openDetails(tester, FakeMenuRepository());
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('food-price-preview')))
            .data,
        'RM 9.50',
      );
      expect(find.text('Choose required options'), findsOneWidget);
      await choose(tester, 'hot');
      expect(find.text('RM 10.50'), findsOneWidget);
      expect(find.text('Choices complete'), findsOneWidget);
      await choose(tester, 'mild');
      expect(isSelected(tester, 'hot'), isFalse);
      expect(find.text('RM 10.50'), findsNothing);
      await choose(tester, 'mild');
      expect(find.text('Choose required options'), findsOneWidget);
      expect(find.textContaining('Add •'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    },
  );

  testWidgets(
    'Minimum and maximum limits, unavailable options and price arithmetic work',
    (tester) async {
      await openDetails(tester, FakeMenuRepository()..items = [customized()]);
      await choose(tester, 'egg');
      expect(find.text('Choose required options'), findsOneWidget);
      await choose(tester, 'salad');
      expect(find.text('RM 13.00'), findsOneWidget);
      expect(find.text('Choices complete'), findsOneWidget);
      await choose(tester, 'soup');
      expect(find.text('RM 13.00'), findsOneWidget);
      expect(isSelected(tester, 'soup'), isFalse);
      await choose(tester, 'egg');
      await choose(tester, 'soup');
      expect(find.text('RM 11.60'), findsOneWidget);
      await choose(tester, 'unavailable');
      expect(find.text('RM 11.60'), findsOneWidget);
      expect(find.text('Unavailable'), findsOneWidget);
    },
  );

  testWidgets('Sold out food remains viewable but choices are disabled', (
    tester,
  ) async {
    await openDetails(
      tester,
      FakeMenuRepository()..items = [customized(available: false)],
    );
    await choose(tester, 'egg');
    expect(isSelected(tester, 'egg'), isFalse);
    expect(find.text('Sold out'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('food-price-preview')))
          .data,
      'RM 9.50',
    );
  });

  testWidgets('Optional groups can remain unselected', (tester) async {
    final food = MenuItem(
      id: 'optional',
      vendorId: 'menu-vendor',
      sessionIds: const ['lunch'],
      name: 'Tea',
      description: '',
      price: 3,
      category: 'Drinks',
      customizationGroups: const [
        CustomizationGroup(
          id: 'sugar',
          title: 'Sugar',
          isRequired: false,
          allowMultiple: false,
          minSelections: 0,
          maxSelections: 1,
          options: [CustomizationOption(id: 'sugar-option', name: 'Sugar')],
        ),
      ],
    );
    await openDetails(tester, FakeMenuRepository()..items = [food]);
    expect(find.text('Choices complete'), findsOneWidget);
    await choose(tester, 'sugar-option');
    await choose(tester, 'sugar-option');
    expect(find.text('Choices complete'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('food-price-preview')))
          .data,
      'RM 3.00',
    );
  });

  testWidgets('Food details error can retry without showing sample data', (
    tester,
  ) async {
    final repo = FakeMenuRepository()..failFood = true;
    await openDetails(tester, repo);
    expect(find.text('Chicken rice'), findsNothing);
    repo.failFood = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Chicken rice'), findsOneWidget);
    expect(repo.foodCalls, 2);
  });
}
