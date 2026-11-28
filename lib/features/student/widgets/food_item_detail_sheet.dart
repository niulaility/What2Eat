import 'package:flutter/material.dart';

import '../models/customer_discovery_models.dart';
import '../theme/what2eat_theme.dart';

class FoodItemDetailSheet extends StatefulWidget {
  const FoodItemDetailSheet({
    super.key,
    required this.item,
    required this.session,
    this.selectedDate,
  });

  final MenuItem item;
  final MealSession session;
  final DateTime? selectedDate;

  @override
  State<FoodItemDetailSheet> createState() => _FoodItemDetailSheetState();
}

class _FoodItemDetailSheetState extends State<FoodItemDetailSheet> {
  final Map<String, Set<String>> _selectedOptionsByGroup = {};
  final TextEditingController _notesController = TextEditingController();
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    for (final group in widget.item.customizationGroups) {
      final defaults = group.options
          .where((o) => o.isDefault)
          .map((o) => o.id)
          .toSet();
      if (defaults.isNotEmpty) {
        _selectedOptionsByGroup[group.id] = defaults;
      } else if (group.isRequired && group.options.isNotEmpty) {
        _selectedOptionsByGroup[group.id] = {group.options.first.id};
      } else {
        _selectedOptionsByGroup[group.id] = <String>{};
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double get _unitPrice {
    double extra = 0;
    for (final group in widget.item.customizationGroups) {
      final selectedIds = _selectedOptionsByGroup[group.id] ?? const <String>{};
      for (final option in group.options) {
        if (selectedIds.contains(option.id)) {
          extra += option.priceDelta;
        }
      }
    }
    return widget.item.price + extra;
  }

  bool get _allRequiredSatisfied {
    for (final group in widget.item.customizationGroups) {
      if (group.isRequired) {
        final selected = _selectedOptionsByGroup[group.id] ?? const <String>{};
        if (selected.isEmpty) return false;
      }
    }
    return true;
  }

  void _toggleOption(CustomizationGroup group, CustomizationOption option) {
    setState(() {
      final current =
          Set<String>.from(_selectedOptionsByGroup[group.id] ?? const {});
      if (!group.allowMultiple) {
        current
          ..clear()
          ..add(option.id);
      } else {
        if (current.contains(option.id)) {
          current.remove(option.id);
        } else {
          if (group.maxSelections != null &&
              current.length >= group.maxSelections!) {
            return;
          }
          current.add(option.id);
        }
      }
      _selectedOptionsByGroup[group.id] = current;
    });
  }

  void _confirmSelection() {
    if (!_allRequiredSatisfied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all required customization options.'),
        ),
      );
      return;
    }

    final labels = <String>[];
    for (final group in widget.item.customizationGroups) {
      final selectedIds = _selectedOptionsByGroup[group.id] ?? const <String>{};
      for (final option in group.options) {
        if (selectedIds.contains(option.id)) {
          labels.add(option.name);
        }
      }
    }

    final result = SelectedCartItem(
      item: widget.item,
      session: widget.session,
      selectedDate: widget.selectedDate,
      quantity: _quantity,
      unitPrice: _unitPrice,
      selectedOptionLabels: labels,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final total = _unitPrice * _quantity;

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Container(
            decoration: const BoxDecoration(
              color: What2EatTheme.creamBackground,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: What2EatTheme.divider,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Expanded(
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    _buildHeaderBanner(),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            widget.item.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: What2EatTheme.darkGreenText,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: What2EatTheme.softYellowBadge,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'RM ${widget.item.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: What2EatTheme.darkGreenText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.item.description,
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.5,
                        color: What2EatTheme.mutedText,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (widget.item.customizationGroups.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: What2EatTheme.border),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: What2EatTheme.oliveAccent,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Prepared as standard by the vendor. No extra customization required.',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: What2EatTheme.mutedText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      for (final group in widget.item.customizationGroups)
                        _buildCustomizationGroup(group),
                    const SizedBox(height: 12),
                    const Text(
                      'Special Instructions (Optional)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: What2EatTheme.darkGreenText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      maxLines: 2,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                      onTapOutside: (_) => FocusScope.of(context).unfocus(),
                      decoration: InputDecoration(
                        hintText: 'E.g. Less spicy, pack sauce separately...',
                        hintStyle: const TextStyle(
                          fontSize: 13.5,
                          color: What2EatTheme.hintText,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: What2EatTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: What2EatTheme.border),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  14,
                  20,
                  14 + MediaQuery.of(context).padding.bottom,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: What2EatTheme.border),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: What2EatTheme.softSurface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _quantity > 1
                                ? () => setState(() => _quantity--)
                                : null,
                            icon: const Icon(Icons.remove, size: 18),
                            color: What2EatTheme.darkGreenText,
                          ),
                          Text(
                            '$_quantity',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: What2EatTheme.darkGreenText,
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(() => _quantity++),
                            icon: const Icon(Icons.add, size: 18),
                            color: What2EatTheme.darkGreenText,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: FilledButton(
                        onPressed:
                            _allRequiredSatisfied ? _confirmSelection : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: What2EatTheme.goldenYellow,
                          foregroundColor: What2EatTheme.darkGreenText,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Add • RM ${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [What2EatTheme.forestGreen, What2EatTheme.sageGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            bottom: -16,
            child: Icon(
              Icons.restaurant_menu,
              size: 130,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: What2EatTheme.goldenYellow.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fastfood_rounded,
                    size: 32,
                    color: What2EatTheme.darkGreenText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomizationGroup(CustomizationGroup group) {
    final selectedIds = _selectedOptionsByGroup[group.id] ?? const <String>{};

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: What2EatTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: What2EatTheme.darkGreenText,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: group.isRequired
                      ? What2EatTheme.softYellowBadge
                      : What2EatTheme.softSurface,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  group.isRequired
                      ? 'Required'
                      : (group.allowMultiple ? 'Optional • Multi' : 'Optional'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: group.isRequired
                        ? What2EatTheme.darkGreenText
                        : What2EatTheme.mutedText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            group.allowMultiple
                ? 'Choose one or more options'
                : 'Select 1 option',
            style: const TextStyle(
              fontSize: 12.5,
              color: What2EatTheme.subtleText,
            ),
          ),
          const SizedBox(height: 10),
          for (final option in group.options)
            _CustomizationOptionTile(
              option: option,
              isSelected: selectedIds.contains(option.id),
              allowMultiple: group.allowMultiple,
              onTap: () => _toggleOption(group, option),
            ),
        ],
      ),
    );
  }
}

class _CustomizationOptionTile extends StatelessWidget {
  const _CustomizationOptionTile({
    required this.option,
    required this.isSelected,
    required this.allowMultiple,
    required this.onTap,
  });

  final CustomizationOption option;
  final bool isSelected;
  final bool allowMultiple;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected
              ? What2EatTheme.softSurfaceAlt
              : What2EatTheme.creamBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected ? What2EatTheme.forestGreen : What2EatTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              allowMultiple
                  ? (isSelected
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded)
                  : (isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded),
              size: 21,
              color: isSelected
                  ? What2EatTheme.forestGreen
                  : What2EatTheme.subtleText,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: What2EatTheme.darkGreenText,
                ),
              ),
            ),
            Text(
              option.priceDelta > 0
                  ? '+RM ${option.priceDelta.toStringAsFixed(2)}'
                  : 'Included',
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    option.priceDelta > 0 ? FontWeight.w700 : FontWeight.w500,
                color: option.priceDelta > 0
                    ? What2EatTheme.forestGreen
                    : What2EatTheme.subtleText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
