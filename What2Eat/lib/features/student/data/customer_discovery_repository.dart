import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer_discovery_models.dart';

class CustomerDiscoveryData {
  const CustomerDiscoveryData({
    required this.universities,
    required this.vendors,
    this.defaultUniversityId,
  });

  final List<UniversityOption> universities;
  final List<VendorProfile> vendors;
  final String? defaultUniversityId;
}

class CustomerDiscoveryRepository {
  CustomerDiscoveryRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient? get _supabase {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static const MealSession breakfastSession = MealSession(
    id: 'breakfast',
    name: 'Breakfast',
    timeRange: '07:30 – 10:00',
    lastOrderTime: '09:30',
    icon: Icons.wb_sunny_outlined,
    sortOrder: 1,
  );

  static const MealSession lunchSession = MealSession(
    id: 'lunch',
    name: 'Lunch',
    timeRange: '11:30 – 14:30',
    lastOrderTime: '14:00',
    icon: Icons.lunch_dining_outlined,
    sortOrder: 2,
  );

  static const MealSession dinnerSession = MealSession(
    id: 'dinner',
    name: 'Dinner',
    timeRange: '18:00 – 21:00',
    lastOrderTime: '20:30',
    icon: Icons.dinner_dining_outlined,
    sortOrder: 3,
  );

  static const MealSession supperSession = MealSession(
    id: 'supper',
    name: 'Supper',
    timeRange: '21:30 – 23:30',
    lastOrderTime: '23:00',
    icon: Icons.nightlight_outlined,
    sortOrder: 4,
  );

  /// Loads active universities and every approved, active vendor that serves
  /// at least one university. Sample data is used only when Supabase is not
  /// initialized (offline widget tests); real query failures are rethrown so
  /// the dashboard shows an error instead of fake vendors.
  Future<CustomerDiscoveryData> loadDiscoveryData() async {
    final client = _supabase;
    if (client == null) {
      return _buildFallbackData();
    }

    final uniRows = await client
        .from('universities')
        .select('id, code, name, state')
        .eq('is_active', true)
        .order('name');

    // "Other university" (code 'other') is a regular row, listed last.
    final universities =
        (uniRows as List<dynamic>)
            .map((e) => UniversityOption.fromMap(Map<String, dynamic>.from(e)))
            .toList()
          ..sort((a, b) {
            final aOther = a.code == 'other', bOther = b.code == 'other';
            if (aOther != bOther) return aOther ? 1 : -1;
            return a.name.compareTo(b.name);
          });

    String? defaultUniId;
    var hasCustomerRow = false;
    final currentUser = client.auth.currentUser;
    if (currentUser != null) {
      try {
        final customerRow = await client
            .from('customers')
            .select('university_id')
            .eq('user_id', currentUser.id)
            .maybeSingle();
        if (customerRow != null) {
          hasCustomerRow = true;
          defaultUniId = customerRow['university_id']?.toString();
        }
      } catch (_) {
        // Non-customer accounts (e.g., admin previewing) may not have a customer row.
      }
    }

    final vendorRows = await client
        .from('vendors')
        .select(
          'id, business_name, business_description, business_contact_number, business_address, logo_url, status, is_active',
        )
        .eq('status', 'approved')
        .eq('is_active', true)
        .order('business_name');

    final liveVendors = await _mapVendorRows(
      client: client,
      vendorRows: vendorRows as List<dynamic>,
    );

    if (!hasCustomerRow && universities.isNotEmpty) {
      defaultUniId ??= universities.first.id;
    }

    return CustomerDiscoveryData(
      universities: universities,
      vendors: liveVendors,
      defaultUniversityId: defaultUniId,
    );
  }

  /// Searches approved active vendors in Supabase, restricted to [universityId]
  /// when a specific university is selected. Returns `null` when Supabase is not
  /// initialized (e.g., offline widget tests).
  Future<List<VendorProfile>?> searchVendors({
    required String? universityId,
    required String query,
  }) async {
    final client = _supabase;
    if (client == null) return null;

    final trimmed = query.trim();
    var builder = client
        .from('vendors')
        .select(
          'id, business_name, business_description, business_contact_number, business_address, logo_url',
        )
        .eq('status', 'approved')
        .eq('is_active', true);

    if (trimmed.isNotEmpty) {
      builder = builder.ilike('business_name', '%$trimmed%');
    }

    final vendorRows = await builder.order('business_name');
    return _mapVendorRows(
      client: client,
      vendorRows: vendorRows as List<dynamic>,
      requiredUniversityId: universityId,
    );
  }

  Future<List<VendorProfile>> _mapVendorRows({
    required SupabaseClient client,
    required List<dynamic> vendorRows,
    String? requiredUniversityId,
  }) async {
    if (vendorRows.isEmpty) return const [];

    final vendorIds = vendorRows
        .map((r) => r['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    if (vendorIds.isEmpty) return const [];

    final vendorUniRows = await client
        .from('vendor_universities')
        .select('vendor_id, university_id')
        .inFilter('vendor_id', vendorIds);

    final Map<String, List<String>> uniIdsByVendor = {};
    for (final row in (vendorUniRows as List<dynamic>)) {
      final map = Map<String, dynamic>.from(row);
      final vendorId = map['vendor_id']?.toString() ?? '';
      final uniId = map['university_id']?.toString() ?? '';
      if (vendorId.isNotEmpty && uniId.isNotEmpty) {
        uniIdsByVendor.putIfAbsent(vendorId, () => []).add(uniId);
      }
    }

    final List<VendorProfile> vendors = [];
    for (final row in vendorRows) {
      final map = Map<String, dynamic>.from(row);
      final vendorId = map['id']?.toString() ?? '';
      final servedUnis = uniIdsByVendor[vendorId] ?? const [];
      if (servedUnis.isEmpty) continue;
      if (requiredUniversityId != null &&
          !servedUnis.contains(requiredUniversityId)) {
        continue;
      }

      vendors.add(
        _enrichLiveVendor(
          id: vendorId,
          businessName: map['business_name']?.toString() ?? 'Campus Kitchen',
          businessDescription: map['business_description']?.toString() ?? '',
          businessContactNumber:
              map['business_contact_number']?.toString() ?? '',
          businessAddress: map['business_address']?.toString() ?? '',
          logoUrl: map['logo_url']?.toString(),
          universityIds: servedUnis,
        ),
      );
    }
    return vendors;
  }

  /// Persists the student's selected university to `public.customers`.
  /// "Other university" is a regular university row.
  Future<void> updateSelectedUniversity(String? universityId) async {
    final client = _supabase;
    final currentUser = client?.auth.currentUser;
    if (client == null || currentUser == null) return;

    await client.from('customers').upsert({
      'user_id': currentUser.id,
      'university_id': universityId,
    }, onConflict: 'user_id');
  }

  VendorProfile _enrichLiveVendor({
    required String id,
    required String businessName,
    required String businessDescription,
    required String businessContactNumber,
    required String businessAddress,
    required String? logoUrl,
    required List<String> universityIds,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dayAfter = today.add(const Duration(days: 2));

    final isMamaSiti = businessName.toLowerCase().contains('mama siti');

    final sessions = isMamaSiti
        ? const [breakfastSession, lunchSession, dinnerSession]
        : const [lunchSession, dinnerSession];

    final datesMap = <String, List<String>>{
      VendorProfile.formatIsoDate(today): sessions.map((s) => s.id).toList(),
      VendorProfile.formatIsoDate(tomorrow): isMamaSiti
          ? ['breakfast', 'lunch']
          : ['lunch', 'dinner'],
      VendorProfile.formatIsoDate(dayAfter): sessions.map((s) => s.id).toList(),
    };

    return VendorProfile(
      id: id,
      businessName: businessName,
      businessDescription: businessDescription,
      businessContactNumber: businessContactNumber,
      businessAddress: businessAddress,
      logoUrl: logoUrl,
      universityIds: universityIds,
      offeredSessions: sessions,
      availableDatesBySession: datesMap,
      menuItems: _mamaSitiMenu(id),
      rating: 4.9,
      prepTimeLabel: '15–25 mins',
      cuisineTag: isMamaSiti ? 'Malay Home-Cooked' : 'Campus Kitchen',
    );
  }

  CustomerDiscoveryData _buildFallbackData() {
    const universities = [
      UniversityOption(
        id: 'utm',
        code: 'utm',
        name: 'Universiti Teknologi Malaysia',
        state: 'Johor',
      ),
      UniversityOption(
        id: 'um',
        code: 'um',
        name: 'Universiti Malaya',
        state: 'Kuala Lumpur',
      ),
      UniversityOption(
        id: 'upm',
        code: 'upm',
        name: 'Universiti Putra Malaysia',
        state: 'Selangor',
      ),
      UniversityOption(
        id: 'ukm',
        code: 'ukm',
        name: 'Universiti Kebangsaan Malaysia',
        state: 'Selangor',
      ),
      UniversityOption(
        id: 'usm',
        code: 'usm',
        name: 'Universiti Sains Malaysia',
        state: 'Penang',
      ),
      UniversityOption(
        id: 'uitm',
        code: 'uitm',
        name: 'Universiti Teknologi MARA',
        state: 'Selangor',
      ),
    ];

    final mamaSiti = _enrichLiveVendor(
      id: 'vendor-mama-siti',
      businessName: 'Mama Siti Kitchen',
      businessDescription: 'Authentic homemade Malay dishes and packed lunch delivery for campus students.',
      businessContactNumber: '0198765432',
      businessAddress: 'No. 12, Jalan Universiti, 81300 Skudai, Johor',
      logoUrl: null,
      universityIds: ['utm', 'um'],
    );

    final samples = _sampleVendorsForUniversities(universities);
    return CustomerDiscoveryData(
      universities: universities,
      vendors: [mamaSiti, ...samples],
      defaultUniversityId: universities.first.id,
    );
  }

  List<VendorProfile> _sampleVendorsForUniversities(
    List<UniversityOption> universities,
  ) {
    String? idForCode(String code) {
      for (final u in universities) {
        if (u.code.toLowerCase() == code) return u.id;
      }
      return universities.isNotEmpty ? universities.first.id : null;
    }

    final utmId = idForCode('utm');
    final umId = idForCode('um');
    final upmId = idForCode('upm');
    final ukmId = idForCode('ukm');
    final usmId = idForCode('usm');
    final uitmId = idForCode('uitm');

    List<String> nonNull(List<String?> ids) =>
        ids.whereType<String>().toSet().toList();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dayAfter = today.add(const Duration(days: 2));

    final todayKey = VendorProfile.formatIsoDate(today);
    final tomorrowKey = VendorProfile.formatIsoDate(tomorrow);
    final dayAfterKey = VendorProfile.formatIsoDate(dayAfter);

    return [
      VendorProfile(
        id: 'sample-wok-station',
        businessName: 'Wok & Bowl Express',
        businessDescription: 'Freshly stir-fried rice bowls, handmade dumplings, and Thai-style basil chicken prepared to order.',
        businessContactNumber: '0174458821',
        businessAddress: 'Blok B-04, Arked Meranti, 81310 Skudai, Johor',
        universityIds: nonNull([utmId, upmId, ukmId]),
        offeredSessions: const [lunchSession, dinnerSession, supperSession],
        availableDatesBySession: {
          todayKey: ['lunch', 'dinner', 'supper'],
          tomorrowKey: ['lunch', 'supper'],
          dayAfterKey: ['lunch', 'dinner'],
        },
        menuItems: _wokExpressMenu('sample-wok-station'),
        rating: 4.7,
        prepTimeLabel: '15–20 mins',
        cuisineTag: 'Asian Rice Bowls',
      ),
      VendorProfile(
        id: 'sample-green-bento',
        businessName: 'The Green Bento Co.',
        businessDescription: 'Balanced high-protein meal boxes, grilled chicken salads, and cold-pressed juices for busy study days.',
        businessContactNumber: '0129934120',
        businessAddress: 'Suite 3, Pusat Komersial Pelajar, Kuala Lumpur',
        universityIds: nonNull([utmId, umId, usmId, uitmId]),
        offeredSessions: const [breakfastSession, lunchSession, dinnerSession],
        availableDatesBySession: {
          todayKey: ['breakfast', 'lunch', 'dinner'],
          tomorrowKey: ['breakfast', 'dinner'],
          dayAfterKey: ['breakfast', 'lunch', 'dinner'],
        },
        menuItems: _greenBentoMenu('sample-green-bento'),
        rating: 4.8,
        prepTimeLabel: '10–20 mins',
        cuisineTag: 'Healthy & Bento',
      ),
      VendorProfile(
        id: 'sample-warung-kopi',
        businessName: 'Warung Kopi & Roti',
        businessDescription: 'Crispy roti canai, kaya toast sets, nasi lemak bungkus, and iced kopi kaw for early lectures and late-night cramming.',
        businessContactNumber: '0136679012',
        businessAddress: 'No. 8, Medan Selera Siswa, 43400 Serdang, Selangor',
        universityIds: nonNull([umId, upmId, ukmId, uitmId, usmId]),
        offeredSessions: const [breakfastSession, supperSession],
        availableDatesBySession: {
          todayKey: ['breakfast', 'supper'],
          tomorrowKey: ['breakfast', 'supper'],
          dayAfterKey: ['breakfast'],
        },
        menuItems: _warungKopiMenu('sample-warung-kopi'),
        rating: 4.6,
        prepTimeLabel: '10–15 mins',
        cuisineTag: 'Breakfast & Supper',
      ),
    ];
  }

  static List<MenuItem> _mamaSitiMenu(String vendorId) {
    return [
      MenuItem(
        id: '$vendorId-nasi-lemak',
        vendorId: vendorId,
        sessionIds: const ['breakfast', 'lunch'],
        name: 'Nasi Lemak Ayam Berempah',
        description: 'Fragrant coconut rice served with crispy spiced fried chicken, house-made sambal, toasted anchovies, peanuts, cucumber, and boiled egg.',
        price: 9.50,
        category: 'Rice & Mains',
        customizationGroups: const [
          CustomizationGroup(
            id: 'sambal-level',
            title: 'Sambal Spice Level',
            isRequired: true,
            allowMultiple: false,
            options: [
              CustomizationOption(
                id: 'mild',
                name: 'Mild Sambal',
                isDefault: true,
              ),
              CustomizationOption(id: 'medium', name: 'Original Pedas'),
              CustomizationOption(id: 'extra', name: 'Extra Spicy Sambal'),
            ],
          ),
          CustomizationGroup(
            id: 'addons',
            title: 'Add-ons & Extras',
            isRequired: false,
            allowMultiple: true,
            options: [
              CustomizationOption(
                id: 'egg',
                name: 'Sunny-Side Up Egg',
                priceDelta: 1.50,
              ),
              CustomizationOption(
                id: 'extra-rice',
                name: 'Extra Coconut Rice',
                priceDelta: 1.80,
              ),
              CustomizationOption(
                id: 'paru',
                name: 'Crispy Paru Sambal',
                priceDelta: 3.00,
              ),
              CustomizationOption(
                id: 'teh-o-ais',
                name: 'Teh O Ais Limau',
                priceDelta: 2.50,
              ),
            ],
          ),
        ],
      ),
      MenuItem(
        id: '$vendorId-lontong',
        vendorId: vendorId,
        sessionIds: const ['breakfast'],
        name: 'Lontong Kuah Lodeh',
        description: 'Compressed rice cakes in rich turmeric coconut vegetable gravy with tempeh, tofu, and sambal tumis.',
        price: 7.00,
        category: 'Breakfast',
        customizationGroups: const [
          CustomizationGroup(
            id: 'lontong-addons',
            title: 'Optional Toppings',
            isRequired: false,
            allowMultiple: true,
            options: [
              CustomizationOption(
                id: 'serunding',
                name: 'Serunding Kelapa',
                priceDelta: 1.20,
              ),
              CustomizationOption(
                id: 'telur-rebus',
                name: 'Boiled Egg',
                priceDelta: 1.20,
              ),
            ],
          ),
        ],
      ),
      MenuItem(
        id: '$vendorId-ayam-masak-merah',
        vendorId: vendorId,
        sessionIds: const ['lunch', 'dinner'],
        name: 'Nasi Tomato Ayam Masak Merah',
        description: 'Aromatic tomato-infused rice paired with tender chicken simmered in sweet-spicy chili tomato gravy and acar jelatah.',
        price: 10.90,
        category: 'Rice & Mains',
        customizationGroups: const [
          CustomizationGroup(
            id: 'portion',
            title: 'Portion Size',
            isRequired: true,
            allowMultiple: false,
            options: [
              CustomizationOption(
                id: 'regular',
                name: 'Regular Set',
                isDefault: true,
              ),
              CustomizationOption(
                id: 'large',
                name: 'Large Rice + Extra Gravy',
                priceDelta: 2.00,
              ),
            ],
          ),
          CustomizationGroup(
            id: 'drink-combo',
            title: 'Drink Pairing',
            isRequired: false,
            allowMultiple: true,
            options: [
              CustomizationOption(
                id: 'sirap-bandung',
                name: 'Sirap Bandung Ais',
                priceDelta: 3.00,
              ),
              CustomizationOption(
                id: 'mineral',
                name: 'Mineral Water (500ml)',
                priceDelta: 1.50,
              ),
            ],
          ),
        ],
      ),
      MenuItem(
        id: '$vendorId-ikan-bakar',
        vendorId: vendorId,
        sessionIds: const ['dinner'],
        name: 'Set Ikan Keli Bakar & Air Asam',
        description: 'Char-grilled catfish marinated in turmeric and lemongrass, served with steamed white rice, ulam, and tangy air asam dip.',
        price: 11.50,
        category: 'Rice & Mains',
        customizationGroups: const [
          CustomizationGroup(
            id: 'dip',
            title: 'Dipping Sauce',
            isRequired: true,
            allowMultiple: false,
            options: [
              CustomizationOption(
                id: 'air-asam',
                name: 'Air Asam',
                isDefault: true,
              ),
              CustomizationOption(id: 'kicap', name: 'Sambal Kicap'),
              CustomizationOption(
                id: 'both',
                name: 'Both Air Asam & Sambal Kicap',
                priceDelta: 1.00,
              ),
            ],
          ),
        ],
      ),
      MenuItem(
        id: '$vendorId-sirap-limau',
        vendorId: vendorId,
        sessionIds: const ['breakfast', 'lunch', 'dinner'],
        name: 'Kopi Kampung Ais / Teh Tarik',
        description: 'Freshly brewed Malaysian kopitiam-style coffee or pulled milk tea.',
        price: 3.20,
        category: 'Drinks',
        customizationGroups: const [
          CustomizationGroup(
            id: 'drink-type',
            title: 'Drink Choice',
            isRequired: true,
            allowMultiple: false,
            options: [
              CustomizationOption(
                id: 'teh-tarik',
                name: 'Teh Tarik Ais',
                isDefault: true,
              ),
              CustomizationOption(id: 'kopi-ais', name: 'Kopi Kampung Ais'),
              CustomizationOption(
                id: 'milo-ais',
                name: 'Milo Ais',
                priceDelta: 0.80,
              ),
            ],
          ),
          CustomizationGroup(
            id: 'sugar',
            title: 'Sweetness Level',
            isRequired: true,
            allowMultiple: false,
            options: [
              CustomizationOption(
                id: 'normal',
                name: 'Normal Sugar',
                isDefault: true,
              ),
              CustomizationOption(
                id: 'kurang-manis',
                name: 'Kurang Manis (Less Sweet)',
              ),
            ],
          ),
        ],
      ),
    ];
  }

  static List<MenuItem> _wokExpressMenu(String vendorId) {
    return [
      MenuItem(
        id: '$vendorId-pad-kra-pao',
        vendorId: vendorId,
        sessionIds: const ['lunch', 'dinner', 'supper'],
        name: 'Thai Basil Chicken Rice Bowl',
        description: 'Wok-seared minced chicken with holy basil, garlic, chili padi, and jasmine rice topped with a crispy-edged fried egg.',
        price: 10.50,
        category: 'Rice Bowls',
        customizationGroups: const [
          CustomizationGroup(
            id: 'heat',
            title: 'Heat Level',
            isRequired: true,
            allowMultiple: false,
            options: [
              CustomizationOption(id: 'mild', name: 'Mild (1 Chili)'),
              CustomizationOption(
                id: 'standard',
                name: 'Standard (3 Chilies)',
                isDefault: true,
              ),
              CustomizationOption(id: 'thai-hot', name: 'Thai Hot (5 Chilies)'),
            ],
          ),
          CustomizationGroup(
            id: 'extras',
            title: 'Bowl Upgrades',
            isRequired: false,
            allowMultiple: true,
            options: [
              CustomizationOption(
                id: 'extra-egg',
                name: 'Extra Fried Egg',
                priceDelta: 1.50,
              ),
              CustomizationOption(
                id: 'extra-meat',
                name: 'Double Chicken Portion',
                priceDelta: 3.50,
              ),
              CustomizationOption(
                id: 'dumplings',
                name: '3pc Chicken Gyoza',
                priceDelta: 4.00,
              ),
            ],
          ),
        ],
      ),
      MenuItem(
        id: '$vendorId-buttermilk-chicken',
        vendorId: vendorId,
        sessionIds: const ['lunch', 'dinner', 'supper'],
        name: 'Salted Egg Buttermilk Chicken Rice',
        description: 'Crispy popcorn chicken tossed in creamy curry-leaf buttermilk salted egg sauce over steamed rice.',
        price: 11.90,
        category: 'Rice Bowls',
        customizationGroups: const [
          CustomizationGroup(
            id: 'sauce',
            title: 'Sauce Preference',
            isRequired: true,
            allowMultiple: false,
            options: [
              CustomizationOption(
                id: 'normal-sauce',
                name: 'Standard Sauce',
                isDefault: true,
              ),
              CustomizationOption(
                id: 'extra-sauce',
                name: 'Extra Buttermilk Sauce',
                priceDelta: 1.50,
              ),
            ],
          ),
        ],
      ),
      MenuItem(
        id: '$vendorId-dumpling-noodles',
        vendorId: vendorId,
        sessionIds: const ['dinner', 'supper'],
        name: 'Chili Oil Dumpling Noodles',
        description: 'Springy egg noodles tossed in fragrant soy-chili oil with 5 handmade chicken & chive dumplings.',
        price: 9.80,
        category: 'Noodles',
        customizationGroups: const [
          CustomizationGroup(
            id: 'noodle-style',
            title: 'Noodle Preparation',
            isRequired: true,
            allowMultiple: false,
            options: [
              CustomizationOption(
                id: 'dry',
                name: 'Dry Chili Oil',
                isDefault: true,
              ),
              CustomizationOption(id: 'soup', name: 'Clear Chicken Broth'),
            ],
          ),
        ],
      ),
    ];
  }

  static List<MenuItem> _greenBentoMenu(String vendorId) {
    return [
      MenuItem(
        id: '$vendorId-overnight-oats',
        vendorId: vendorId,
        sessionIds: const ['breakfast'],
        name: 'Matcha Chia Overnight Oats',
        description: 'Rolled oats soaked in oat milk with ceremonial matcha, chia seeds, sliced banana, and toasted almonds.',
        price: 8.90,
        category: 'Breakfast',
        customizationGroups: const [
          CustomizationGroup(
            id: 'sweetener',
            title: 'Sweetener',
            isRequired: true,
            allowMultiple: false,
            options: [
              CustomizationOption(
                id: 'honey',
                name: 'Wildflower Honey',
                isDefault: true,
              ),
              CustomizationOption(id: 'unsweetened', name: 'Unsweetened'),
            ],
          ),
          CustomizationGroup(
            id: 'toppings',
            title: 'Extra Toppings',
            isRequired: false,
            allowMultiple: true,
            options: [
              CustomizationOption(
                id: 'granola',
                name: 'Crunchy Maple Granola',
                priceDelta: 1.50,
              ),
              CustomizationOption(
                id: 'peanut-butter',
                name: 'Peanut Butter Drizzle',
                priceDelta: 1.80,
              ),
            ],
          ),
        ],
      ),
      MenuItem(
        id: '$vendorId-teriyaki-bento',
        vendorId: vendorId,
        sessionIds: const ['lunch', 'dinner'],
        name: 'Grilled Teriyaki Chicken Bento',
        description: 'Char-grilled boneless chicken thigh glazed in house teriyaki, served with Japanese short-grain rice, edamame, tamagoyaki, and sesame salad.',
        price: 13.50,
        category: 'Bento Boxes',
        customizationGroups: const [
          CustomizationGroup(
            id: 'base',
            title: 'Carb Base',
            isRequired: true,
            allowMultiple: false,
            options: [
              CustomizationOption(
                id: 'white-rice',
                name: 'Japanese White Rice',
                isDefault: true,
              ),
              CustomizationOption(
                id: 'brown-rice',
                name: 'Multigrain Brown Rice',
                priceDelta: 1.00,
              ),
              CustomizationOption(
                id: 'salad-only',
                name: 'Double Greens (No Rice)',
              ),
            ],
          ),
          CustomizationGroup(
            id: 'bento-addons',
            title: 'Protein & Sides',
            isRequired: false,
            allowMultiple: true,
            options: [
              CustomizationOption(
                id: 'onsen-egg',
                name: 'Onsen Tamago Egg',
                priceDelta: 2.00,
              ),
              CustomizationOption(
                id: 'miso-soup',
                name: 'Warm Miso Soup',
                priceDelta: 2.50,
              ),
            ],
          ),
        ],
      ),
    ];
  }

  static List<MenuItem> _warungKopiMenu(String vendorId) {
    return [
      MenuItem(
        id: '$vendorId-roti-canai-set',
        vendorId: vendorId,
        sessionIds: const ['breakfast', 'supper'],
        name: 'Roti Canai Banjir & Telur Goyang',
        description: 'Two flaky hand-tossed roti canai drenched in dhal & chicken curry with two soft-boiled kampung eggs.',
        price: 6.50,
        category: 'Breakfast & Supper',
        customizationGroups: const [
          CustomizationGroup(
            id: 'gravy',
            title: 'Curry Style',
            isRequired: true,
            allowMultiple: false,
            options: [
              CustomizationOption(
                id: 'banjir',
                name: 'Banjir (Flooded on Roti)',
                isDefault: true,
              ),
              CustomizationOption(
                id: 'separate',
                name: 'Pack Gravy Separately',
              ),
            ],
          ),
          CustomizationGroup(
            id: 'warung-extras',
            title: 'Add More',
            isRequired: false,
            allowMultiple: true,
            options: [
              CustomizationOption(
                id: 'roti-telur',
                name: 'Upgrade 1pc to Roti Telur',
                priceDelta: 1.50,
              ),
              CustomizationOption(
                id: 'kopi-o',
                name: 'Kopi O Kaw (Iced)',
                priceDelta: 2.20,
              ),
            ],
          ),
        ],
      ),
      MenuItem(
        id: '$vendorId-maggi-goreng',
        vendorId: vendorId,
        sessionIds: const ['supper'],
        name: 'Maggi Goreng Mamak Special',
        description: 'Wok-fried instant noodles with mustard greens, tofu, fried egg, and crispy chicken strips.',
        price: 7.80,
        category: 'Supper',
        customizationGroups: const [
          CustomizationGroup(
            id: 'spice',
            title: 'Spice Level',
            isRequired: true,
            allowMultiple: false,
            options: [
              CustomizationOption(
                id: 'regular',
                name: 'Regular Mamak Style',
                isDefault: true,
              ),
              CustomizationOption(id: 'pedas', name: 'Extra Cili Padi'),
            ],
          ),
        ],
      ),
    ];
  }
}
