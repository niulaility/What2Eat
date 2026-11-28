import 'package:flutter_test/flutter_test.dart';
import 'package:what2eat_starter/features/vendor/vendor_catalog.dart';

void main() {
  late VendorCatalog catalog;
  setUp(() => catalog = VendorCatalog(now: DateTime(2026, 11, 25, 8)));
  tearDown(() => catalog.dispose());

  VendorMenu menu({
    String id = 'new',
    DateTime? opening,
    DateTime? closing,
    int start = 12 * 60,
    int end = 13 * 60,
    List<String> foods = const ['food-1'],
    VendorMealSession session = VendorMealSession.dinner,
  }) => VendorMenu(
    id: id,
    date: DateTime(2026, 11, 26),
    session: session,
    openingAt: opening ?? DateTime(2026, 11, 25, 8),
    closingAt: closing ?? DateTime(2026, 11, 26, 10),
    deliveryStart: start,
    deliveryEnd: end,
    foodIds: foods,
  );

  test(
    'Catalog mirrors separate menus, food, categories and customization limits',
    () {
      expect(catalog.foods.length, 3);
      expect(catalog.menus.length, 2);
      expect(catalog.foods.first.groups[0].selectionLabel, 'Choose 1 of 5');
      expect(
        catalog.foods.first.groups[1].selectionLabel,
        'Choose up to 3 of 5',
      );
      expect(
        catalog.foods.first.groups.map(validateVendorGroup),
        everyElement(isNull),
      );
    },
  );

  test(
    'Category names are normalized and removing a category preserves food',
    () {
      expect(catalog.saveCategory('  RICE   BOWLS '), isNotNull);
      expect(catalog.saveCategory('  Light   meals  '), isNull);
      expect(catalog.categories.last.name, 'Light meals');
      catalog.removeCategory('rice');
      expect(catalog.foods.length, 3);
      expect(catalog.foods.first.categoryId, isNull);
      expect(
        catalog.categoryName(catalog.foods.first.categoryId),
        'Uncategorized',
      );
    },
  );

  test(
    'Menu windows, date-session uniqueness and food references are checked',
    () {
      expect(
        catalog.validateMenu(menu(closing: DateTime(2026, 11, 25, 7))),
        'Ordering must close after it opens.',
      );
      expect(
        catalog.validateMenu(menu(start: 780, end: 720)),
        'Delivery must end after it starts.',
      );
      expect(
        catalog.validateMenu(menu(closing: DateTime(2026, 11, 26, 13))),
        'Close ordering before the delivery window starts.',
      );
      expect(
        catalog.validateMenu(menu(session: VendorMealSession.lunch)),
        'A menu already exists for this date and meal session.',
      );
      expect(
        catalog.validateMenu(menu(foods: [])),
        'Select at least one food item.',
      );
      expect(catalog.validateMenuSchedule(menu(foods: [])), isNull);
      expect(
        catalog.validateMenuSchedule(menu(closing: DateTime(2026, 11, 25, 7))),
        'Ordering must close after it opens.',
      );
      expect(
        catalog.validateMenu(menu(foods: ['missing'])),
        'A selected food item is no longer available.',
      );
      expect(catalog.validateMenu(menu()), isNull);
    },
  );

  test('Draft creation and publishing only update the local catalog', () {
    expect(catalog.saveMenu(menu()), isNull);
    expect(catalog.menus.last.isPublished, isFalse);
    expect(catalog.setPublished('new', true), isNull);
    expect(catalog.menus.last.isPublished, isTrue);
    expect(catalog.setPublished('new', false), isNull);
    expect(catalog.menus.last.isPublished, isFalse);
  });

  test(
    'Dashboard counts distinguish open ordering, menu date and draft status',
    () {
      expect(catalog.menuCountsAt(DateTime(2026, 11, 25, 7)).active, 0);
      final opening = catalog.menuCountsAt(DateTime(2026, 11, 25, 8));
      expect(opening.active, 1);
      expect(opening.today, 0);
      expect(opening.draft, 1);
      final closing = catalog.menuCountsAt(DateTime(2026, 11, 26, 10));
      expect(closing.active, 0);
      expect(closing.today, 1);
      expect(closing.draft, 1);
      catalog.setPublished('menu-1', false);
      expect(catalog.menuCountsAt(DateTime(2026, 11, 26, 10)).today, 0);
      expect(
        catalog.menusFor(VendorMenuFilter.today, DateTime(2026, 11, 26, 10)),
        isEmpty,
      );
      expect(
        catalog
            .menusFor(VendorMenuFilter.draft, DateTime(2026, 11, 26, 10))
            .map((menu) => menu.id),
        contains('menu-1'),
      );
      catalog.setPublished('menu-1', true);
      expect(catalog.menuCountsAt(DateTime(2026, 11, 26, 10)).today, 1);
      catalog.setPublished('menu-1', false);
      expect(catalog.menuCountsAt(DateTime(2026, 11, 25, 9)).active, 0);
      expect(catalog.menuCountsAt(DateTime(2026, 11, 25, 9)).draft, 2);
    },
  );

  test('Closed menus expire after their menu date ends, preserving drafts and food', () {
    catalog.setPublished('menu-2', true);
    expect(
      catalog.removeExpiredClosedMenus(DateTime(2026, 11, 26, 23, 59, 59)),
      0,
    );
    expect(catalog.removeExpiredClosedMenus(DateTime(2026, 11, 27)), 1);
    expect(catalog.menus.map((menu) => menu.id), isNot(contains('menu-1')));
    // The next menu is already closed for orders but its menu date is today.
    expect(catalog.menus.map((menu) => menu.id), contains('menu-2'));
    catalog.setPublished('menu-2', false);
    expect(catalog.removeExpiredClosedMenus(DateTime(2026, 11, 28)), 0);
    expect(catalog.menus.map((menu) => menu.id), contains('menu-2'));
    catalog.setPublished('menu-2', true);
    expect(catalog.removeExpiredClosedMenus(DateTime(2026, 11, 28)), 1);
    expect(catalog.removeExpiredClosedMenus(DateTime(2026, 11, 28)), 0);
    expect(catalog.foods.length, 3);
    expect(catalog.categories.length, 3);
  });

  test('Menu availability is retained on publishing and cleared with removed food links', () {
    final draft = menu().copyWith(unavailableFoodIds: ['food-1']);
    expect(catalog.saveMenu(draft), isNull);
    expect(catalog.setPublished(draft.id, true), isNull);
    expect(catalog.menus.last.unavailableFoodIds, ['food-1']);
    expect(catalog.menus.first.unavailableFoodIds, isEmpty);
    expect(catalog.foods.first.isAvailable, isTrue);
    catalog.removeFood('food-1');
    expect(catalog.menus.last.foodIds, isEmpty);
    expect(catalog.menus.last.unavailableFoodIds, isEmpty);
    expect(catalog.menus.last.isPublished, isFalse);
  });

  test('Deleting food removes menu links and makes empty menus drafts', () {
    catalog.removeFood('food-1');
    expect(
      catalog.menus.every((menu) => !menu.foodIds.contains('food-1')),
      isTrue,
    );
    catalog.removeFood('food-2');
    expect(catalog.menus.first.foodIds, isEmpty);
    expect(catalog.menus.first.isPublished, isFalse);
  });

  test('Customization minimum, maximum, duplicate names and extra prices are checked', () {
    VendorCustomizationGroup group(
      int min,
      int max,
      List<VendorCustomizationOption> options,
    ) => VendorCustomizationGroup(
      id: 'test',
      name: 'Toppings',
      minSelectable: min,
      maxSelectable: max,
      options: options,
    );
    const options = [
      VendorCustomizationOption(id: 'one', name: 'Egg'),
      VendorCustomizationOption(id: 'two', name: 'Sauce'),
    ];
    expect(validateVendorGroup(group(2, 1, options)), isNotNull);
    expect(validateVendorGroup(group(0, 3, options)), isNotNull);
    expect(validateVendorGroup(group(0, 1, [])), isNotNull);
    expect(
      validateVendorGroup(
        group(0, 1, const [
          VendorCustomizationOption(
            id: 'one',
            name: 'Egg',
            additionalPrice: -1,
          ),
        ]),
      ),
      isNotNull,
    );
    expect(
      validateVendorGroup(
        group(0, 1, const [
          VendorCustomizationOption(id: 'one', name: 'Egg'),
          VendorCustomizationOption(id: 'two', name: ' egg '),
        ]),
      ),
      isNotNull,
    );
    expect(validateVendorGroup(group(0, 2, options)), isNull);
  });

  test('Food editing checks price and leaves other food data intact', () {
    expect(
      catalog.saveFood(
        const VendorFood(id: 'food-1', name: 'Updated bowl', price: -1),
      ),
      isNotNull,
    );
    final original = catalog.foods.first;
    expect(
      catalog.saveFood(
        VendorFood(
          id: original.id,
          name: 'Updated bowl',
          price: 14,
          groups: original.groups,
        ),
      ),
      isNull,
    );
    expect(catalog.foods.first.price, 14);
    expect(catalog.foods.first.groups.length, 2);
    expect(catalog.foods[1].name, 'Grilled Chicken Wrap');
  });
}
