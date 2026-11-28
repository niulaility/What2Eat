import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what2eat_starter/features/profile/account_page.dart';
import 'package:what2eat_starter/features/vendor/vendor_catalog.dart';
import 'package:what2eat_starter/features/vendor/vendor_customization_editor.dart';
import 'package:what2eat_starter/features/vendor/vendor_dashboard_page.dart';
import 'package:what2eat_starter/features/vendor/vendor_food_preview.dart';
import 'package:what2eat_starter/features/vendor/vendor_food_editor.dart';
import 'package:what2eat_starter/features/vendor/vendor_ui.dart';
import 'package:what2eat_starter/features/vendor/vendor_menu_food_selection_page.dart';

import 'support/profile_fixture.dart';

Future<void> openVendor(
  WidgetTester tester,
  VendorCatalog catalog, {
  double width = 411,
  double height = 891,
  double scale = 1,
  bool reducedMotion = false,
  SampleProfileRepository? profiles,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reducedMotion,
        ),
        child: child!,
      ),
      home: VendorDashboardPage(
        name: 'Aina Kitchen',
        catalog: catalog,
        profileRepository: profiles,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> reveal(
  WidgetTester tester,
  Finder target,
  String scrollKey,
) async {
  await tester.scrollUntilVisible(
    target,
    300,
    scrollable: find
        .descendant(
          of: find.byKey(ValueKey(scrollKey)),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

void main() {
  late VendorCatalog catalog;
  setUp(() => catalog = VendorCatalog());
  tearDown(() => catalog.dispose());

  testWidgets(
    'Draft has a full-width Delete below Edit and Publish with an inline session date',
    (tester) async {
      await openVendor(tester, catalog, width: 375);
      await tester.tap(find.byKey(const ValueKey('vendor-tab-Menus')));
      await tester.pumpAndSettle();
      final card = tester.getRect(
        find.byKey(const ValueKey('vendor-menu-menu-2')),
      );
      final delete = tester.getRect(
        find.byKey(const ValueKey('delete-menu-menu-2')),
      );
      final edit = tester.getRect(find.byKey(const ValueKey('edit-menu-2')));
      final publish = tester.getRect(
        find.byKey(const ValueKey('publish-menu-2')),
      );
      expect(delete.top, greaterThanOrEqualTo(edit.bottom + 8));
      expect(delete.top, greaterThanOrEqualTo(publish.bottom + 8));
      expect(delete.width, closeTo(card.width - 36, 0.1));
      final heading = tester.widget<Text>(
        find.byKey(const ValueKey('menu-date-menu-2')),
      );
      expect(heading.textSpan!.toPlainText(), startsWith('Dinner ('));
      expect(heading.textSpan!.toPlainText(), isNot(contains('menu')));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('vendor-menu-menu-2')),
          matching: find.byIcon(Icons.close),
        ),
        findsNothing,
      );
    },
  );

  for (final size in [
    (375.0, 812.0, 1.0),
    (375.0, 812.0, 2.0),
    (812.0, 375.0, 1.5),
  ]) {
    testWidgets(
      'Menu cards adapt to ${size.$1}x${size.$2} at ${size.$3} text scale',
      (tester) async {
        await openVendor(
          tester,
          catalog,
          width: size.$1,
          height: size.$2,
          scale: size.$3,
          reducedMotion: true,
        );
        await tester.tap(find.byKey(const ValueKey('vendor-tab-Menus')));
        await tester.pumpAndSettle();
        expect(find.text('Ordering opens'), findsNWidgets(2));
        expect(find.text('Estimated delivery'), findsNWidgets(2));
        final action = find.byKey(const ValueKey('edit-menu-2'));
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Menu actions match active, draft and published views', (
    tester,
  ) async {
    final now = DateTime.now();
    final date = DateUtils.dateOnly(now).add(const Duration(days: 3));
    catalog.saveMenu(
      VendorMenu(
        id: 'active-actions',
        date: date,
        session: VendorMealSession.breakfast,
        openingAt: now.subtract(const Duration(hours: 1)),
        closingAt: now.add(const Duration(hours: 1)),
        deliveryStart: 480,
        deliveryEnd: 540,
        foodIds: ['food-1'],
        isPublished: true,
      ),
    );
    await openVendor(tester, catalog);
    await tester.tap(find.byKey(const ValueKey('vendor-summary-active')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('edit-active-actions')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('delete-menu-active-actions')),
      findsNothing,
    );
    final close = find.byKey(const ValueKey('close-orders-active-actions'));
    await tester.ensureVisible(close);
    await tester.tap(close);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Close Order').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('vendor-menu-active-actions')),
      findsNothing,
    );
    expect(catalog.menus.last.isPublished, isTrue);
    expect(
      catalog
          .menusFor(VendorMenuFilter.active, DateTime.now())
          .map((m) => m.id),
      isNot(contains('active-actions')),
    );
    final published = find.byKey(
      const ValueKey('vendor-menu-filter-published'),
    );
    await tester.ensureVisible(published);
    await tester.tap(published);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('close-orders-active-actions')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('publish-active-actions')), findsNothing);
    final delete = find.byKey(const ValueKey('delete-menu-active-actions'));
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Delete'),
      ),
    );
    await tester.pumpAndSettle();
    expect(catalog.menus.map((m) => m.id), isNot(contains('active-actions')));
    expect(catalog.foods.length, 3);
    final drafts = find.byKey(const ValueKey('vendor-menu-filter-draft'));
    await tester.ensureVisible(drafts);
    await tester.tap(drafts);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('edit-menu-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('publish-menu-2')), findsOneWidget);
    final trash = find.byKey(const ValueKey('delete-menu-menu-2'));
    await tester.ensureVisible(trash);
    await tester.tap(trash);
    await tester.pumpAndSettle();
    expect(find.text('Delete menu?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(catalog.menus.map((menu) => menu.id), contains('menu-2'));
  });

  testWidgets('Summary cards open their matching filtered menu lists', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    expect(
      catalog.saveMenu(
        VendorMenu(
          id: 'today-preview',
          date: today,
          session: VendorMealSession.breakfast,
          openingAt: today.subtract(const Duration(days: 1)),
          closingAt: today.add(const Duration(hours: 6)),
          deliveryStart: 8 * 60,
          deliveryEnd: 9 * 60,
          foodIds: ['food-1'],
        ),
      ),
      isNull,
    );
    expect(
      catalog.saveMenu(
        VendorMenu(
          id: 'active-preview',
          date: today.add(const Duration(days: 3)),
          session: VendorMealSession.breakfast,
          openingAt: now.subtract(const Duration(hours: 1)),
          closingAt: now.add(const Duration(hours: 1)),
          deliveryStart: 8 * 60,
          deliveryEnd: 9 * 60,
          foodIds: ['food-1'],
          isPublished: true,
        ),
      ),
      isNull,
    );
    await openVendor(tester, catalog);
    for (final filter in [
      VendorMenuFilter.active,
      VendorMenuFilter.today,
      VendorMenuFilter.draft,
    ]) {
      final count = int.parse(
        tester
            .widget<Text>(
              find.byKey(ValueKey('vendor-summary-${filter.name}-count')),
            )
            .data!,
      );
      await tester.tap(find.byKey(ValueKey('vendor-summary-${filter.name}')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(ValueKey('vendor-menu-filter-${filter.name}')),
            )
            .selected,
        isTrue,
      );
      final matchingIds = catalog
          .menusFor(filter, now)
          .map((menu) => menu.id)
          .toSet();
      expect(matchingIds.length, count);
      for (final menu in catalog.menus) {
        expect(
          find.byKey(ValueKey('vendor-menu-${menu.id}')),
          matchingIds.contains(menu.id) ? findsOneWidget : findsNothing,
        );
      }
      await tester.tap(find.byKey(const ValueKey('vendor-tab-Home')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('vendor-summary-active')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('vendor-menu-filter-all')), findsNothing);
    final filterTops = [
      for (final name in ['active', 'today', 'draft', 'published'])
        tester.getTopLeft(find.byKey(ValueKey('vendor-menu-filter-$name'))).dy,
    ];
    expect(filterTops, everyElement(filterTops.first));
    await tester.tap(find.byKey(const ValueKey('vendor-menu-filter-active')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const ValueKey('vendor-menu-filter-active')),
          )
          .selected,
      isFalse,
    );
    for (final menu in catalog.menus) {
      expect(find.byKey(ValueKey('vendor-menu-${menu.id}')), findsOneWidget);
    }
  });

  testWidgets(
    'Image selection stays local and is saved only with the food draft',
    (tester) async {
      final bytes = File('test/fixtures/profile-test.jpg').readAsBytesSync();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => VendorFoodEditor(
                      catalog: catalog,
                      food: catalog.foods.first,
                      pickImage: () async => XFile.fromData(
                        bytes,
                        name: 'food.jpg',
                        mimeType: 'image/jpeg',
                      ),
                    ),
                  ),
                ),
                child: const Text('Open photo editor'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open photo editor'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Choose photo'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(catalog.foods.first.imageBytes, isNull);
      expect(
        tester
            .widgetList<VendorFoodImage>(find.byType(VendorFoodImage))
            .any((image) => image.bytes != null),
        isTrue,
      );
      final save = find.byKey(const ValueKey('save-food'));
      await reveal(tester, save, 'food-editor-scroll');
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(catalog.foods.first.imageBytes, orderedEquals(bytes));
    },
  );

  testWidgets('Oversized images are rejected without changing the food photo', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VendorFoodEditor(
          catalog: catalog,
          food: catalog.foods.first,
          pickImage: () async =>
              XFile.fromData(Uint8List(5 * 1024 * 1024 + 1), name: 'large.jpg'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Choose photo'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('Choose an image smaller than 5 MB.'), findsOneWidget);
    expect(catalog.foods.first.imageBytes, isNull);
  });

  testWidgets('Leaving the food editor does not apply unsaved changes', (
    tester,
  ) async {
    await openVendor(tester, catalog);
    await tester.tap(find.byKey(const ValueKey('vendor-tab-Food')));
    await tester.pumpAndSettle();
    final edit = find.byKey(const ValueKey('edit-food-food-1'));
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('food-price')));
    await tester.enterText(find.byKey(const ValueKey('food-price')), '99.00');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(catalog.foods.first.price, 12.5);
  });

  for (final size in [(320.0, 1.0), (411.0, 1.4), (900.0, 1.0)]) {
    testWidgets(
      'Vendor dashboard and management tabs fit ${size.$1}/${size.$2}',
      (tester) async {
        // Supabase is deliberately not initialized: local previews must work offline.
        await openVendor(tester, catalog, width: size.$1, scale: size.$2);
        expect(find.text('Welcome back, Aina! 👋'), findsOneWidget);
        expect(find.text('What2Eat'), findsOneWidget);
        expect(find.text('What’s cooking in your kitchen?'), findsNothing);
        expect(find.text('Published menus'), findsNothing);
        expect(find.text('Your next menus'), findsNothing);
        expect(find.text('Your food catalog'), findsNothing);
        expect(
          find.byKey(const ValueKey('vendor-summary-active')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('vendor-summary-today')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('vendor-summary-draft')),
          findsOneWidget,
        );
        final summaryCards = ['active', 'today', 'draft']
            .map(
              (id) =>
                  tester.getRect(find.byKey(ValueKey('vendor-summary-$id'))),
            )
            .toList();
        expect(summaryCards.map((rect) => rect.top).toSet().length, 1);
        expect(summaryCards.map((rect) => rect.height).toSet().length, 1);
        expect(summaryCards[0].right, lessThan(summaryCards[1].left));
        expect(summaryCards[1].right, lessThan(summaryCards[2].left));
        expect(
          find.byKey(const ValueKey('vendor-tab-Categories')),
          findsNothing,
        );
        for (final tab in ['Menus', 'Food', 'Home']) {
          await tester.tap(find.byKey(ValueKey('vendor-tab-$tab')));
          await tester.pumpAndSettle();
          final scroll = tester.state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('vendor-dashboard-scroll')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          scroll.position.jumpTo(scroll.position.maxScrollExtent);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets(
    'Create item preselects the filter category and allows a different category',
    (tester) async {
      await openVendor(tester, catalog);
      await tester.tap(find.byKey(const ValueKey('vendor-tab-Food')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Rice bowls'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('vendor-create-food')));
      await tester.pumpAndSettle();
      final category = find.byKey(const ValueKey('food-category'));
      await reveal(tester, category, 'food-editor-scroll');
      expect(
        tester.widget<DropdownButtonFormField<String>>(category).initialValue,
        'rice',
      );
      await tester.tap(category);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wraps').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('food-name')));
      await tester.enterText(
        find.byKey(const ValueKey('food-name')),
        'New wrap',
      );
      await tester.enterText(find.byKey(const ValueKey('food-price')), '7.50');
      final save = find.byKey(const ValueKey('save-food'));
      await reveal(tester, save, 'food-editor-scroll');
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(catalog.foods.last.name, 'New wrap');
      expect(catalog.foods.last.categoryId, 'wraps');
    },
  );

  testWidgets(
    'Edit beside the category plus opens rename and safe category removal',
    (tester) async {
      await openVendor(tester, catalog);
      await tester.tap(find.byKey(const ValueKey('vendor-tab-Food')));
      await tester.pumpAndSettle();
      final edit = find.byKey(const ValueKey('vendor-edit-categories'));
      final add = find.byKey(const ValueKey('vendor-add-category'));
      expect(
        tester.getTopLeft(edit).dx - tester.getTopRight(add).dx,
        lessThanOrEqualTo(8),
      );
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(find.text('Edit categories'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Edit'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Remove'),
        ),
        findsNothing,
      );
      final name = find.byKey(const ValueKey('edit-category-name-rice'));
      await tester.tap(name);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.enterText(name, 'Wraps');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('This category already exists.'), findsOneWidget);
      await tester.enterText(name, 'Bowls');
      await tester.tap(find.widgetWithText(TextButton, 'Done'));
      await tester.pumpAndSettle();
      expect(catalog.categoryName('rice'), 'Bowls');
      await tester.tap(edit);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('remove-category-rice')));
      await tester.pumpAndSettle();
      expect(find.text('Remove category?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(
        catalog.categories.map((category) => category.id),
        isNot(contains('rice')),
      );
      expect(catalog.foods.length, 3);
      expect(catalog.foods.first.categoryId, isNull);
      await tester.tap(find.widgetWithText(TextButton, 'Done'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('vendor-create-food')), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('vendor-category-uncategorized')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('vendor-food-food-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('vendor-food-food-3')), findsOneWidget);
      expect(find.byKey(const ValueKey('vendor-food-food-2')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('vendor-create-food')));
      await tester.pumpAndSettle();
      final category = find.byKey(const ValueKey('food-category'));
      await reveal(tester, category, 'food-editor-scroll');
      expect(
        tester.widget<DropdownButtonFormField<String>>(category).initialValue,
        '',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Customization groups drag into saved customer display order', (
    tester,
  ) async {
    await openVendor(tester, catalog);
    await tester.tap(find.byKey(const ValueKey('vendor-tab-Food')));
    await tester.pumpAndSettle();
    final edit = find.byKey(const ValueKey('edit-food-food-1'));
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('save-food'));
    await reveal(tester, save, 'food-editor-scroll');
    final drink = find.byKey(const ValueKey('reorder-customization-drink'));
    final extras = find.byKey(const ValueKey('reorder-customization-extras'));
    expect(find.text('Move'), findsNothing);
    final from = tester.getCenter(drink);
    final to = tester.getCenter(extras);
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump(const Duration(milliseconds: 300));
    for (var step = 1; step <= 6; step++) {
      await gesture.moveTo(
        Offset(from.dx, from.dy + (to.dy - from.dy + 100) * step / 6),
      );
      await tester.pump(const Duration(milliseconds: 150));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('food-customization-extras')))
          .dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('food-customization-drink')))
            .dy,
      ),
    );
    expect(catalog.foods.first.groups.map((group) => group.id), [
      'drink',
      'extras',
    ]);
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(catalog.foods.first.groups.map((group) => group.id), [
      'extras',
      'drink',
    ]);
    expect(find.byKey(const ValueKey('preview-food-food-1')), findsNothing);
    await tester.pumpWidget(
      MaterialApp(home: VendorFoodPreview(food: catalog.foods.first)),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Add-ons')).dy,
      lessThan(tester.getTopLeft(find.text('Choose your drink')).dy),
    );
  });

  testWidgets('Option dragging preserves names, prices and saved order', (
    tester,
  ) async {
    await openVendor(tester, catalog);
    await tester.tap(find.byKey(const ValueKey('vendor-tab-Food')));
    await tester.pumpAndSettle();
    final editFood = find.byKey(const ValueKey('edit-food-food-1'));
    await tester.ensureVisible(editFood);
    await tester.tap(editFood);
    await tester.pumpAndSettle();
    final editGroup = find.byKey(const ValueKey('edit-customization-drink'));
    await reveal(tester, editGroup, 'food-editor-scroll');
    await tester.tap(editGroup);
    await tester.pumpAndSettle();
    final waterName = find.byKey(const ValueKey('option-name-water'));
    await tester.ensureVisible(waterName);
    await tester.enterText(waterName, 'Still water');
    await tester.enterText(
      find.byKey(const ValueKey('option-price-water')),
      '0.80',
    );
    final availability = find.byKey(const ValueKey('option-availability-water'));
    await tester.ensureVisible(availability);
    await tester.pumpAndSettle();
    await tester.tap(availability);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final tea = find.byKey(const ValueKey('reorder-option-tea'));
    await tester.ensureVisible(tea);
    await tester.pumpAndSettle();
    final water = find.byKey(const ValueKey('reorder-option-water'));
    await Scrollable.ensureVisible(tester.element(water), alignment: .3);
    await tester.pumpAndSettle();
    final from = tester.getCenter(water);
    final to = tester.getCenter(tea);
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 600));
    for (var step = 1; step <= 6; step++) {
      await gesture.moveTo(
        Offset(from.dx, from.dy + (to.dy - from.dy + 10) * step / 6),
      );
      await tester.pump(const Duration(milliseconds: 150));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('option-tea'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('option-water'))).dy,
      ),
    );
    final saveGroup = find.byKey(const ValueKey('save-customization'));
    await reveal(tester, saveGroup, 'customization-editor-scroll');
    await tester.tap(saveGroup);
    await tester.pumpAndSettle();
    expect(catalog.foods.first.groups.first.options.first.id, 'water');
    final saveFood = find.byKey(const ValueKey('save-food'));
    await reveal(tester, saveFood, 'food-editor-scroll');
    await tester.tap(saveFood);
    await tester.pumpAndSettle();
    final options = catalog.foods.first.groups.first.options;
    expect(options.take(2).map((option) => option.id), ['tea', 'water']);
    expect(options[1].name, 'Still water');
    expect(options[1].additionalPrice, 0.8);
    expect(options[1].isAvailable, isFalse);
    await tester.pumpWidget(
      MaterialApp(home: VendorFoodPreview(food: catalog.foods.first)),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('preview-option-water')),
          )
          .onChanged,
      isNull,
    );
  });

  testWidgets(
    'Categories drag into filter order without changing their food assignments',
    (tester) async {
      await openVendor(tester, catalog);
      await tester.tap(find.byKey(const ValueKey('vendor-tab-Food')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('vendor-edit-categories')));
      await tester.pumpAndSettle();
      final rice = find.byKey(const ValueKey('reorder-category-rice'));
      final wraps = find.byKey(const ValueKey('reorder-category-wraps'));
      final from = tester.getCenter(rice);
      final to = tester.getCenter(wraps);
      final gesture = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 600));
      for (var step = 1; step <= 6; step++) {
        await gesture.moveTo(
          Offset(from.dx, from.dy + (to.dy - from.dy + 5) * step / 6),
        );
        await tester.pump(const Duration(milliseconds: 150));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(catalog.categories.map((category) => category.id), [
        'wraps',
        'rice',
        'drinks',
      ]);
      expect(catalog.foods.first.categoryId, 'rice');
      await tester.tap(find.widgetWithText(TextButton, 'Done'));
      await tester.pumpAndSettle();
      final wrapsPosition = tester.getTopLeft(
        find.widgetWithText(ChoiceChip, 'Wraps'),
      );
      final ricePosition = tester.getTopLeft(
        find.widgetWithText(ChoiceChip, 'Rice bowls'),
      );
      expect(
        wrapsPosition.dy < ricePosition.dy ||
            (wrapsPosition.dy == ricePosition.dy &&
                wrapsPosition.dx < ricePosition.dx),
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('vendor-edit-categories')));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(wraps).dy, lessThan(tester.getTopLeft(rice).dy));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Selected menu food availability persists per menu and across Back',
    (tester) async {
      await openVendor(tester, catalog);
      await tester.tap(find.byKey(const ValueKey('vendor-tab-Menus')));
      await tester.pumpAndSettle();
      final edit = find.byKey(const ValueKey('edit-menu-1'));
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      final next = find.byKey(const ValueKey('menu-next'));
      await reveal(tester, next, 'menu-editor-scroll');
      await tester.tap(next);
      await tester.pumpAndSettle();
      final availability = find.byKey(
        const ValueKey('menu-food-availability-food-1'),
      );
      await tester.ensureVisible(availability);
      expect(tester.widget<SwitchListTile>(availability).value, isTrue);
      await tester.tap(availability);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(availability).value, isFalse);
      expect(find.text('Sold out'), findsOneWidget);
      expect(catalog.menus.first.unavailableFoodIds, isEmpty);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(availability).value, isFalse);
      final publish = find.byKey(const ValueKey('publish-menu'));
      await reveal(tester, publish, 'menu-food-scroll');
      await tester.tap(publish);
      await tester.pumpAndSettle();
      expect(catalog.menus.first.unavailableFoodIds, ['food-1']);
      expect(catalog.menus.last.unavailableFoodIds, isEmpty);
      expect(catalog.foods.first.isAvailable, isTrue);
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      await reveal(tester, next, 'menu-editor-scroll');
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(availability).value, isFalse);
      final food = find.byKey(const ValueKey('menu-food-food-1'));
      await tester.ensureVisible(food);
      await tester.tap(food);
      await tester.pumpAndSettle();
      expect(availability, findsNothing);
      await tester.tap(food);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(availability).value, isTrue);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(catalog.menus.first.unavailableFoodIds, ['food-1']);
    },
  );

  testWidgets('Food editor saves a local food card with validation', (
    tester,
  ) async {
    await openVendor(tester, catalog);
    await tester.tap(find.byKey(const ValueKey('vendor-tab-Food')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vendor-create-food')));
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('save-food'));
    await reveal(tester, save, 'food-editor-scroll');
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Enter a food name.'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('food-name')));
    await tester.enterText(
      find.byKey(const ValueKey('food-name')),
      'Campus Toast',
    );
    await tester.enterText(find.byKey(const ValueKey('food-price')), '5.50');
    await reveal(tester, save, 'food-editor-scroll');
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(catalog.foods.last.name, 'Campus Toast');
    expect(catalog.foods.last.price, 5.5);
    expect(find.text('Campus Toast'), findsOneWidget);
  });

  testWidgets('Meal sessions open below the field for every selection', (
    tester,
  ) async {
    await openVendor(tester, catalog);
    await tester.tap(find.byKey(const ValueKey('vendor-tab-Menus')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Create menu'));
    await tester.pumpAndSettle();
    final dropdown = find.byKey(const ValueKey('menu-session'));
    for (final label in ['Dinner', 'Lunch', 'Breakfast', 'Dinner']) {
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      final firstOption = find.widgetWithText(MenuItemButton, 'Breakfast');
      expect(
        tester.getTopLeft(firstOption).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(dropdown).dy),
      );
      await tester.tap(find.widgetWithText(MenuItemButton, label));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Menu category filters retain selections and Publish saves locally',
    (tester) async {
      final selection = <String>{};
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Theme(
              data: vendorThemeData(context),
              child: VendorMenuFoodSelectionPage(
                catalog: catalog,
                draft: catalog.menus.last,
                selection: selection,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('menu-category-rice')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('menu-food-food-2')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('menu-food-food-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('menu-category-wraps')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('menu-food-food-1')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('menu-food-food-2')));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
      expect(catalog.menus.last.isPublished, isFalse);
      await tester.tap(find.byKey(const ValueKey('menu-category-drinks')));
      await tester.pumpAndSettle();
      expect(find.text('No food items in this category yet.'), findsOneWidget);
      final publish = find.byKey(const ValueKey('publish-menu'));
      await reveal(tester, publish, 'menu-food-scroll');
      await tester.tap(publish);
      await tester.pumpAndSettle();
      expect(catalog.menus.last.isPublished, isTrue);
      expect(catalog.menus.last.foodIds, containsAll(['food-1', 'food-2']));
    },
  );

  testWidgets('Create a date/session menu and publish only in preview', (
    tester,
  ) async {
    await openVendor(tester, catalog);
    await tester.tap(find.byKey(const ValueKey('vendor-tab-Menus')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Create menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-session')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dinner').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('menu-food-food-1')), findsNothing);
    final next = find.byKey(const ValueKey('menu-next'));
    await reveal(tester, next, 'menu-editor-scroll');
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(catalog.menus.length, 2);
    final saveEmpty = find.byKey(const ValueKey('save-menu'));
    await reveal(tester, saveEmpty, 'menu-food-scroll');
    await tester.tap(saveEmpty);
    await tester.pumpAndSettle();
    expect(find.text('Select at least one food item.'), findsOneWidget);
    final food = find.byKey(const ValueKey('menu-food-food-1'));
    await reveal(tester, food, 'menu-food-scroll');
    await tester.tap(food);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-next')));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(food).value, isTrue);
    final save = find.byKey(const ValueKey('save-menu'));
    await reveal(tester, save, 'menu-food-scroll');
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(catalog.menus.length, 3);
    final menu = catalog.menus.last;
    expect(menu.isPublished, isFalse);
    expect(menu.session, VendorMealSession.dinner);
    expect(menu.deliveryStart, 18 * 60);
    expect(menu.deliveryEnd, 19 * 60);
    final publish = find.byKey(ValueKey('publish-${menu.id}'));
    await tester.ensureVisible(publish);
    await tester.tap(publish);
    await tester.pumpAndSettle();
    expect(find.textContaining('local preview only'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(catalog.menus.last.isPublished, isTrue);
  });

  testWidgets(
    'The filter plus only adds categories with duplicate validation',
    (tester) async {
      await openVendor(tester, catalog);
      await tester.tap(find.byKey(const ValueKey('vendor-tab-Food')));
      await tester.pumpAndSettle();
      expect(find.text('Manage categories'), findsNothing);
      expect(find.byTooltip('Add food item'), findsNothing);
      await tester.tap(find.byTooltip('Add category'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('category-name')),
        'rice bowls',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('This category already exists.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('category-name')),
        'Breakfast',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(catalog.categories.last.name, 'Breakfast');
      expect(find.byType(VendorFoodEditor), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Breakfast'));
      await tester.pumpAndSettle();
      expect(find.text('No food items in this view yet.'), findsOneWidget);
      expect(catalog.foods.length, 3);
      expect(catalog.foods.first.categoryId, 'rice');
    },
  );

  testWidgets(
    'Customer preview enforces required and maximum selections and updates prices',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: VendorFoodPreview(food: catalog.foods.first)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-food-preview')));
      await tester.pumpAndSettle();
      expect(find.text('Choose at least 1 option.'), findsOneWidget);
      final tea = find.byKey(const ValueKey('preview-option-tea'));
      await reveal(tester, tea, 'food-preview-scroll');
      await tester.tap(tea);
      await tester.pumpAndSettle();
      expect(find.text('Preview total: RM 14.00'), findsOneWidget);
      for (final id in ['egg', 'rice', 'veg']) {
        final option = find.byKey(ValueKey('preview-option-$id'));
        await reveal(tester, option, 'food-preview-scroll');
        await tester.tap(option);
        await tester.pumpAndSettle();
      }
      expect(find.text('Preview total: RM 18.50'), findsOneWidget);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('preview-option-chicken')),
            )
            .onChanged,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('confirm-food-preview')));
      await tester.pumpAndSettle();
      expect(
        find.text('Selection preview only. No order was placed.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Customization option fields share a row with availability below',
    (tester) async {
      tester.view.physicalSize = const Size(411, 891);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Theme(
              data: vendorThemeData(context),
              child: VendorCustomizationEditor(
                catalog: catalog,
                group: catalog.foods.first.groups.first,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Option 1'), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);
      final name = find.byKey(const ValueKey('option-name-water'));
      final price = find.byKey(const ValueKey('option-price-water'));
      expect(tester.getTopLeft(price).dy, tester.getTopLeft(name).dy);
      expect(
        tester.getTopLeft(price).dx,
        greaterThan(tester.getTopRight(name).dx),
      );
      final availability = find.byKey(
        const ValueKey('option-availability-water'),
      );
      expect(
        tester.getTopLeft(availability).dy,
        greaterThan(tester.getBottomLeft(price).dy),
      );
      final drag = find.byKey(const ValueKey('reorder-option-water'));
      final trash = find.byKey(const ValueKey('remove-option-water'));
      final card = tester.getRect(find.byKey(const ValueKey('option-water')));
      expect(tester.getCenter(drag).dx, closeTo(card.center.dx, .1));
      expect(
        tester.getCenter(drag).dy,
        greaterThan(tester.getCenter(availability).dy),
      );
      expect(
        tester.getCenter(trash).dx,
        greaterThan(tester.getTopRight(name).dx),
      );
      final tea = find.byKey(const ValueKey('option-name-tea'));
      await tester.ensureVisible(tea);
      await tester.enterText(tea, 'Updated tea');
      final remove = find.byKey(const ValueKey('remove-option-water'));
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(name, findsNothing);
      final input = tester.widget<TextField>(
        find.descendant(of: tea, matching: find.byType(TextField)),
      );
      expect(input.controller!.text, 'Updated tea');
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [(320.0, 1.0), (375.0, 2.0), (900.0, 1.0)]) {
    testWidgets(
      'Reference option layout fits ${size.$1} at ${size.$2} text scale',
      (tester) async {
        tester.view.physicalSize = Size(size.$1, 812);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(size.$2)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Theme(
                data: vendorThemeData(context),
                child: VendorCustomizationEditor(
                  catalog: catalog,
                  group: catalog.foods.first.groups.first,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('save-customization')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Customization editor rejects limits that exceed option count', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Theme(
            data: vendorThemeData(context),
            child: VendorCustomizationEditor(
              catalog: catalog,
              group: catalog.foods.first.groups.first,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('group-max')), '6');
    final save = find.byKey(const ValueKey('save-customization'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(
      find.text('Maximum selections cannot exceed the number of options.'),
      findsOneWidget,
    );
  });

  testWidgets('Existing top-right profile entry is retained', (tester) async {
    final profiles = SampleProfileRepository(role: 'vendor');
    await openVendor(tester, catalog, profiles: profiles);
    expect(
      tester.getCenter(find.byTooltip('Account options')).dx,
      greaterThan(350),
    );
    await tester.tap(find.byTooltip('Account options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountPage), findsOneWidget);
    expect(find.text('Edit profile'), findsOneWidget);
  });
}
