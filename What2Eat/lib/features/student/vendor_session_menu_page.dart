import 'dart:async';

import 'package:flutter/material.dart';

import 'data/customer_menu_repository.dart';
import 'models/customer_discovery_models.dart';
import 'theme/what2eat_theme.dart';
import 'widgets/menu_food_image.dart';

class VendorSessionMenuPage extends StatefulWidget {
  const VendorSessionMenuPage({
    super.key,
    required this.vendor,
    required this.menu,
    this.repository,
  });
  final VendorProfile vendor;
  final MenuSessionWindow menu;
  final CustomerMenuRepository? repository;

  @override
  State<VendorSessionMenuPage> createState() => _VendorSessionMenuPageState();
}

class _VendorSessionMenuPageState extends State<VendorSessionMenuPage>
    with WidgetsBindingObserver {
  late final _repository = widget.repository ?? CustomerMenuRepository();
  CustomerMenu? _menu;
  String? _category, _error;
  bool _loading = true;
  Timer? _closing;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _closing?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    _closing?.cancel();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final menu = await _repository.loadMenu(
        vendorId: widget.vendor.id,
        menuId: widget.menu.menuId,
      );
      if (!mounted || request != _request) return;
      if (!menu.window.isOpenAt(DateTime.now())) {
        throw const MenuBrowseFailure('This meal session is not open.');
      }
      setState(() {
        _menu = menu;
        if (!menu.items.any((item) => item.category == _category)) {
          _category = null;
        }
        _loading = false;
      });
      final remaining = menu.window.orderClosingAt.difference(DateTime.now());
      _closing = Timer(
        remaining.isNegative ? Duration.zero : remaining,
        _expire,
      );
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _menu = null;
        _loading = false;
        _error = error is MenuBrowseFailure
            ? error.message
            : 'Could not load this menu. Please try again.';
      });
    }
  }

  void _expire() {
    if (!mounted) return;
    setState(() {
      _menu = null;
      _error = 'Ordering for this meal session has closed.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final menu = _menu;
    final categories =
        menu?.items.map((item) => item.category).toSet() ?? <String>{};
    final items =
        menu?.items
            .where((item) => _category == null || item.category == _category)
            .toList() ??
        <MenuItem>[];
    return Scaffold(
      backgroundColor: What2EatTheme.creamBackground,
      appBar: AppBar(
        backgroundColor: What2EatTheme.creamBackground,
        foregroundColor: What2EatTheme.darkGreenText,
        title: Text(
          '${widget.menu.session.name} Menu',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh menu',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                key: const ValueKey('digital-menu'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  Text(
                    widget.vendor.businessName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: What2EatTheme.darkGreenText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${menu!.window.menuDate.day}/${menu.window.menuDate.month}/${menu.window.menuDate.year}',
                    style: const TextStyle(
                      color: What2EatTheme.mutedText,
                      height: 1.5,
                    ),
                  ),
                  Text(
                    'Ordering closes ${_time(menu.window.orderClosingAt)}',
                    style: const TextStyle(
                      color: What2EatTheme.mutedText,
                      height: 1.5,
                    ),
                  ),
                  Text(
                    'Estimated delivery ${menu.deliveryTimeRange}',
                    style: const TextStyle(
                      color: What2EatTheme.mutedText,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (categories.isNotEmpty) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filter('All', null),
                          for (final category in categories)
                            _filter(category, category),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'No dishes published for this meal session yet.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final item in items) _FoodItemCard(item: item),
                ],
              ),
            ),
    );
  }

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  Widget _filter(String label, String? value) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: FilterChip(
      selected: _category == value,
      onSelected: (_) => setState(() => _category = value),
      label: Text(label),
      selectedColor: What2EatTheme.softSurface,
      backgroundColor: Colors.white,
      checkmarkColor: What2EatTheme.forestGreen,
      labelStyle: const TextStyle(color: What2EatTheme.darkGreenText),
      side: const BorderSide(color: What2EatTheme.border),
      shape: const StadiumBorder(),
    ),
  );
}

class _FoodItemCard extends StatelessWidget {
  const _FoodItemCard({required this.item});
  final MenuItem item;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: What2EatTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        key: ValueKey('menu-food-${item.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: MenuFoodImage(item: item, size: 72),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: What2EatTheme.darkGreenText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: What2EatTheme.goldenYellow,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'RM ${item.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: What2EatTheme.darkGreenText,
                            ),
                          ),
                        ),
                        if (!item.isAvailable)
                          const Text(
                            'Sold out',
                            style: TextStyle(color: What2EatTheme.mutedText),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
