import 'package:flutter/material.dart';

import 'vendor_catalog.dart';
import 'vendor_ui.dart';

class VendorFoodPreview extends StatefulWidget {
  const VendorFoodPreview({super.key, required this.food});
  final VendorFood food;
  @override
  State<VendorFoodPreview> createState() => _VendorFoodPreviewState();
}

class _VendorFoodPreviewState extends State<VendorFoodPreview> {
  final Map<String, Set<String>> _selected = {};
  bool _submitted = false;
  double get _total {
    var total = widget.food.price;
    for (final group in widget.food.groups) {
      for (final option in group.options) {
        if (_selected[group.id]?.contains(option.id) == true) {
          total += option.additionalPrice;
        }
      }
    }
    return total;
  }

  bool get _valid => widget.food.groups.every(
    (group) =>
        (_selected[group.id]?.length ?? 0) >= group.minSelectable &&
        (_selected[group.id]?.length ?? 0) <= group.maxSelectable,
  );

  void _toggle(
    VendorCustomizationGroup group,
    VendorCustomizationOption option,
    bool selected,
  ) {
    if (!option.isAvailable) return;
    setState(() {
      final values = _selected.putIfAbsent(group.id, () => <String>{});
      if (!selected) {
        values.remove(option.id);
      } else if (group.maxSelectable == 1) {
        values
          ..clear()
          ..add(option.id);
      } else if (values.length < group.maxSelectable) {
        values.add(option.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: VendorColors.cream,
    appBar: AppBar(
      title: const Text('Customer preview'),
      backgroundColor: VendorColors.cream,
    ),
    body: SingleChildScrollView(
      key: const ValueKey('food-preview-scroll'),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: VendorFoodImage(
                  bytes: widget.food.imageBytes,
                  asset: widget.food.assetImage,
                  size: 210,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.food.name,
                style: vendorText(25, weight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'RM ${widget.food.price.toStringAsFixed(2)}',
                style: vendorText(21, weight: FontWeight.w700),
              ),
              if (widget.food.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  widget.food.description,
                  style: vendorText(15, color: VendorColors.muted),
                ),
              ],
              if (!widget.food.isAvailable) ...[
                const SizedBox(height: 12),
                Text(
                  'This food item is currently unavailable.',
                  style: vendorText(15, color: Colors.red),
                ),
              ],
              const SizedBox(height: 24),
              if (widget.food.groups.isEmpty)
                const VendorPanel(
                  child: Text('No customization is required for this item.'),
                ),
              for (final group in widget.food.groups)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: VendorPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          group.name,
                          style: vendorText(20, weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          group.selectionLabel,
                          style: vendorText(14, color: VendorColors.muted),
                        ),
                        const SizedBox(height: 10),
                        for (final option in group.options)
                          CheckboxListTile(
                            key: ValueKey('preview-option-${option.id}'),
                            contentPadding: EdgeInsets.zero,
                            value:
                                _selected[group.id]?.contains(option.id) ==
                                true,
                            title: Text(option.name, style: vendorText(16)),
                            subtitle: Text(
                              !option.isAvailable
                                  ? 'Sold out'
                                  : option.additionalPrice == 0
                                  ? 'No additional charge'
                                  : '+ RM ${option.additionalPrice.toStringAsFixed(2)}',
                            ),
                            onChanged:
                                !option.isAvailable ||
                                    (group.maxSelectable > 1 &&
                                        (_selected[group.id]?.length ?? 0) >=
                                            group.maxSelectable &&
                                        _selected[group.id]?.contains(
                                              option.id,
                                            ) !=
                                            true)
                                ? null
                                : (value) =>
                                      _toggle(group, option, value ?? false),
                          ),
                        if (_submitted &&
                            (_selected[group.id]?.length ?? 0) <
                                group.minSelectable)
                          Text(
                            'Choose at least ${group.minSelectable} ${group.minSelectable == 1 ? 'option' : 'options'}.',
                            style: const TextStyle(color: Colors.red),
                          ),
                      ],
                    ),
                  ),
                ),
              const VendorPreviewNote(),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Preview total: RM ${_total.toStringAsFixed(2)}',
              key: const ValueKey('food-preview-total'),
              style: vendorText(19, weight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('confirm-food-preview'),
                onPressed: !widget.food.isAvailable
                    ? null
                    : () {
                        setState(() => _submitted = true);
                        if (_valid) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Selection preview only. No order was placed.',
                              ),
                            ),
                          );
                        }
                      },
                child: const Text('Confirm selection preview'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
