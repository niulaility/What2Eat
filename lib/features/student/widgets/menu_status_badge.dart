import 'package:flutter/material.dart';

import '../models/customer_discovery_models.dart';
import '../theme/what2eat_theme.dart';

/// Colours for each ordering status. Only open menus are tappable.
({Color background, Color foreground}) menuStatusColors(
  MenuOrderStatus status,
) => switch (status) {
  MenuOrderStatus.open => (
    background: const Color(0xFFDFF0D8),
    foreground: const Color(0xFF2E6B30),
  ),
  MenuOrderStatus.notOpenYet => (
    background: What2EatTheme.softYellowBadge,
    foreground: What2EatTheme.darkGreenText,
  ),
  MenuOrderStatus.closed => (
    background: What2EatTheme.softSurface,
    foreground: What2EatTheme.subtleText,
  ),
};

/// Small pill showing "Open", "Not open yet", or "Closed".
class MenuStatusBadge extends StatelessWidget {
  const MenuStatusBadge({super.key, required this.status});

  final MenuOrderStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = menuStatusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: colors.foreground,
        ),
      ),
    );
  }
}
