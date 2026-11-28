import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'vendor_catalog.dart';
import 'vendor_customization_editor.dart';
import 'vendor_ui.dart';

class VendorFoodEditor extends StatefulWidget {
  const VendorFoodEditor({
    super.key,
    required this.catalog,
    this.food,
    this.initialCategoryId,
    this.pickImage,
  });
  final VendorCatalog catalog;
  final VendorFood? food;
  final String? initialCategoryId;
  final Future<XFile?> Function()? pickImage;
  @override
  State<VendorFoodEditor> createState() => _VendorFoodEditorState();
}

class _VendorFoodEditorState extends State<VendorFoodEditor> {
  final _form = GlobalKey<FormState>();
  late String _name = widget.food?.name ?? '';
  late String _description = widget.food?.description ?? '';
  late String _price = widget.food?.price.toStringAsFixed(2) ?? '';
  late String? _categoryId = widget.food != null
      ? widget.food!.categoryId
      : widget.initialCategoryId;
  late Uint8List? _image = widget.food?.imageBytes;
  late String? _asset = widget.food?.assetImage;
  late final List<VendorCustomizationGroup> _groups = List.of(
    widget.food?.groups ?? [],
  );
  bool _picking = false;
  String? _error;

  Future<void> _pickImage() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final file = widget.pickImage != null
          ? await widget.pickImage!()
          : await ImagePicker().pickImage(
              source: ImageSource.gallery,
              maxWidth: 1600,
              maxHeight: 1600,
              imageQuality: 85,
            );
      if (file == null) return;
      if (await file.length() > 5 * 1024 * 1024) {
        throw const FormatException('Choose an image smaller than 5 MB.');
      }
      final bytes = await file.readAsBytes();
      final jpeg =
          bytes.length > 3 &&
          bytes[0] == 255 &&
          bytes[1] == 216 &&
          bytes[2] == 255;
      final png =
          bytes.length >= 8 &&
          listEqualsForImage(bytes.take(8).toList(), [
            137,
            80,
            78,
            71,
            13,
            10,
            26,
            10,
          ]);
      final webp =
          bytes.length >= 12 &&
          String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
      if (!jpeg && !png && !webp) {
        throw const FormatException('Choose a JPEG, PNG or WebP image.');
      }
      if (mounted) {
        setState(() {
          _image = bytes;
          _asset = null;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message
              : 'Could not open this image. Please try another.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _editGroup([VendorCustomizationGroup? group]) async {
    final result = await Navigator.of(context).push<VendorCustomizationGroup>(
      MaterialPageRoute(
        builder: (context) => Theme(
          data: vendorThemeData(context),
          child: VendorCustomizationEditor(
            catalog: widget.catalog,
            group: group,
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      final index = _groups.indexWhere((item) => item.id == result.id);
      if (index < 0) {
        _groups.add(result);
      } else {
        _groups[index] = result;
      }
    });
  }

  void _reorderGroups(int oldIndex, int newIndex) => setState(() {
    final group = _groups.removeAt(oldIndex);
    _groups.insert(newIndex, group);
  });

  void _save() {
    if (_picking || !_form.currentState!.validate()) return;
    final error = widget.catalog.saveFood(
      VendorFood(
        id: widget.food?.id ?? widget.catalog.newId('food'),
        name: normalizedVendorName(_name),
        description: _description.trim(),
        price: double.parse(_price),
        categoryId: _categoryId,
        imageBytes: _image,
        assetImage: _asset,
        isAvailable: widget.food?.isAvailable ?? true,
        groups: List.of(_groups),
      ),
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: VendorColors.cream,
    appBar: AppBar(
      title: Text(widget.food == null ? 'Add food item' : 'Edit food item'),
      backgroundColor: VendorColors.cream,
    ),
    body: SingleChildScrollView(
      key: const ValueKey('food-editor-scroll'),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: VendorFoodImage(
                    bytes: _image,
                    asset: _asset,
                    size: 170,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _picking ? null : _pickImage,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(_picking ? 'Opening photo…' : 'Choose photo'),
                    ),
                    if (_image != null || _asset != null)
                      TextButton(
                        onPressed: () => setState(() {
                          _image = null;
                          _asset = null;
                        }),
                        child: const Text('Remove photo'),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  key: const ValueKey('food-name'),
                  initialValue: _name,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Food name'),
                  onChanged: (value) => _name = value,
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Enter a food name.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('food-price'),
                  initialValue: _price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Price',
                    prefixText: 'RM ',
                  ),
                  onChanged: (value) => _price = value,
                  validator: vendorPriceError,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: const ValueKey('food-category'),
                  initialValue: _categoryId ?? '',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Food category'),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Uncategorized'),
                    ),
                    for (final category in widget.catalog.categories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _categoryId = value == '' ? null : value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _description,
                  maxLength: 1000,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    alignLabelWithHint: true,
                  ),
                  onChanged: (value) => _description = value,
                ),
                const SizedBox(height: 20),
                VendorSectionTitle(
                  'Customizations',
                  action: IconButton(
                    tooltip: 'Add customization',
                    onPressed: _editGroup,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ),
                if (_groups.isEmpty)
                  Text(
                    'No customization yet.',
                    style: vendorText(14, color: VendorColors.muted),
                  ),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  primary: false,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  buildDefaultDragHandles: false,
                  onReorderItem: _reorderGroups,
                  itemCount: _groups.length,
                  itemBuilder: (context, index) {
                    final group = _groups[index];
                    return Padding(
                      key: ValueKey('food-customization-${group.id}'),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: VendorPanel(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        group.name,
                                        style: vendorText(
                                          18,
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        group.selectionLabel,
                                        style: vendorText(
                                          16,
                                          color: VendorColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  key: ValueKey(
                                    'edit-customization-${group.id}',
                                  ),
                                  tooltip: 'Edit ${group.name}',
                                  onPressed: () => _editGroup(group),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: VendorColors.green,
                                  ),
                                ),
                                IconButton(
                                  key: ValueKey(
                                    'remove-customization-${group.id}',
                                  ),
                                  tooltip: 'Delete ${group.name}',
                                  onPressed: () =>
                                      setState(() => _groups.remove(group)),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: VendorColors.danger,
                                  ),
                                ),
                              ],
                            ),
                            Center(
                              child: VendorReorderHandle(
                                key: ValueKey(
                                  'reorder-customization-${group.id}',
                                ),
                                index: index,
                                label: group.name,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  key: const ValueKey('save-food'),
                  onPressed: _picking ? null : _save,
                  child: const Text('Save food item'),
                ),
                const VendorPreviewNote(),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

bool listEqualsForImage(List<int> a, List<int> b) =>
    a.length == b.length &&
    List.generate(
      a.length,
      (index) => a[index] == b[index],
    ).every((value) => value);
