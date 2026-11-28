import 'package:flutter/material.dart';

import 'vendor_catalog.dart';
import 'vendor_ui.dart';

class VendorCustomizationEditor extends StatefulWidget {
  const VendorCustomizationEditor({
    super.key,
    required this.catalog,
    this.group,
  });
  final VendorCatalog catalog;
  final VendorCustomizationGroup? group;
  @override
  State<VendorCustomizationEditor> createState() =>
      _VendorCustomizationEditorState();
}

class _OptionDraft {
  _OptionDraft(this.id, this.name, this.price, {this.isAvailable = true});
  final String id;
  String name, price;
  bool isAvailable;
}

class _VendorCustomizationEditorState extends State<VendorCustomizationEditor> {
  final _form = GlobalKey<FormState>();
  late String _name = widget.group?.name ?? '';
  late String _minimum = '${widget.group?.minSelectable ?? 1}';
  late String _maximum = '${widget.group?.maxSelectable ?? 1}';
  late final List<_OptionDraft> _options =
      widget.group?.options
          .map(
            (option) => _OptionDraft(
              option.id,
              option.name,
              option.additionalPrice.toStringAsFixed(2),
              isAvailable: option.isAvailable,
            ),
          )
          .toList() ??
      [_OptionDraft(widget.catalog.newId('option'), '', '0.00')];
  String? _error;

  void _reorderOptions(int oldIndex, int newIndex) => setState(() {
    final option = _options.removeAt(oldIndex);
    _options.insert(newIndex, option);
  });

  void _save() {
    if (!_form.currentState!.validate()) return;
    final group = VendorCustomizationGroup(
      id: widget.group?.id ?? widget.catalog.newId('group'),
      name: normalizedVendorName(_name),
      minSelectable: int.parse(_minimum),
      maxSelectable: int.parse(_maximum),
      options: _options
          .map(
            (option) => VendorCustomizationOption(
              id: option.id,
              name: normalizedVendorName(option.name),
              additionalPrice: double.parse(option.price),
              isAvailable: option.isAvailable,
            ),
          )
          .toList(),
    );
    final error = validateVendorGroup(group);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, group);
  }

  Widget _optionFields(_OptionDraft option) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final name = TextFormField(
            key: ValueKey('option-name-${option.id}'),
            initialValue: option.name,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Option name',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              hintText: 'e.g. Iced tea',
              counterText: '',
            ),
            onChanged: (value) => option.name = value,
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Enter an option name.' : null,
          );
          final price = TextFormField(
            key: ValueKey('option-price-${option.id}'),
            initialValue: option.price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Additional price',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              prefixText: 'RM ',
            ),
            onChanged: (value) => option.price = value,
            validator: vendorPriceError,
          );
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          if (constraints.maxWidth < 220 * scale) {
            return Column(children: [name, const SizedBox(height: 12), price]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: name),
              const SizedBox(width: 12),
              Expanded(child: price),
            ],
          );
        },
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Flexible(
            child: Text(
              'Availability',
              style: vendorText(14, color: VendorColors.muted),
            ),
          ),
          const SizedBox(width: 8),
          Transform.scale(
            scale: .75,
            alignment: Alignment.centerLeft,
            child: Semantics(
              label:
                  '${option.name.trim().isEmpty ? 'Option' : option.name} availability',
              child: Switch.adaptive(
                key: ValueKey('option-availability-${option.id}'),
                value: option.isAvailable,
                activeTrackColor: VendorColors.green,
                onChanged: (value) =>
                    setState(() => option.isAvailable = value),
              ),
            ),
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: VendorColors.cream,
    appBar: AppBar(
      title: Text(
        widget.group == null ? 'Add customization' : 'Edit customization',
      ),
      backgroundColor: VendorColors.cream,
    ),
    body: SingleChildScrollView(
      key: const ValueKey('customization-editor-scroll'),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const ValueKey('group-name'),
                  initialValue: _name,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Customize Selection',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    hintText: 'e.g. Choose your drink',
                  ),
                  onChanged: (value) => _name = value,
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Enter a group name.'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const ValueKey('group-min'),
                        initialValue: _minimum,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Min.',
                          helperText: '0 means optional',
                          helperMaxLines: 2,
                        ),
                        onChanged: (value) => _minimum = value,
                        validator: (value) =>
                            int.tryParse(value ?? '') == null ||
                                int.parse(value!) < 0
                            ? 'Enter 0 or more.'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        key: const ValueKey('group-max'),
                        initialValue: _maximum,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Max.'),
                        onChanged: (value) => _maximum = value,
                        validator: (value) =>
                            int.tryParse(value ?? '') == null ||
                                int.parse(value!) < 1
                            ? 'Enter 1 or more.'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                VendorSectionTitle(
                  'Options',
                  action: IconButton.filledTonal(
                    tooltip: 'Add option',
                    style: IconButton.styleFrom(
                      backgroundColor: VendorColors.sage,
                      foregroundColor: VendorColors.green,
                      shape: const CircleBorder(),
                    ),
                    onPressed: () => setState(
                      () => _options.add(
                        _OptionDraft(
                          widget.catalog.newId('option'),
                          '',
                          '0.00',
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                  ),
                ),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  primary: false,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  buildDefaultDragHandles: false,
                  onReorderItem: _reorderOptions,
                  itemCount: _options.length,
                  itemBuilder: (context, index) {
                    final option = _options[index];
                    return Padding(
                      key: ValueKey('option-${option.id}'),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: VendorPanel(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _optionFields(option)),
                                const SizedBox(width: 8),
                                IconButton(
                                  key: ValueKey('remove-option-${option.id}'),
                                  tooltip: option.name.trim().isEmpty
                                      ? 'Delete option'
                                      : 'Delete ${option.name}',
                                  onPressed: () =>
                                      setState(() => _options.remove(option)),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: VendorColors.danger,
                                  ),
                                ),
                              ],
                            ),
                            Center(
                              child: VendorReorderHandle(
                                key: ValueKey('reorder-option-${option.id}'),
                                index: index,
                                label: option.name.trim().isEmpty
                                    ? 'option'
                                    : option.name,
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
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                FilledButton(
                  key: const ValueKey('save-customization'),
                  onPressed: _save,
                  child: const Text('Save customization'),
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
