import 'dart:typed_data';

import 'package:flutter/material.dart';

abstract final class VendorColors {
  static const cream = Color(0xFFFFFCF5),
      green = Color(0xFF344B35),
      ink = Color(0xFF253729),
      muted = Color(0xFF596451),
      line = Color(0xFFCBD2BE),
      gold = Color(0xFFFFD85C),
      sage = Color(0xFFEEF1E4),
      danger = Color(0xFFB3261E),
      dangerSurface = Color(0xFFF7E9E6),
      draft = Color(0xFFFFF0C0);
}

ButtonStyle vendorActionStyle({
  Color background = VendorColors.sage,
  Color foreground = VendorColors.green,
}) => FilledButton.styleFrom(
  backgroundColor: background,
  foregroundColor: foreground,
  minimumSize: const Size(88, 48),
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
);

ThemeData vendorThemeData(BuildContext context) => Theme.of(context).copyWith(
  scaffoldBackgroundColor: VendorColors.cream,
  colorScheme: ColorScheme.fromSeed(seedColor: VendorColors.green),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: VendorColors.gold,
      foregroundColor: VendorColors.ink,
      minimumSize: const Size(0, 48),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
  ),
);

TextStyle vendorText(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = VendorColors.ink,
}) => TextStyle(fontSize: size, height: 1.4, fontWeight: weight, color: color);

class VendorPanel extends StatelessWidget {
  const VendorPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: VendorColors.line),
    ),
    child: Padding(padding: padding, child: child),
  );
}

class VendorSectionTitle extends StatelessWidget {
  const VendorSectionTitle(this.title, {super.key, this.action});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: vendorText(23, weight: FontWeight.w600)),
        ),
        ?action,
      ],
    ),
  );
}

class VendorReorderHandle extends StatelessWidget {
  const VendorReorderHandle({
    super.key,
    required this.index,
    required this.label,
  });
  final int index;
  final String label;

  @override
  Widget build(BuildContext context) => ReorderableDelayedDragStartListener(
    index: index,
    child: Semantics(
      label: 'Hold and drag to reorder $label',
      child: const SizedBox(
        width: 48,
        height: 24,
        child: Icon(Icons.drag_handle, size: 20, color: VendorColors.muted),
      ),
    ),
  );
}

class VendorFoodImage extends StatelessWidget {
  const VendorFoodImage({super.key, this.bytes, this.asset, this.size = 84});
  final Uint8List? bytes;
  final String? asset;
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: SizedBox(
      width: size,
      height: size,
      child: bytes != null
          ? Image.memory(
              bytes!,
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                  .ceil(),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.restaurant, color: VendorColors.muted),
            )
          : asset != null
          ? Image.asset(
              asset!,
              fit: BoxFit.contain,
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                  .ceil(),
            )
          : Container(
              color: VendorColors.sage,
              child: const Icon(
                Icons.restaurant,
                size: 32,
                color: VendorColors.muted,
              ),
            ),
    ),
  );
}

class VendorPreviewNote extends StatelessWidget {
  const VendorPreviewNote({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 20),
    child: Text(
      'Local preview · Changes are not saved to Supabase.',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, height: 1.4, color: VendorColors.muted),
    ),
  );
}

String vendorDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String vendorTime(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
String vendorDateTime(DateTime date) =>
    '${vendorDate(date)}, ${vendorTime(date.hour * 60 + date.minute)}';

Future<bool> vendorConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        scrollable: true,
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

String? vendorPriceError(String? value) {
  final text = (value ?? '').trim();
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) {
    return 'Use an amount with up to 2 decimal places.';
  }
  final number = double.tryParse(text);
  return number == null || number > 99999999.99
      ? 'Enter a valid amount.'
      : null;
}
