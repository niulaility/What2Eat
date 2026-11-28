import 'package:flutter/foundation.dart';

enum VendorMealSession { breakfast, lunch, dinner }

enum VendorMenuFilter { all, active, today, draft, published }

bool matchesVendorMenuFilter(
  VendorMenu menu,
  VendorMenuFilter filter,
  DateTime now,
) => switch (filter) {
  VendorMenuFilter.all => true,
  VendorMenuFilter.active =>
    menu.isPublished &&
        !now.isBefore(menu.openingAt) &&
        now.isBefore(menu.closingAt),
  VendorMenuFilter.today =>
    menu.isPublished && DateUtilsForVendor.sameDay(menu.date, now),
  VendorMenuFilter.draft => !menu.isPublished,
  VendorMenuFilter.published => menu.isPublished,
};

extension VendorMealSessionLabel on VendorMealSession {
  String get label => '${name[0].toUpperCase()}${name.substring(1)}';
}

class VendorFoodCategory {
  const VendorFoodCategory(this.id, this.name);
  final String id, name;
}

class VendorCustomizationOption {
  const VendorCustomizationOption({
    required this.id,
    required this.name,
    this.additionalPrice = 0,
    this.isAvailable = true,
  });
  final String id, name;
  final double additionalPrice;
  final bool isAvailable;
}

class VendorCustomizationGroup {
  const VendorCustomizationGroup({
    required this.id,
    required this.name,
    required this.minSelectable,
    required this.maxSelectable,
    required this.options,
  });
  final String id, name;
  final int minSelectable, maxSelectable;
  final List<VendorCustomizationOption> options;
  bool get isRequired => minSelectable > 0;
  String get selectionLabel => minSelectable == maxSelectable
      ? 'Choose $minSelectable of ${options.length}'
      : minSelectable == 0
      ? 'Choose up to $maxSelectable of ${options.length}'
      : 'Choose $minSelectable–$maxSelectable of ${options.length}';
}

class VendorFood {
  const VendorFood({
    required this.id,
    required this.name,
    required this.price,
    this.description = '',
    this.categoryId,
    this.assetImage,
    this.imageBytes,
    this.isAvailable = true,
    this.groups = const [],
  });
  final String id, name, description;
  final String? categoryId, assetImage;
  final Uint8List? imageBytes;
  final double price;
  final bool isAvailable;
  final List<VendorCustomizationGroup> groups;
  VendorFood withoutCategory() => VendorFood(
    id: id,
    name: name,
    price: price,
    description: description,
    assetImage: assetImage,
    imageBytes: imageBytes,
    isAvailable: isAvailable,
    groups: groups,
  );
}

class VendorMenu {
  const VendorMenu({
    required this.id,
    required this.date,
    required this.session,
    required this.openingAt,
    required this.closingAt,
    required this.deliveryStart,
    required this.deliveryEnd,
    required this.foodIds,
    this.unavailableFoodIds = const [],
    this.isPublished = false,
  });
  final String id;
  final DateTime date, openingAt, closingAt;
  final VendorMealSession session;
  // Minutes after midnight: corresponds to the schema's TIME delivery columns.
  final int deliveryStart, deliveryEnd;
  final List<String> foodIds;
  final List<String> unavailableFoodIds;
  final bool isPublished;
  VendorMenu copyWith({
    List<String>? foodIds,
    List<String>? unavailableFoodIds,
    bool? isPublished,
    DateTime? closingAt,
  }) => VendorMenu(
    id: id,
    date: date,
    session: session,
    openingAt: openingAt,
    closingAt: closingAt ?? this.closingAt,
    deliveryStart: deliveryStart,
    deliveryEnd: deliveryEnd,
    foodIds: foodIds ?? this.foodIds,
    unavailableFoodIds: (unavailableFoodIds ?? this.unavailableFoodIds)
        .where((id) => (foodIds ?? this.foodIds).contains(id))
        .toList(),
    isPublished: isPublished ?? this.isPublished,
  );
}

String normalizedVendorName(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');

String? validateVendorGroup(VendorCustomizationGroup group) {
  if (normalizedVendorName(group.name).isEmpty) {
    return 'Enter a customization group name.';
  }
  if (group.options.isEmpty) return 'Add at least one option.';
  if (group.minSelectable < 0 ||
      group.maxSelectable < 1 ||
      group.maxSelectable < group.minSelectable) {
    return 'Use selection limits with 0 ≤ minimum ≤ maximum and maximum ≥ 1.';
  }
  if (group.maxSelectable > group.options.length) {
    return 'Maximum selections cannot exceed the number of options.';
  }
  final names = <String>{};
  for (final option in group.options) {
    final name = normalizedVendorName(option.name).toLowerCase();
    if (name.isEmpty) return 'Enter a name for every option.';
    if (!names.add(name)) return 'Use a different name for each option.';
    if (!option.additionalPrice.isFinite ||
        option.additionalPrice < 0 ||
        option.additionalPrice > 99999999.99) {
      return 'Additional prices must be valid amounts of RM 0.00 or more.';
    }
  }
  return null;
}

/// Session-local preview workspace. No database or storage client is used.
class VendorCatalog extends ChangeNotifier {
  VendorCatalog({DateTime? now}) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    _categories.addAll(const [
      VendorFoodCategory('rice', 'Rice bowls'),
      VendorFoodCategory('wraps', 'Wraps'),
      VendorFoodCategory('drinks', 'Drinks'),
    ]);
    _foods.addAll([
      VendorFood(
        id: 'food-1',
        name: 'Chicken Teriyaki Bowl',
        price: 12.50,
        categoryId: 'rice',
        description:
            'Grilled teriyaki chicken, steamed rice and fresh vegetables.',
        assetImage: 'assets/dashboard/teriyaki-bowl.png',
        groups: [
          VendorCustomizationGroup(
            id: 'drink',
            name: 'Choose your drink',
            minSelectable: 1,
            maxSelectable: 1,
            options: const [
              VendorCustomizationOption(id: 'water', name: 'Mineral water'),
              VendorCustomizationOption(
                id: 'tea',
                name: 'Iced lemon tea',
                additionalPrice: 1.5,
              ),
              VendorCustomizationOption(
                id: 'coffee',
                name: 'Iced coffee',
                additionalPrice: 2,
              ),
              VendorCustomizationOption(
                id: 'juice',
                name: 'Orange juice',
                additionalPrice: 2.5,
              ),
              VendorCustomizationOption(
                id: 'soy',
                name: 'Soy milk',
                additionalPrice: 1,
              ),
            ],
          ),
          VendorCustomizationGroup(
            id: 'extras',
            name: 'Add-ons',
            minSelectable: 0,
            maxSelectable: 3,
            options: const [
              VendorCustomizationOption(
                id: 'egg',
                name: 'Fried egg',
                additionalPrice: 1.5,
              ),
              VendorCustomizationOption(
                id: 'rice',
                name: 'Extra rice',
                additionalPrice: 1,
              ),
              VendorCustomizationOption(
                id: 'chicken',
                name: 'Extra chicken',
                additionalPrice: 4,
              ),
              VendorCustomizationOption(
                id: 'veg',
                name: 'Extra vegetables',
                additionalPrice: 2,
              ),
              VendorCustomizationOption(id: 'sauce', name: 'Extra sauce'),
            ],
          ),
        ],
      ),
      const VendorFood(
        id: 'food-2',
        name: 'Grilled Chicken Wrap',
        price: 9.50,
        categoryId: 'wraps',
        description:
            'Grilled chicken and crunchy vegetables in a soft tortilla.',
        assetImage: 'assets/dashboard/chicken-wrap.png',
      ),
      const VendorFood(
        id: 'food-3',
        name: 'Vegetable Noodle Bowl',
        price: 10,
        categoryId: 'rice',
        description: 'Warm noodles with seasonal vegetables.',
        assetImage: 'assets/dashboard/noodle-bowl.png',
      ),
    ]);
    final tomorrow = today.add(const Duration(days: 1));
    _menus.addAll([
      VendorMenu(
        id: 'menu-1',
        date: tomorrow,
        session: VendorMealSession.lunch,
        openingAt: today.add(const Duration(hours: 8)),
        closingAt: tomorrow.add(const Duration(hours: 10)),
        deliveryStart: 12 * 60,
        deliveryEnd: 13 * 60,
        foodIds: ['food-1', 'food-2'],
        isPublished: true,
      ),
      VendorMenu(
        id: 'menu-2',
        date: tomorrow.add(const Duration(days: 1)),
        session: VendorMealSession.dinner,
        openingAt: today.add(const Duration(hours: 8)),
        closingAt: tomorrow.add(const Duration(days: 1, hours: 16)),
        deliveryStart: 18 * 60,
        deliveryEnd: 19 * 60,
        foodIds: ['food-1', 'food-3'],
      ),
    ]);
  }
  final List<VendorFoodCategory> _categories = [];
  final List<VendorFood> _foods = [];
  final List<VendorMenu> _menus = [];
  List<VendorFoodCategory> get categories => List.unmodifiable(_categories);
  List<VendorFood> get foods => List.unmodifiable(_foods);
  List<VendorMenu> get menus => List.unmodifiable(_menus);
  List<VendorMenu> menusFor(VendorMenuFilter filter, DateTime now) =>
      _menus
          .where((menu) => matchesVendorMenuFilter(menu, filter, now))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
  ({int active, int today, int draft}) menuCountsAt(DateTime now) => (
    active: menusFor(VendorMenuFilter.active, now).length,
    today: menusFor(VendorMenuFilter.today, now).length,
    draft: menusFor(VendorMenuFilter.draft, now).length,
  );
  int _nextId = 10;
  String newId(String prefix) => '$prefix-${_nextId++}';
  String categoryName(String? id) =>
      _categories.where((category) => category.id == id).firstOrNull?.name ??
      'Uncategorized';

  String? saveCategory(String name, {String? id}) {
    name = normalizedVendorName(name);
    if (name.isEmpty || name.length > 80) {
      return 'Use a category name of 1–80 characters.';
    }
    if (_categories.any(
      (category) =>
          category.id != id &&
          category.name.toLowerCase() == name.toLowerCase(),
    )) {
      return 'This category already exists.';
    }
    final index = _categories.indexWhere((category) => category.id == id);
    final category = VendorFoodCategory(id ?? newId('category'), name);
    if (index < 0) {
      _categories.add(category);
    } else {
      _categories[index] = category;
    }
    notifyListeners();
    return null;
  }

  void removeCategory(String id) {
    _categories.removeWhere((category) => category.id == id);
    for (var i = 0; i < _foods.length; i++) {
      if (_foods[i].categoryId == id) _foods[i] = _foods[i].withoutCategory();
    }
    notifyListeners();
  }

  void reorderCategory(int oldIndex, int newIndex) {
    if (oldIndex == newIndex ||
        oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= _categories.length ||
        newIndex >= _categories.length) {
      return;
    }
    final category = _categories.removeAt(oldIndex);
    _categories.insert(newIndex, category);
    notifyListeners();
  }

  String? saveFood(VendorFood food) {
    if (normalizedVendorName(food.name).isEmpty) return 'Enter a food name.';
    if (!food.price.isFinite || food.price < 0 || food.price > 99999999.99) {
      return 'Enter a valid food price.';
    }
    if (food.categoryId != null &&
        !_categories.any((category) => category.id == food.categoryId)) {
      return 'Choose an existing category.';
    }
    final groupNames = <String>{};
    for (final group in food.groups) {
      final error = validateVendorGroup(group);
      if (error != null) return error;
      if (!groupNames.add(normalizedVendorName(group.name).toLowerCase())) {
        return 'Customization groups must have different names.';
      }
    }
    final index = _foods.indexWhere((item) => item.id == food.id);
    if (index < 0) {
      _foods.add(food);
    } else {
      _foods[index] = food;
    }
    notifyListeners();
    return null;
  }

  void removeFood(String id) {
    _foods.removeWhere((food) => food.id == id);
    for (var i = 0; i < _menus.length; i++) {
      final ids = _menus[i].foodIds.where((foodId) => foodId != id).toList();
      _menus[i] = _menus[i].copyWith(
        foodIds: ids,
        isPublished: ids.isEmpty ? false : _menus[i].isPublished,
      );
    }
    notifyListeners();
  }

  String? validateMenuSchedule(VendorMenu menu) {
    if (!menu.closingAt.isAfter(menu.openingAt)) {
      return 'Ordering must close after it opens.';
    }
    if (menu.deliveryEnd <= menu.deliveryStart) {
      return 'Delivery must end after it starts.';
    }
    if (menu.deliveryStart < 0 || menu.deliveryEnd >= 24 * 60) {
      return 'Use delivery times within the menu date.';
    }
    final deliveryAt = DateTime(
      menu.date.year,
      menu.date.month,
      menu.date.day,
    ).add(Duration(minutes: menu.deliveryStart));
    if (menu.closingAt.isAfter(deliveryAt)) {
      return 'Close ordering before the delivery window starts.';
    }
    if (_menus.any(
      (other) =>
          other.id != menu.id &&
          other.session == menu.session &&
          DateUtilsForVendor.sameDay(other.date, menu.date),
    )) {
      return 'A menu already exists for this date and meal session.';
    }
    return null;
  }

  String? validateMenu(VendorMenu menu) {
    final scheduleError = validateMenuSchedule(menu);
    if (scheduleError != null) return scheduleError;
    if (menu.foodIds.isEmpty) return 'Select at least one food item.';
    if (menu.foodIds.any((id) => !_foods.any((food) => food.id == id))) {
      return 'A selected food item is no longer available.';
    }
    if (menu.unavailableFoodIds.any((id) => !menu.foodIds.contains(id))) {
      return 'Availability can only be set for selected food items.';
    }
    return null;
  }

  String? saveMenu(VendorMenu menu) {
    final error = validateMenu(menu);
    if (error != null) return error;
    final index = _menus.indexWhere((other) => other.id == menu.id);
    if (index < 0) {
      _menus.add(menu);
    } else {
      _menus[index] = menu;
    }
    notifyListeners();
    return null;
  }

  String? setPublished(String id, bool published) {
    final menu = _menus.firstWhere((menu) => menu.id == id);
    return saveMenu(menu.copyWith(isPublished: published));
  }

  String? closeMenuOrders(String id, DateTime now) {
    final menu = _menus.firstWhere((menu) => menu.id == id);
    if (!matchesVendorMenuFilter(menu, VendorMenuFilter.active, now)) {
      return 'This menu is not open for orders.';
    }
    return saveMenu(menu.copyWith(closingAt: now));
  }

  void removeMenu(String id) {
    _menus.removeWhere((menu) => menu.id == id);
    notifyListeners();
  }

  int removeExpiredClosedMenus(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final before = _menus.length;
    _menus.removeWhere(
      (menu) =>
          menu.isPublished &&
          DateTime(
            menu.date.year,
            menu.date.month,
            menu.date.day,
          ).isBefore(today) &&
          !now.isBefore(menu.closingAt),
    );
    final removed = before - _menus.length;
    if (removed > 0) notifyListeners();
    return removed;
  }
}

abstract final class DateUtilsForVendor {
  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
