import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:what2eat_starter/features/student/data/customer_menu_repository.dart';

void main() {
  final now = DateTime.utc(2026, 11, 27, 4);
  Map<String, dynamic> menu({int offset = 0}) => {
    'id': 'menu',
    'vendor_id': 'vendor',
    'meal_session': 'lunch',
    'menu_date': '2026-11-27',
    'order_opening_at': now.add(Duration(hours: offset - 1)).toIso8601String(),
    'order_closing_at': now.add(Duration(hours: offset + 1)).toIso8601String(),
    'delivery_start_time': '12:30:00',
    'delivery_end_time': '13:00:00',
    'vendor': {'status': 'approved', 'is_active': true},
  };
  Map<String, dynamic> food(
    String id, {
    String vendor = 'vendor',
    bool available = true,
  }) => {
    'is_available': available,
    'food': {
      'id': id,
      'vendor_id': vendor,
      'name': 'Rice $id',
      'description': null,
      'price': 8.5,
      'image_url': null,
      'category': {'id': 'rice', 'name': 'Rice', 'display_order': 1},
      'groups': [
        {
          'id': 'late',
          'name': 'Add-ons',
          'min_selectable': 0,
          'max_selectable': 2,
          'display_order': 2,
          'options': [
            {
              'id': 'unavailable',
              'name': 'Unavailable',
              'additional_price': 0,
              'is_available': false,
              'display_order': 0,
            },
            {
              'id': 'egg',
              'name': 'Egg',
              'additional_price': 1.5,
              'is_available': true,
              'display_order': 1,
            },
          ],
        },
        {
          'id': 'first',
          'name': 'Spice',
          'min_selectable': 1,
          'max_selectable': 1,
          'display_order': 0,
          'options': [],
        },
      ],
    },
  };
  SupabaseClient clientFor(
    Object? row,
    List<Map<String, dynamic>> items,
    List<http.Request> requests, {
    int status = 200,
  }) {
    final client = SupabaseClient(
      'https://menu-test.invalid',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        final response = request.url.path.endsWith('/menus')
            ? (row == null ? [] : [row])
            : items;
        return http.Response(
          jsonEncode(response),
          status,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    return client;
  }

  test('Reads only selected published vendor menu and maps per-menu stock and category', () async {
    final requests = <http.Request>[];
    final client = clientFor(menu(), [
      food('sold', available: false),
      food('foreign', vendor: 'other'),
    ], requests);
    final result = await CustomerMenuRepository(
      client: client,
      now: () => now,
    ).loadMenu(vendorId: 'vendor', menuId: 'menu');
    expect(requests.every((request) => request.method == 'GET'), isTrue);
    final query = requests.first.url.queryParameters;
    expect(query['id'], 'eq.menu');
    expect(query['vendor_id'], 'eq.vendor');
    expect(query['is_published'], 'eq.true');
    expect(query['vendor.status'], 'eq.approved');
    expect(query['vendor.is_active'], 'eq.true');
    expect(requests.last.url.queryParameters['menu_id'], 'eq.menu');
    expect(
      requests.last.url.queryParameters['select'],
      isNot(contains('image_url,is_available')),
    );
    expect(result.items, hasLength(1));
    expect(result.items.single.isAvailable, isFalse);
    expect(result.deliveryTimeRange, '12:30 – 13:00');
  });

  for (final offset in [-3, 3]) {
    test('Closed or future menu does not load dishes ($offset)', () async {
      final requests = <http.Request>[];
      final client = clientFor(menu(offset: offset), [], requests);
      await expectLater(
        CustomerMenuRepository(
          client: client,
          now: () => now,
        ).loadMenu(vendorId: 'vendor', menuId: 'menu'),
        throwsA(isA<MenuBrowseFailure>()),
      );
      expect(requests, hasLength(1));
    });
  }

  test(
    'Missing, unpublished or inaccessible menu never loads sample dishes',
    () async {
      final requests = <http.Request>[];
      final client = clientFor(null, [], requests);
      await expectLater(
        CustomerMenuRepository(
          client: client,
          now: () => now,
        ).loadMenu(vendorId: 'vendor', menuId: 'menu'),
        throwsA(isA<MenuBrowseFailure>()),
      );
      expect(requests, hasLength(1));
    },
  );

  test('A menu that closes during loading is rejected', () async {
    final requests = <http.Request>[];
    final client = clientFor(menu(), [food('rice')], requests);
    var clockCalls = 0;
    await expectLater(
      CustomerMenuRepository(
        client: client,
        now: () => ++clockCalls == 1 ? now : now.add(const Duration(hours: 2)),
      ).loadMenu(vendorId: 'vendor', menuId: 'menu'),
      throwsA(isA<MenuBrowseFailure>()),
    );
    expect(requests, hasLength(2));
  });
}
