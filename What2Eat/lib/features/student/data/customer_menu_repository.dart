import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer_discovery_models.dart';
import 'customer_discovery_repository.dart';

class MenuBrowseFailure implements Exception {
  const MenuBrowseFailure(this.message);
  final String message;
}

class CustomerMenuRepository {
  CustomerMenuRepository({this.client, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final SupabaseClient? client;
  final DateTime Function() _now;

  Future<CustomerMenu> loadMenu({
    required String vendorId,
    required String menuId,
  }) async {
    try {
      return await _load(vendorId, menuId).timeout(const Duration(seconds: 20));
    } on MenuBrowseFailure {
      rethrow;
    } on Exception {
      throw const MenuBrowseFailure(
        'Could not load this menu. Please try again.',
      );
    }
  }

  Future<CustomerMenu> _load(String vendorId, String menuId) async {
    final supabase = client ?? Supabase.instance.client;
    final row = await supabase
        .from('menus')
        .select(
          'id,vendor_id,menu_date,meal_session,order_opening_at,order_closing_at,'
          'delivery_start_time,delivery_end_time,vendor:vendors!inner(status,is_active)',
        )
        .eq('id', menuId)
        .eq('vendor_id', vendorId)
        .eq('is_published', true)
        .eq('vendor.status', 'approved')
        .eq('vendor.is_active', true)
        .maybeSingle();
    if (row == null) {
      throw const MenuBrowseFailure('This menu is no longer available.');
    }
    final session =
        CustomerDiscoveryRepository.sessionsById[row['meal_session']];
    if (session == null) {
      throw const MenuBrowseFailure('This meal session is unavailable.');
    }
    final window = MenuSessionWindow(
      menuId: row['id'] as String,
      session: session,
      menuDate: DateTime.parse(row['menu_date'] as String),
      orderOpeningAt: DateTime.parse(row['order_opening_at'] as String)
          .toLocal(),
      orderClosingAt: DateTime.parse(row['order_closing_at'] as String)
          .toLocal(),
    );
    if (!window.isOpenAt(_now())) {
      throw MenuBrowseFailure(
        window.statusAt(_now()) == MenuOrderStatus.closed
            ? 'Ordering for this meal session has closed.'
            : 'This meal session is not open yet.',
      );
    }

    final rows = await supabase
        .from('menu_items')
        .select(
          'is_available,food:food_items(id,vendor_id,name,description,price,image_url,'
          'category:food_categories(id,name,display_order))',
        )
        .eq('menu_id', menuId)
        .order('created_at')
        .order('id');
    final items = <MenuItem>[];
    final categoryOrder = <String, int>{};
    for (final entry in rows) {
      final food = entry['food'] as Map<String, dynamic>?;
      if (food == null || food['vendor_id'] != vendorId) continue;
      final category = food['category'] as Map<String, dynamic>?;
      final categoryName = category?['name'] as String? ?? 'Uncategorized';
      categoryOrder[categoryName] =
          (category?['display_order'] as num?)?.toInt() ?? 2147483647;
      items.add(
        MenuItem(
          id: food['id'] as String,
          vendorId: vendorId,
          sessionIds: [session.id],
          name: food['name'] as String,
          description: food['description'] as String? ?? '',
          price: (food['price'] as num).toDouble(),
          imageUrl: food['image_url'] as String?,
          category: categoryName,
          isAvailable: entry['is_available'] == true,
        ),
      );
    }
    items.sort((a, b) {
      final order = categoryOrder[a.category]!.compareTo(
        categoryOrder[b.category]!,
      );
      if (order != 0) return order;
      final category = a.category.compareTo(b.category);
      return category != 0 ? category : a.name.compareTo(b.name);
    });
    // Loading may cross the closing time: do not expose an expired menu.
    if (!window.isOpenAt(_now())) {
      throw const MenuBrowseFailure(
        'Ordering for this meal session has closed.',
      );
    }
    String time(dynamic value) => value.toString().substring(0, 5);
    return CustomerMenu(
      window: window,
      items: items,
      deliveryTimeRange:
          '${time(row['delivery_start_time'])} – ${time(row['delivery_end_time'])}',
    );
  }
}
