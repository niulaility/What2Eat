import 'package:flutter/material.dart';

import 'vendor_catalog.dart';
import 'vendor_ui.dart';
import 'vendor_menu_food_selection_page.dart';

class VendorMenuEditor extends StatefulWidget {
  const VendorMenuEditor({super.key, required this.catalog, this.menu});
  final VendorCatalog catalog;
  final VendorMenu? menu;
  @override
  State<VendorMenuEditor> createState() => _VendorMenuEditorState();
}

class _VendorMenuEditorState extends State<VendorMenuEditor> {
  late DateTime _date;
  late DateTime _opening;
  late DateTime _closing;
  late VendorMealSession _session;
  late int _deliveryStart, _deliveryEnd;
  late final Set<String> _foods = {...?widget.menu?.foodIds};
  late final Set<String> _unavailableFoods = {
    ...?widget.menu?.unavailableFoodIds,
  };
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date =
        widget.menu?.date ??
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    _opening =
        widget.menu?.openingAt ??
        DateTime(now.year, now.month, now.day, now.hour, now.minute);
    _closing = widget.menu?.closingAt ?? _date.add(const Duration(hours: 10));
    _session = widget.menu?.session ?? VendorMealSession.lunch;
    _deliveryStart = widget.menu?.deliveryStart ?? 12 * 60;
    _deliveryEnd = widget.menu?.deliveryEnd ?? 13 * 60;
  }

  Future<DateTime?> _pickDate(DateTime initial) {
    final today = DateUtils.dateOnly(DateTime.now());
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: initial.isBefore(today) ? DateUtils.dateOnly(initial) : today,
      lastDate: today.add(const Duration(days: 730)),
    );
  }

  Future<void> _pickWindow(bool opening) async {
    final initial = opening ? _opening : _closing;
    final day = await _pickDate(initial);
    if (!mounted || day == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted || time == null) return;
    final value = DateTime(
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (opening) {
        _opening = value;
      } else {
        _closing = value;
      }
    });
  }

  Future<void> _pickDelivery(bool start) async {
    final minutes = start ? _deliveryStart : _deliveryEnd;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (!mounted || time == null) return;
    setState(() {
      if (start) {
        _deliveryStart = time.hour * 60 + time.minute;
      } else {
        _deliveryEnd = time.hour * 60 + time.minute;
      }
    });
  }

  Future<void> _next() async {
    final draft = VendorMenu(
      id: widget.menu?.id ?? widget.catalog.newId('menu'),
      date: _date,
      session: _session,
      openingAt: _opening,
      closingAt: _closing,
      deliveryStart: _deliveryStart,
      deliveryEnd: _deliveryEnd,
      foodIds: _foods.toList(),
      unavailableFoodIds: _unavailableFoods.where(_foods.contains).toList(),
      isPublished: widget.menu?.isPublished ?? false,
    );
    final error = widget.catalog.validateMenuSchedule(draft);
    setState(() => _error = error);
    if (error != null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => Theme(
          data: vendorThemeData(context),
          child: VendorMenuFoodSelectionPage(
            catalog: widget.catalog,
            draft: draft,
            selection: _foods,
            unavailableSelection: _unavailableFoods,
          ),
        ),
      ),
    );
    if (mounted && saved == true) Navigator.pop(context);
  }

  Widget _dateField(
    String label,
    String value,
    VoidCallback onTap, {
    Key? key,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: OutlinedButton(
      key: key,
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: VendorColors.ink,
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: vendorText(13, color: VendorColors.muted)),
                const SizedBox(height: 4),
                Text(value, style: vendorText(16)),
              ],
            ),
          ),
          const Icon(Icons.edit_outlined, size: 18),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: VendorColors.cream,
    appBar: AppBar(
      title: Text(widget.menu == null ? 'Create menu' : 'Edit menu'),
      backgroundColor: VendorColors.cream,
    ),
    body: SingleChildScrollView(
      key: const ValueKey('menu-editor-scroll'),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Menu details',
                style: vendorText(20, weight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              _dateField('Menu date', vendorDate(_date), () async {
                final date = await _pickDate(_date);
                if (mounted && date != null) setState(() => _date = date);
              }, key: const ValueKey('menu-date')),
              DropdownMenu<VendorMealSession>(
                key: const ValueKey('menu-session'),
                initialSelection: _session,
                expandedInsets: EdgeInsets.zero,
                requestFocusOnTap: false,
                enableSearch: false,
                label: const Text('Meal session'),
                menuStyle: const MenuStyle(alignment: Alignment.bottomLeft),
                dropdownMenuEntries: [
                  for (final session in VendorMealSession.values)
                    DropdownMenuEntry(value: session, label: session.label),
                ],
                onSelected: (session) {
                  if (session == null) return;
                  setState(() {
                    _session = session;
                    if (widget.menu == null) {
                      _deliveryStart = switch (session) {
                        VendorMealSession.breakfast => 8 * 60,
                        VendorMealSession.lunch => 12 * 60,
                        VendorMealSession.dinner => 18 * 60,
                      };
                      _deliveryEnd = _deliveryStart + 60;
                      _closing = DateTime(
                        _date.year,
                        _date.month,
                        _date.day,
                      ).add(Duration(minutes: _deliveryStart - 120));
                    }
                  });
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Ordering window',
                style: vendorText(20, weight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _dateField(
                'Ordering opens',
                vendorDateTime(_opening),
                () => _pickWindow(true),
                key: const ValueKey('menu-opens'),
              ),
              _dateField(
                'Ordering closes',
                vendorDateTime(_closing),
                () => _pickWindow(false),
                key: const ValueKey('menu-closes'),
              ),
              const SizedBox(height: 8),
              Text(
                'Estimated delivery on ${vendorDate(_date)}',
                style: vendorText(20, weight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _dateField(
                'Delivery starts',
                vendorTime(_deliveryStart),
                () => _pickDelivery(true),
              ),
              _dateField(
                'Delivery ends',
                vendorTime(_deliveryEnd),
                () => _pickDelivery(false),
              ),
              const SizedBox(height: 12),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('menu-next'),
                onPressed: _next,
                child: const Text('Next'),
              ),
              const VendorPreviewNote(),
            ],
          ),
        ),
      ),
    ),
  );
}
