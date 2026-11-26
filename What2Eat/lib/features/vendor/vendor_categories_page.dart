import 'package:flutter/material.dart';

import 'vendor_catalog.dart';
import 'vendor_ui.dart';

Future<void> showVendorCategoryDialog(
  BuildContext context,
  VendorCatalog catalog, {
  VendorFoodCategory? category,
}) => showDialog<void>(
  context: context,
  builder: (_) => Theme(
    data: vendorThemeData(context),
    child: _CategoryDialog(catalog: catalog, category: category),
  ),
);

class VendorCategoriesPage extends StatefulWidget {
  const VendorCategoriesPage({
    super.key,
    required this.catalog,
    this.showHeading = true,
  });
  final VendorCatalog catalog;
  final bool showHeading;

  @override
  VendorCategoriesPageState createState() => VendorCategoriesPageState();
}

class VendorCategoriesPageState extends State<VendorCategoriesPage> {
  final Map<String, String> _edited = {};
  final Map<String, String> _errors = {};

  bool _saveCategory(VendorFoodCategory category) {
    if (!_edited.containsKey(category.id)) return true;
    final error = widget.catalog.saveCategory(
      _edited[category.id]!,
      id: category.id,
    );
    setState(() {
      if (error == null) {
        _edited.remove(category.id);
        _errors.remove(category.id);
      } else {
        _errors[category.id] = error;
      }
    });
    return error == null;
  }

  bool saveChanges() {
    var valid = true;
    for (final category in widget.catalog.categories) {
      if (!_saveCategory(category)) valid = false;
    }
    return valid;
  }

  Future<void> _edit(BuildContext context, [VendorFoodCategory? category]) =>
      showVendorCategoryDialog(context, widget.catalog, category: category);

  Future<void> _remove(
    BuildContext context,
    VendorFoodCategory category,
  ) async {
    if (await vendorConfirm(
      context,
      title: 'Remove category?',
      message:
          'Remove “${category.name}” from this preview? Its food items will become Uncategorized. No food items will be deleted.',
      action: 'Remove',
    )) {
      widget.catalog.removeCategory(category.id);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.showHeading) ...[
        VendorSectionTitle(
          'Food categories',
          action: IconButton(
            tooltip: 'Add category',
            onPressed: () => _edit(context),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ),
        Text(
          'Organize your food cards so customers can browse your menu easily.',
          style: vendorText(14, color: VendorColors.muted),
        ),
        const SizedBox(height: 20),
      ],
      if (widget.catalog.categories.isEmpty)
        const VendorPanel(
          child: Text('No categories yet. Tap + to add your first category.'),
        ),
      ReorderableListView.builder(
        shrinkWrap: true,
        primary: false,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        buildDefaultDragHandles: false,
        onReorderItem: widget.catalog.reorderCategory,
        itemCount: widget.catalog.categories.length,
        itemBuilder: (context, index) {
          final category = widget.catalog.categories[index];
          return Padding(
            key: ValueKey('category-row-${category.id}'),
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                VendorReorderHandle(
                  key: ValueKey('reorder-category-${category.id}'),
                  index: index,
                  label: category.name,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('edit-category-name-${category.id}'),
                    initialValue: category.name,
                    maxLength: 80,
                    style: vendorText(16),
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: 'Category name',
                      counterText: '',
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: VendorColors.green),
                      ),
                      errorText: _errors[category.id],
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (value) => setState(() {
                      _edited[category.id] = value;
                      _errors.remove(category.id);
                    }),
                    onFieldSubmitted: (_) {
                      if (_saveCategory(category)) {
                        FocusScope.of(context).unfocus();
                      }
                    },
                    onTapOutside: (_) {
                      _saveCategory(category);
                      FocusScope.of(context).unfocus();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: ValueKey('remove-category-${category.id}'),
                  tooltip: 'Delete ${category.name}',
                  icon: const Icon(
                    Icons.delete_outline,
                    color: VendorColors.danger,
                  ),
                  onPressed: () => _remove(context, category),
                ),
              ],
            ),
          );
        },
      ),
    ],
  );
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({required this.catalog, this.category});
  final VendorCatalog catalog;
  final VendorFoodCategory? category;
  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _form = GlobalKey<FormState>();
  late String _name = widget.category?.name ?? '';
  String? _error;
  void _save() {
    if (!_form.currentState!.validate()) return;
    final error = widget.catalog.saveCategory(_name, id: widget.category?.id);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.category == null ? 'Add category' : 'Edit category'),
    scrollable: true,
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            key: const ValueKey('category-name'),
            initialValue: _name,
            maxLength: 80,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Category name'),
            onChanged: (value) => _name = value,
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Enter a category name.' : null,
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save')),
    ],
  );
}
