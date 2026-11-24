import 'package:flutter/material.dart';

import 'models/customer_discovery_models.dart';
import 'theme/what2eat_theme.dart';
import 'widgets/food_item_detail_sheet.dart';

class VendorSessionMenuPage extends StatefulWidget {
  const VendorSessionMenuPage({
    super.key,
    required this.vendor,
    required this.session,
    this.selectedDate,
  });

  final VendorProfile vendor;
  final MealSession session;
  final DateTime? selectedDate;

  @override
  State<VendorSessionMenuPage> createState() => _VendorSessionMenuPageState();
}

class _VendorSessionMenuPageState extends State<VendorSessionMenuPage> {
  String _selectedCategory = 'All';
  final List<SelectedCartItem> _selections = [];

  List<MenuItem> get _sessionMenu =>
      widget.vendor.menuForSession(widget.session.id);

  List<String> get _categories {
    final cats = <String>{'All'};
    for (final item in _sessionMenu) {
      cats.add(item.category);
    }
    return cats.toList();
  }

  List<MenuItem> get _filteredMenu {
    if (_selectedCategory == 'All') return _sessionMenu;
    return _sessionMenu
        .where((item) => item.category == _selectedCategory)
        .toList();
  }

  Future<void> _openFoodItemDetail(MenuItem item) async {
    final selected = await showModalBottomSheet<SelectedCartItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FoodItemDetailSheet(
        item: item,
        session: widget.session,
        selectedDate: widget.selectedDate,
      ),
    );

    if (selected == null || !mounted) return;
    setState(() {
      _selections.add(selected);
    });

    final optionsText = selected.selectedOptionLabels.isEmpty
        ? 'Standard'
        : selected.selectedOptionLabels.join(', ');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: What2EatTheme.forestGreen,
          content: Text(
            'Added ${selected.quantity}× ${selected.item.name} ($optionsText)',
          ),
        ),
      );
  }

  void _showSelectionsSummary() {
    final totalAmount = _selections.fold<double>(
      0,
      (sum, item) => sum + item.totalPrice,
    );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: What2EatTheme.creamBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Your Selected Items',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: What2EatTheme.darkGreenText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'RM ${totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: What2EatTheme.forestGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _selections.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final entry = _selections[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: What2EatTheme.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: What2EatTheme.softYellowBadge,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${entry.quantity}×',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: What2EatTheme.darkGreenText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: What2EatTheme.darkGreenText,
                                  ),
                                ),
                                if (entry.selectedOptionLabels.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      entry.selectedOptionLabels.join(' • '),
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: What2EatTheme.mutedText,
                                      ),
                                    ),
                                  ),
                                if (entry.notes != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      'Note: ${entry.notes}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: What2EatTheme.subtleText,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'RM ${entry.totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: What2EatTheme.darkGreenText,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final menu = _filteredMenu;
    final totalCount = _selections.fold<int>(0, (s, e) => s + e.quantity);
    final totalPrice =
        _selections.fold<double>(0, (s, e) => s + e.totalPrice);

    return Scaffold(
      backgroundColor: What2EatTheme.creamBackground,
      appBar: AppBar(
        backgroundColor: What2EatTheme.creamBackground,
        elevation: 0,
        foregroundColor: What2EatTheme.darkGreenText,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.session.name} Menu',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: What2EatTheme.darkGreenText,
              ),
            ),
            Text(
              '${widget.vendor.businessName} • Last order ${widget.session.lastOrderTime}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: What2EatTheme.oliveAccent,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _selections.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: _showSelectionsSummary,
                  style: FilledButton.styleFrom(
                    backgroundColor: What2EatTheme.goldenYellow,
                    foregroundColor: What2EatTheme.darkGreenText,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: What2EatTheme.forestGreen,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '$totalCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'View Customized Selections',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'RM ${totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          if (_categories.length > 2) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final cat in _categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: _selectedCategory == cat,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = cat),
                        label: Text(cat),
                        selectedColor: What2EatTheme.softSurface,
                        backgroundColor: Colors.white,
                        checkmarkColor: What2EatTheme.forestGreen,
                        labelStyle: TextStyle(
                          fontWeight: _selectedCategory == cat
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: What2EatTheme.darkGreenText,
                        ),
                        side: const BorderSide(color: What2EatTheme.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (menu.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: What2EatTheme.border),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.no_meals_outlined,
                    size: 40,
                    color: What2EatTheme.oliveAccent,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'No dishes published for this meal session yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: What2EatTheme.darkGreenText,
                    ),
                  ),
                ],
              ),
            )
          else
            for (final item in menu)
              _FoodItemCard(
                item: item,
                onTap: () => _openFoodItemDetail(item),
              ),
        ],
      ),
    );
  }
}

class _FoodItemCard extends StatelessWidget {
  const _FoodItemCard({
    required this.item,
    required this.onTap,
  });

  final MenuItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: What2EatTheme.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: What2EatTheme.softSurfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.lunch_dining_rounded,
                  size: 32,
                  color: What2EatTheme.forestGreen,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: What2EatTheme.darkGreenText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
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
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: What2EatTheme.darkGreenText,
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.add_circle_rounded,
                          color: What2EatTheme.forestGreen,
                          size: 24,
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
    );
  }
}
