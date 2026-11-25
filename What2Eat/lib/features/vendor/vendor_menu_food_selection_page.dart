import 'package:flutter/material.dart';

import 'vendor_catalog.dart';
import 'vendor_ui.dart';

class VendorMenuFoodSelectionPage extends StatefulWidget {
  const VendorMenuFoodSelectionPage({
    super.key,
    required this.catalog,
    required this.draft,
    required this.selection,
    this.unavailableSelection,
  });

  final VendorCatalog catalog;
  final VendorMenu draft;
  // Shared only with the unsaved editor so Back preserves the selection.
  final Set<String> selection;
  final Set<String>? unavailableSelection;

  @override
  State<VendorMenuFoodSelectionPage> createState() =>
      _VendorMenuFoodSelectionPageState();
}

class _VendorMenuFoodSelectionPageState
    extends State<VendorMenuFoodSelectionPage> {
  String? _error;
  String? _category;
  late final Set<String> _unavailable =
      widget.unavailableSelection ?? widget.draft.unavailableFoodIds.toSet();

  void _save({required bool publish}) {
    final error = widget.catalog.saveMenu(
      widget.draft.copyWith(
        foodIds: widget.selection.toList(),
        unavailableFoodIds: _unavailable
            .where(widget.selection.contains)
            .toList(),
        isPublished: publish,
      ),
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, true);
  }

  Widget _foodCard(VendorFood food) {
    final selected = widget.selection.contains(food.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: selected ? VendorColors.sage : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? VendorColors.green : VendorColors.line,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            CheckboxListTile(
              key: ValueKey('menu-food-${food.id}'),
              value: selected,
              contentPadding: const EdgeInsets.all(12),
              controlAffinity: ListTileControlAffinity.trailing,
              title: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VendorFoodImage(
                    bytes: food.imageBytes,
                    asset: food.assetImage,
                    size: 64,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          food.name,
                          style: vendorText(16, weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'RM ${food.price.toStringAsFixed(2)}',
                          style: vendorText(15),
                        ),
                        Text(
                          widget.catalog.categoryName(food.categoryId),
                          style: vendorText(13, color: VendorColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              onChanged: (value) => setState(() {
                if (value == true) {
                  widget.selection.add(food.id);
                } else {
                  widget.selection.remove(food.id);
                  _unavailable.remove(food.id);
                }
                _error = null;
              }),
            ),
            if (selected) ...[
              const Divider(
                height: 1,
                indent: 12,
                endIndent: 12,
                color: VendorColors.line,
              ),
              SwitchListTile.adaptive(
                key: ValueKey('menu-food-availability-${food.id}'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                title: Text(
                  'Availability',
                  style: vendorText(14, weight: FontWeight.w500),
                ),
                subtitle: Text(
                  _unavailable.contains(food.id) ? 'Sold out' : 'Available',
                  style: vendorText(13, color: VendorColors.muted),
                ),
                value: !_unavailable.contains(food.id),
                activeTrackColor: VendorColors.green,
                onChanged: (available) => setState(() {
                  if (available) {
                    _unavailable.remove(food.id);
                  } else {
                    _unavailable.add(food.id);
                  }
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: VendorColors.cream,
    appBar: AppBar(
      title: const Text('Menu food items'),
      backgroundColor: VendorColors.cream,
    ),
    body: SingleChildScrollView(
      key: const ValueKey('menu-food-scroll'),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Select food items',
                style: vendorText(20, weight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose which items customers can order from this menu.',
                style: vendorText(14, color: VendorColors.muted),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    shape: const StadiumBorder(),
                    key: const ValueKey('menu-category-all'),
                    label: const Text('All'),
                    selected: _category == null,
                    onSelected: (_) => setState(() => _category = null),
                  ),
                  for (final category in widget.catalog.categories)
                    ChoiceChip(
                      shape: const StadiumBorder(),
                      key: ValueKey('menu-category-${category.id}'),
                      label: Text(category.name),
                      selected: _category == category.id,
                      onSelected: (_) =>
                          setState(() => _category = category.id),
                    ),
                  if (widget.catalog.foods.any(
                    (food) => food.categoryId == null,
                  ))
                    ChoiceChip(
                      shape: const StadiumBorder(),
                      key: const ValueKey('menu-category-uncategorized'),
                      label: const Text('Uncategorized'),
                      selected: _category == '',
                      onSelected: (_) => setState(() => _category = ''),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${widget.selection.length} selected',
                style: vendorText(14),
              ),
              const SizedBox(height: 12),
              if (widget.catalog.foods.isEmpty)
                const Text('Add a food item in Food before creating a menu.'),
              if (widget.catalog.foods.isNotEmpty &&
                  !widget.catalog.foods.any(
                    (food) =>
                        _category == null ||
                        (food.categoryId ?? '') == _category,
                  ))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No food items in this category yet.',
                    style: vendorText(14, color: VendorColors.muted),
                  ),
                ),
              for (final food in widget.catalog.foods)
                if (_category == null || (food.categoryId ?? '') == _category)
                  _foodCard(food),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('save-menu'),
                      style: vendorActionStyle(),
                      onPressed: () => _save(publish: false),
                      child: const Text('Save draft'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('publish-menu'),
                      style: vendorActionStyle(
                        background: VendorColors.gold,
                        foreground: VendorColors.ink,
                      ),
                      onPressed: () => _save(publish: true),
                      child: const Text('Publish'),
                    ),
                  ),
                ],
              ),
              const VendorPreviewNote(),
            ],
          ),
        ),
      ),
    ),
  );
}
