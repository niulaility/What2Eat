import 'package:flutter/material.dart';

class UniversityOption {
  const UniversityOption({
    required this.id,
    required this.code,
    required this.name,
    this.state,
  });

  final String id;
  final String code;
  final String name;
  final String? state;

  factory UniversityOption.fromMap(Map<String, dynamic> map) {
    return UniversityOption(
      id: map['id']?.toString() ?? '',
      code: map['code']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      state: map['state']?.toString(),
    );
  }
}

class MealSession {
  const MealSession({
    required this.id,
    required this.name,
    required this.timeRange,
    required this.lastOrderTime,
    required this.icon,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String timeRange;
  final String lastOrderTime;
  final IconData icon;
  final int sortOrder;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealSession &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class CustomizationOption {
  const CustomizationOption({
    required this.id,
    required this.name,
    this.priceDelta = 0.0,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final double priceDelta;
  final bool isDefault;
}

class CustomizationGroup {
  const CustomizationGroup({
    required this.id,
    required this.title,
    required this.isRequired,
    required this.allowMultiple,
    required this.options,
    this.maxSelections,
  });

  final String id;
  final String title;
  final bool isRequired;
  final bool allowMultiple;
  final List<CustomizationOption> options;
  final int? maxSelections;
}

class MenuItem {
  const MenuItem({
    required this.id,
    required this.vendorId,
    required this.sessionIds,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    this.imageUrl,
    this.isAvailable = true,
    this.customizationGroups = const [],
  });

  final String id;
  final String vendorId;
  final List<String> sessionIds;
  final String name;
  final String description;
  final double price;
  final String category;
  final String? imageUrl;
  final bool isAvailable;
  final List<CustomizationGroup> customizationGroups;
}

class VendorProfile {
  const VendorProfile({
    required this.id,
    required this.businessName,
    required this.businessDescription,
    required this.businessContactNumber,
    required this.businessAddress,
    this.logoUrl,
    required this.universityIds,
    required this.offeredSessions,
    required this.availableDatesBySession,
    required this.menuItems,
    this.rating = 4.8,
    this.prepTimeLabel = '15–25 mins',
    this.cuisineTag = 'Local & Campus',
  });

  final String id;
  final String businessName;
  final String businessDescription;
  final String businessContactNumber;
  final String businessAddress;
  final String? logoUrl;
  final List<String> universityIds;
  final List<MealSession> offeredSessions;

  /// Maps ISO date string (`yyyy-MM-dd`) to the session IDs available on that date.
  final Map<String, List<String>> availableDatesBySession;
  final List<MenuItem> menuItems;
  final double rating;
  final String prepTimeLabel;
  final String cuisineTag;

  List<MealSession> sessionsForDate(DateTime date) {
    final key = formatIsoDate(date);
    final ids = availableDatesBySession[key];
    if (ids == null || ids.isEmpty) return const [];
    return offeredSessions.where((s) => ids.contains(s.id)).toList();
  }

  List<MenuItem> menuForSession(String sessionId) {
    return menuItems
        .where((item) => item.isAvailable && item.sessionIds.contains(sessionId))
        .toList();
  }

  static String formatIsoDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class SelectedCartItem {
  const SelectedCartItem({
    required this.item,
    required this.session,
    required this.selectedDate,
    required this.quantity,
    required this.unitPrice,
    required this.selectedOptionLabels,
    this.notes,
  });

  final MenuItem item;
  final MealSession session;
  final DateTime? selectedDate;
  final int quantity;
  final double unitPrice;
  final List<String> selectedOptionLabels;
  final String? notes;

  double get totalPrice => unitPrice * quantity;
}
