import 'package:flutter/material.dart';

import '../data/customer_menu_repository.dart';
import '../models/customer_discovery_models.dart';
import '../theme/what2eat_theme.dart';

class CustomerFoodDetailsSheet extends StatefulWidget {
  const CustomerFoodDetailsSheet({
    super.key,
    required this.vendorId,
    required this.menuId,
    required this.foodId,
    required this.repository,
  });
  final String vendorId, menuId, foodId;
  final CustomerMenuRepository repository;

  @override
  State<CustomerFoodDetailsSheet> createState() =>
      _CustomerFoodDetailsSheetState();
}

class _CustomerFoodDetailsSheetState extends State<CustomerFoodDetailsSheet> {
  MenuItem? _food;
  String? _error;
  bool _loading = true;
  final _choices = <String, Set<String>>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final food = await widget.repository.loadFood(
        vendorId: widget.vendorId,
        menuId: widget.menuId,
        foodId: widget.foodId,
      );
      if (!mounted) return;
      setState(() {
        _food = food;
        _choices.clear();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is MenuBrowseFailure
            ? error.message
            : 'Could not load this food item. Please try again.';
      });
    }
  }

  int _minimum(CustomizationGroup group) =>
      group.minSelections ?? (group.isRequired ? 1 : 0);
  int _maximum(CustomizationGroup group) =>
      group.maxSelections ?? (group.allowMultiple ? group.options.length : 1);

  int get _priceCents {
    final food = _food!;
    var cents = (food.price * 100).round();
    for (final group in food.customizationGroups) {
      for (final option in group.options) {
        if (_choices[group.id]?.contains(option.id) == true) {
          cents += (option.priceDelta * 100).round();
        }
      }
    }
    return cents;
  }

  bool get _complete => _food!.customizationGroups.every(
    (group) => (_choices[group.id]?.length ?? 0) >= _minimum(group),
  );

  void _choose(CustomizationGroup group, CustomizationOption option) {
    if (_food?.isAvailable != true || !option.isAvailable) return;
    final current = Set<String>.from(_choices[group.id] ?? <String>{});
    if (current.contains(option.id)) {
      current.remove(option.id);
    } else if (_maximum(group) == 1) {
      current
        ..clear()
        ..add(option.id);
    } else if (current.length < _maximum(group)) {
      current.add(option.id);
    } else {
      return;
    }
    setState(() => _choices[group.id] = current);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .86,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Food details',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: What2EatTheme.mutedText,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close food details',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            TextButton(
                              onPressed: _load,
                              child: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : _content(),
          ),
          if (_food != null && !_loading && _error == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: What2EatTheme.border)),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 4,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Price preview',
                        style: TextStyle(color: What2EatTheme.mutedText),
                      ),
                      Text(
                        _food!.isAvailable
                            ? (_complete
                                  ? 'Choices complete'
                                  : 'Choose required options')
                            : 'Sold out',
                        style: const TextStyle(
                          color: What2EatTheme.darkGreenText,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: What2EatTheme.goldenYellow,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'RM ${(_priceCents / 100).toStringAsFixed(2)}',
                      key: const ValueKey('food-price-preview'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: What2EatTheme.darkGreenText,
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

  Widget _content() {
    final food = _food!;
    return ListView(
      key: const ValueKey('food-details-content'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        _banner(food),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final name = Text(
              food.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: What2EatTheme.darkGreenText,
              ),
            );
            final price = Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: What2EatTheme.softYellowBadge,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'RM ${food.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: What2EatTheme.darkGreenText,
                ),
              ),
            );
            if (constraints.maxWidth < 320 ||
                MediaQuery.textScalerOf(context).scale(15) > 20) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [name, const SizedBox(height: 8), price],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: name),
                const SizedBox(width: 12),
                price,
              ],
            );
          },
        ),
        if (!food.isAvailable)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Sold out · Options unavailable'),
          ),
        if (food.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              food.description,
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.5,
                color: What2EatTheme.mutedText,
              ),
            ),
          ),
        const SizedBox(height: 20),
        if (food.customizationGroups.isEmpty)
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
                    'Prepared as standard. No customization needed.',
                    style: TextStyle(
                      fontSize: 14,
                      color: What2EatTheme.mutedText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        for (final group in food.customizationGroups) _group(group),
      ],
    );
  }

  Widget _banner(MenuItem food) => Container(
    height: 150,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [What2EatTheme.forestGreen, What2EatTheme.sageGreen],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(18),
    ),
    child: food.imageUrl?.isNotEmpty == true
        ? Image.network(
            food.imageUrl!,
            width: double.infinity,
            height: 150,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _bannerFallback(),
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : _bannerFallback(),
          )
        : _bannerFallback(),
  );

  Widget _bannerFallback() => Stack(
    children: [
      Positioned(
        right: -16,
        bottom: -16,
        child: Icon(
          Icons.restaurant_menu,
          size: 130,
          color: Colors.white.withValues(alpha: .12),
        ),
      ),
      Center(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: What2EatTheme.goldenYellow,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.fastfood_rounded,
            size: 32,
            color: What2EatTheme.darkGreenText,
          ),
        ),
      ),
    ],
  );

  Widget _group(CustomizationGroup group) {
    final min = _minimum(group), max = _maximum(group);
    final selected = _choices[group.id] ?? <String>{};
    final rule = min == 0
        ? 'Choose up to $max'
        : min == max
        ? 'Choose $min'
        : 'Choose $min–$max';
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
          LayoutBuilder(
            builder: (context, constraints) {
              final title = Text(
                group.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: What2EatTheme.darkGreenText,
                ),
              );
              final badge = Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: min > 0
                      ? What2EatTheme.softYellowBadge
                      : What2EatTheme.softSurface,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  min > 0 ? 'Required' : 'Optional',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: What2EatTheme.darkGreenText,
                  ),
                ),
              );
              if (constraints.maxWidth < 260 ||
                  MediaQuery.textScalerOf(context).scale(12) > 18) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 8), badge],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 8),
                  badge,
                ],
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            '$rule · ${selected.length} selected',
            style: const TextStyle(
              fontSize: 13,
              color: What2EatTheme.subtleText,
            ),
          ),
          if (selected.length < min)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Choose ${min - selected.length} more',
                style: const TextStyle(
                  fontSize: 13,
                  color: What2EatTheme.mutedText,
                ),
              ),
            ),
          const SizedBox(height: 10),
          if (group.options.isEmpty) const Text('No options available'),
          for (final option in group.options)
            _FoodChoiceTile(
              key: ValueKey('food-option-${option.id}'),
              option: option,
              selected: selected.contains(option.id),
              multiple: max > 1,
              onTap:
                  !_food!.isAvailable ||
                      !option.isAvailable ||
                      (max > 1 &&
                          selected.length >= max &&
                          !selected.contains(option.id))
                  ? null
                  : () => _choose(group, option),
            ),
        ],
      ),
    );
  }
}

class _FoodChoiceTile extends StatelessWidget {
  const _FoodChoiceTile({
    super.key,
    required this.option,
    required this.selected,
    required this.multiple,
    this.onTap,
  });
  final CustomizationOption option;
  final bool selected, multiple;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    checked: selected,
    enabled: onTap != null,
    inMutuallyExclusiveGroup: !multiple,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? What2EatTheme.softSurfaceAlt
            : What2EatTheme.creamBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? What2EatTheme.forestGreen : What2EatTheme.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      multiple
                          ? (selected
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded)
                          : (selected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded),
                      size: 21,
                      color: selected
                          ? What2EatTheme.forestGreen
                          : What2EatTheme.subtleText,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Text(
                      option.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: onTap == null
                            ? What2EatTheme.subtleText
                            : What2EatTheme.darkGreenText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text(
                      !option.isAvailable
                          ? 'Unavailable'
                          : option.priceDelta > 0
                          ? '+ RM ${option.priceDelta.toStringAsFixed(2)}'
                          : 'Included',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: option.priceDelta > 0
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: onTap == null
                            ? What2EatTheme.subtleText
                            : option.priceDelta > 0
                            ? What2EatTheme.forestGreen
                            : What2EatTheme.subtleText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
