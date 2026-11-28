import 'package:flutter/material.dart';

import '../models/customer_discovery_models.dart';
import '../theme/what2eat_theme.dart';

class MenuFoodImage extends StatelessWidget {
  const MenuFoodImage({super.key, required this.item, required this.size});
  final MenuItem item;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: item.imageUrl?.isNotEmpty == true
        ? Image.network(
            item.imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallback(),
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : _fallback(),
          )
        : _fallback(),
  );

  Widget _fallback() => const ColoredBox(
    color: What2EatTheme.softSurfaceAlt,
    child: Icon(
      Icons.lunch_dining_rounded,
      size: 32,
      color: What2EatTheme.forestGreen,
    ),
  );
}
