import 'package:what2eat_starter/features/student/data/customer_discovery_repository.dart';
import 'package:what2eat_starter/features/student/data/customer_menu_repository.dart';
import 'package:what2eat_starter/features/student/models/customer_discovery_models.dart';

MenuSessionWindow menuWindow({
  String id = 'open-menu',
  MealSession session = CustomerDiscoveryRepository.lunchSession,
  int offset = 0,
}) {
  final now = DateTime.now();
  return MenuSessionWindow(
    menuId: id,
    session: session,
    menuDate: DateTime(now.year, now.month, now.day),
    orderOpeningAt: now.add(Duration(hours: offset - 1)),
    orderClosingAt: now.add(Duration(hours: offset + 1)),
  );
}

const menuVendor = VendorProfile(
  id: 'menu-vendor',
  businessName: 'Campus Kitchen',
  businessDescription: 'Fresh campus meals',
  businessContactNumber: '0123456789',
  businessAddress: 'Campus',
  universityIds: ['utm'],
  offeredSessions: [],
  availableDatesBySession: {},
  menuItems: [],
);

const browseItems = [
  MenuItem(
    id: 'rice',
    vendorId: 'menu-vendor',
    sessionIds: ['lunch'],
    name: 'Chicken rice',
    description: 'Steamed rice with roast chicken',
    price: 9.5,
    category: 'Rice',
    customizationGroups: [
      CustomizationGroup(
        id: 'spice',
        title: 'Spice level',
        isRequired: true,
        allowMultiple: false,
        maxSelections: 1,
        options: [
          CustomizationOption(id: 'mild', name: 'Mild'),
          CustomizationOption(id: 'hot', name: 'Hot', priceDelta: 1),
        ],
      ),
    ],
  ),
  MenuItem(
    id: 'tea',
    vendorId: 'menu-vendor',
    sessionIds: ['lunch'],
    name: 'Lemon tea',
    description: 'Freshly brewed',
    price: 3,
    category: 'Drinks',
    isAvailable: false,
  ),
];

class FakeMenuRepository extends CustomerMenuRepository {
  bool fail = false;
  List<MenuItem> items = browseItems;
  int calls = 0;
  @override
  Future<CustomerMenu> loadMenu({
    required String vendorId,
    required String menuId,
  }) async {
    calls++;
    if (fail) {
      throw const MenuBrowseFailure(
        'Could not load this menu. Please try again.',
      );
    }
    return CustomerMenu(
      window: menuWindow(id: menuId),
      items: items,
      deliveryTimeRange: '12:00 – 13:00',
    );
  }
}

class MenuDiscoveryFixture extends CustomerDiscoveryRepository {
  @override
  Future<CustomerDiscoveryData> loadDiscoveryData() async =>
      CustomerDiscoveryData(
        universities: const [
          UniversityOption(
            id: 'utm',
            code: 'UTM',
            name: 'Universiti Teknologi Malaysia',
          ),
        ],
        vendors: const [menuVendor],
        defaultUniversityId: 'utm',
        menuSessions: {
          'menu-vendor': [
            menuWindow(),
            menuWindow(
              id: 'future-menu',
              session: CustomerDiscoveryRepository.dinnerSession,
              offset: 3,
            ),
          ],
        },
      );
}
