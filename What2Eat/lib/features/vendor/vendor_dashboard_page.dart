import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/widgets/dashboard_backdrop.dart';
import '../authentication/auth_page.dart';
import '../profile/account_page.dart';
import '../profile/profile_repository.dart';
import 'vendor_catalog.dart';
import 'vendor_categories_page.dart';
import 'vendor_food_editor.dart';
import 'vendor_menu_editor.dart';
import 'vendor_ui.dart';

class VendorDashboardPage extends StatefulWidget {
  const VendorDashboardPage({
    super.key,
    required this.name,
    this.catalog,
    this.profileRepository,
  });
  final String name;
  final VendorCatalog? catalog;
  final ProfileRepository? profileRepository;
  @override
  State<VendorDashboardPage> createState() => _VendorDashboardPageState();
}

class _VendorDashboardPageState extends State<VendorDashboardPage>
    with WidgetsBindingObserver {
  late String _name = widget.name;
  late final VendorCatalog _catalog = widget.catalog ?? VendorCatalog();
  final _scroll = ScrollController();
  int _tab = 0;
  VendorMenuFilter _menuFilter = VendorMenuFilter.all;
  String? _category;
  Timer? _midnightRefresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _catalog.removeExpiredClosedMenus(DateTime.now());
    _scheduleMidnightRefresh();
  }

  void _scheduleMidnightRefresh() {
    _midnightRefresh?.cancel();
    final now = DateTime.now();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    _midnightRefresh = Timer(nextDay.difference(now), _refreshMenus);
  }

  void _refreshMenus() {
    if (!mounted) return;
    _catalog.removeExpiredClosedMenus(DateTime.now());
    setState(() {});
    _scheduleMidnightRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshMenus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightRefresh?.cancel();
    _scroll.dispose();
    if (widget.catalog == null) _catalog.dispose();
    super.dispose();
  }

  void _navigate(int tab) {
    setState(() => _tab = tab);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _openMenuFilter(String id) {
    setState(() {
      _menuFilter = switch (id) {
        'active' => VendorMenuFilter.active,
        'today' => VendorMenuFilter.today,
        _ => VendorMenuFilter.draft,
      };
      _tab = 1;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _openProfile() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => AccountPage(
        repository: widget.profileRepository,
        onUpdated: (profile) {
          if (mounted) setState(() => _name = profile.displayName);
        },
      ),
    ),
  );

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const AuthPage()),
      (_) => false,
    );
  }

  Future<void> _editMenu([VendorMenu? menu]) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (context) => Theme(
            data: vendorThemeData(context),
            child: VendorMenuEditor(catalog: _catalog, menu: menu),
          ),
        ),
      );
  Future<void> _editFood([VendorFood? food]) => Navigator.of(context)
      .push<void>(
        MaterialPageRoute(
          builder: (context) => Theme(
            data: vendorThemeData(context),
            child: VendorFoodEditor(
              catalog: _catalog,
              food: food,
              initialCategoryId:
                  _catalog.categories.any(
                    (category) => category.id == _category,
                  )
                  ? _category
                  : null,
            ),
          ),
        ),
      );
  Future<void> _editCategories() {
    final editorKey = GlobalKey<VendorCategoriesPageState>();
    return showDialog<void>(
      context: context,
      builder: (context) => Theme(
        data: vendorThemeData(context),
        child: Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 480,
              maxHeight: MediaQuery.sizeOf(context).height * .8,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Edit categories',
                    style: vendorText(24, weight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: ListenableBuilder(
                        listenable: _catalog,
                        builder: (_, _) => VendorCategoriesPage(
                          key: editorKey,
                          catalog: _catalog,
                          showHeading: false,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        if (editorKey.currentState?.saveChanges() ?? true) {
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _publish(VendorMenu menu) async {
    const action = 'Publish';
    final confirmed = await vendorConfirm(
      context,
      title: '$action menu?',
      action: action,
      message:
          '${menu.session.label} · ${vendorDate(menu.date)}\n\nThis changes the local preview only. It will not publish or remove a menu for real customers.',
    );
    if (!mounted || !confirmed) return;
    final error = _catalog.setPublished(menu.id, true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Menu published in the local preview.')),
    );
  }

  Future<void> _closeOrders(VendorMenu menu) async {
    final confirmed = await vendorConfirm(
      context,
      title: 'Close orders?',
      action: 'Close Order',
      message: 'Stop accepting new orders for this menu? It will remain published. This changes the local preview only.',
    );
    if (!mounted || !confirmed) return;
    final error = _catalog.closeMenuOrders(menu.id, DateTime.now());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Orders closed in the local preview.')),
    );
  }

  Future<void> _deleteMenu(VendorMenu menu) async {
    final confirmed = await vendorConfirm(
      context,
      title: 'Delete menu?',
      action: 'Delete',
      message:
          'Delete this ${menu.session.label.toLowerCase()} menu from the local preview? Your food catalog will be kept.',
    );
    if (!mounted || !confirmed) return;
    _catalog.removeMenu(menu.id);
  }

  Future<void> _removeFood(VendorFood food) async {
    if (await vendorConfirm(
      context,
      title: 'Remove food item?',
      action: 'Remove',
      message:
          'Remove “${food.name}” from this preview and its menus? Menus left without food will become drafts. No database records will change.',
    )) {
      _catalog.removeFood(food.id);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: vendorThemeData(context),
    child: Scaffold(
      backgroundColor: VendorColors.cream,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: VendorColors.cream,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 72,
        titleSpacing: 16,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: VendorColors.gold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.ramen_dining_rounded,
                  size: 28,
                  color: VendorColors.ink,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'What2Eat',
                style: vendorText(
                  24,
                  weight: FontWeight.w700,
                  color: VendorColors.green,
                ),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Account options',
            icon: const Icon(
              Icons.account_circle_outlined,
              size: 28,
              color: VendorColors.green,
            ),
            onSelected: (value) {
              if (value == 'profile') _openProfile();
              if (value == 'logout') _logout();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 20),
                    SizedBox(width: 12),
                    Text('Profile'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.redAccent),
                    SizedBox(width: 12),
                    Text('Logout', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomPaint(
        painter: DashboardBackdrop(),
        child: SizedBox.expand(
          child: SingleChildScrollView(
            key: const ValueKey('vendor-dashboard-scroll'),
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: ListenableBuilder(
                  listenable: _catalog,
                  builder: (context, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      switch (_tab) {
                        1 => _menusPage(),
                        2 => _foodsPage(),
                        _ => _home(),
                      },
                      const VendorPreviewNote(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          decoration: BoxDecoration(
            color: VendorColors.cream,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: VendorColors.ink, width: .8),
          ),
          child: Row(
            children: [
              for (final (index, label, icon) in const [
                (0, 'Home', Icons.home_outlined),
                (1, 'Menus', Icons.calendar_month_outlined),
                (2, 'Food', Icons.restaurant_menu),
                (3, 'Settings', Icons.settings_outlined),
              ])
                Expanded(
                  child: Semantics(
                    selected: _tab == index,
                    button: true,
                    enabled: index != 3,
                    child: InkWell(
                      key: ValueKey('vendor-tab-$label'),
                      onTap: index == 3 ? null : () => _navigate(index),
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _tab == index
                                    ? VendorColors.gold
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                icon,
                                size: 25,
                                color: _tab == index
                                    ? VendorColors.green
                                    : VendorColors.muted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              label,
                              textAlign: TextAlign.center,
                              style: vendorText(12, weight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _home() {
    final firstName = _name.trim().isEmpty
        ? 'there'
        : _name.trim().split(RegExp(r'\s+')).first;
    final counts = _catalog.menuCountsAt(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Welcome back, ',
                style: vendorText(22, color: VendorColors.muted),
              ),
              TextSpan(
                text: '$firstName! 👋',
                style: vendorText(28, weight: FontWeight.w700),
              ),
            ],
          ),
          style: vendorText(22),
        ),
        const SizedBox(height: 24),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _summaryCard(
                  'active',
                  'Active menus',
                  'Published and open for orders',
                  counts.active,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryCard(
                  'today',
                  "Today's menus",
                  'Published and scheduled for today',
                  counts.today,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryCard(
                  'draft',
                  'Draft menus',
                  'Not published',
                  counts.draft,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _editMenu,
          style: FilledButton.styleFrom(
            backgroundColor: VendorColors.green,
            foregroundColor: VendorColors.cream,
          ),
          icon: const Icon(Icons.add),
          label: const Text('Create menu'),
        ),
      ],
    );
  }

  Widget _summaryCard(String id, String label, String description, int count) =>
      Semantics(
        label: '$label: $count. $description',
        button: true,
        onTap: () => _openMenuFilter(id),
        excludeSemantics: true,
        child: Tooltip(
          message: description,
          child: Material(
            key: ValueKey('vendor-summary-$id'),
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: VendorColors.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openMenuFilter(id),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$count',
                      key: ValueKey('vendor-summary-$id-count'),
                      style: vendorText(32, weight: FontWeight.w500).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: vendorText(14, color: VendorColors.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Widget _menusPage() {
    final menus = _catalog.menusFor(_menuFilter, DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Menus', style: vendorText(23, weight: FontWeight.w600)),
        const SizedBox(height: 12),
        Tooltip(
          message: 'Create menu',
          child: FilledButton.icon(
            onPressed: _editMenu,
            style: FilledButton.styleFrom(
              backgroundColor: VendorColors.green,
              foregroundColor: VendorColors.cream,
            ),
            icon: const Icon(Icons.add),
            label: const Text('Create menu'),
          ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = (constraints.maxWidth - 24) / 4;
            final minimumWidth = MediaQuery.textScalerOf(context).scale(76);
            final width = availableWidth < minimumWidth
                ? minimumWidth
                : availableWidth;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final filter in VendorMenuFilter.values.where(
                    (filter) => filter != VendorMenuFilter.all,
                  )) ...[
                    if (filter != VendorMenuFilter.active)
                      const SizedBox(width: 8),
                    SizedBox(
                      width: width,
                      child: ChoiceChip(
                        shape: const StadiumBorder(),
                        key: ValueKey('vendor-menu-filter-${filter.name}'),
                        label: SizedBox(
                          width: double.infinity,
                          child: Text(
                            switch (filter) {
                              VendorMenuFilter.active => 'Active',
                              VendorMenuFilter.today => 'Today',
                              VendorMenuFilter.draft => 'Draft',
                              VendorMenuFilter.published => 'Published',
                              VendorMenuFilter.all => 'All',
                            },
                            textAlign: TextAlign.center,
                            style: vendorText(13),
                          ),
                        ),
                        labelPadding: EdgeInsets.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        showCheckmark: false,
                        selected: _menuFilter == filter,
                        backgroundColor: Colors.white,
                        selectedColor: VendorColors.gold,
                        onSelected: (selected) => setState(
                          () => _menuFilter = selected
                              ? filter
                              : VendorMenuFilter.all,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Text(
            '${menus.length} ${menus.length == 1 ? 'menu' : 'menus'}',
            style: vendorText(14, color: VendorColors.muted),
          ),
        ),
        const SizedBox(height: 12),
        if (menus.isEmpty)
          const VendorPanel(
            child: Text(
              'No menus in this view. Choose Create menu to add one.',
            ),
          ),
        for (final menu in menus)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _menuCard(menu),
          ),
      ],
    );
  }

  Widget _menuCard(VendorMenu menu) {
    final now = DateTime.now();
    final active = matchesVendorMenuFilter(menu, VendorMenuFilter.active, now);
    final status = !menu.isPublished
        ? 'Draft'
        : active
        ? 'Active'
        : !now.isBefore(menu.closingAt)
        ? 'Orders closed'
        : 'Published';
    final actions = <Widget>[
      FilledButton(
        key: ValueKey('edit-${menu.id}'),
        style: vendorActionStyle(),
        onPressed: () => _editMenu(menu),
        child: const Text('Edit'),
      ),
      if (!menu.isPublished)
        FilledButton(
          key: ValueKey('publish-${menu.id}'),
          style: vendorActionStyle(
            background: VendorColors.gold,
            foreground: VendorColors.ink,
          ),
          onPressed: () => _publish(menu),
          child: const Text('Publish'),
        ),
      if (_menuFilter != VendorMenuFilter.published && active)
        FilledButton(
          key: ValueKey('close-orders-${menu.id}'),
          style: vendorActionStyle(
            background: VendorColors.dangerSurface,
            foreground: VendorColors.danger,
          ),
          onPressed: () => _closeOrders(menu),
          child: const Text('Close Order'),
        )
      else if (menu.isPublished)
        FilledButton(
          key: ValueKey('delete-menu-${menu.id}'),
          style: vendorActionStyle(
            background: VendorColors.dangerSurface,
            foreground: VendorColors.danger,
          ),
          onPressed: () => _deleteMenu(menu),
          child: const Text('Delete'),
        ),
    ];
    return VendorPanel(
      key: ValueKey('vendor-menu-${menu.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Text.rich(
                  key: ValueKey('menu-date-${menu.id}'),
                  TextSpan(
                    children: [
                      TextSpan(text: menu.session.label),
                      TextSpan(
                        text: ' (${vendorDate(menu.date)})',
                        style: vendorText(18, weight: FontWeight.w600),
                      ),
                    ],
                  ),
                  style: vendorText(18, weight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    key: ValueKey('menu-status-${menu.id}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: menu.isPublished
                          ? VendorColors.sage
                          : VendorColors.draft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      textAlign: TextAlign.center,
                      style: vendorText(12, color: VendorColors.green),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${menu.foodIds.length} ${menu.foodIds.length == 1 ? 'food item' : 'food items'}',
            key: ValueKey('menu-food-count-${menu.id}'),
            style: vendorText(14, weight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _menuWindow('Ordering opens', menu.openingAt),
          const SizedBox(height: 8),
          _menuWindow('Ordering closes', menu.closingAt),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                'Estimated delivery',
                style: vendorText(13, color: VendorColors.muted),
              ),
              Text(
                '${vendorTime(menu.deliveryStart)}–${vendorTime(menu.deliveryEnd)}',
                style: vendorText(16, weight: FontWeight.w500),
              ),
            ],
          ),
          const Divider(height: 24, color: VendorColors.line),
          LayoutBuilder(
            builder: (context, constraints) {
              final minimumWidth = MediaQuery.textScalerOf(context).scale(88);
              final columns = ((constraints.maxWidth + 8) / (minimumWidth + 8))
                  .floor()
                  .clamp(1, actions.length);
              final width =
                  (constraints.maxWidth - (columns - 1) * 8) / columns;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final action in actions)
                    SizedBox(width: width, child: action),
                ],
              );
            },
          ),
          if (!menu.isPublished) ...[
            const SizedBox(height: 8),
            FilledButton(
              key: ValueKey('delete-menu-${menu.id}'),
              style: vendorActionStyle(
                background: VendorColors.dangerSurface,
                foreground: VendorColors.danger,
              ),
              onPressed: () => _deleteMenu(menu),
              child: const Text('Delete'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _menuWindow(String label, DateTime value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        flex: 2,
        child: Text(label, style: vendorText(13, color: VendorColors.muted)),
      ),
      const SizedBox(width: 8),
      Expanded(
        flex: 3,
        child: Text(
          '${vendorDate(value)} · ${vendorTime(value.hour * 60 + value.minute)}',
          textAlign: TextAlign.end,
          style: vendorText(13),
        ),
      ),
    ],
  );

  Widget _foodsPage() {
    final selected =
        _category == '' ||
            _catalog.categories.any((category) => category.id == _category)
        ? _category
        : null;
    final foods = _catalog.foods.where(
      (food) => selected == null || (food.categoryId ?? '') == selected,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const VendorSectionTitle('Food & categories'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              shape: const StadiumBorder(),
              label: const Text('All'),
              selected: selected == null,
              selectedColor: VendorColors.gold,
              onSelected: (_) => setState(() => _category = null),
            ),
            for (final category in _catalog.categories)
              ChoiceChip(
                shape: const StadiumBorder(),
                label: Text(category.name),
                selected: selected == category.id,
                selectedColor: VendorColors.gold,
                onSelected: (_) => setState(() => _category = category.id),
              ),
            ChoiceChip(
              key: const ValueKey('vendor-category-uncategorized'),
              shape: const StadiumBorder(),
              label: const Text('Uncategorized'),
              selected: selected == '',
              selectedColor: VendorColors.gold,
              onSelected: (_) => setState(() => _category = ''),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filledTonal(
                  key: const ValueKey('vendor-add-category'),
                  tooltip: 'Add category',
                  style: IconButton.styleFrom(
                    backgroundColor: VendorColors.sage,
                    foregroundColor: VendorColors.green,
                    minimumSize: const Size(36, 36),
                    fixedSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.padded,
                  ),
                  onPressed: () => showVendorCategoryDialog(context, _catalog),
                  icon: const Icon(Icons.add),
                ),
                IconButton.filledTonal(
                  key: const ValueKey('vendor-edit-categories'),
                  tooltip: 'Edit categories',
                  style: IconButton.styleFrom(
                    backgroundColor: VendorColors.sage,
                    foregroundColor: VendorColors.green,
                    minimumSize: const Size(36, 36),
                    fixedSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.padded,
                    shape: const CircleBorder(),
                  ),
                  onPressed: _editCategories,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('vendor-create-food'),
          onPressed: _editFood,
          style: FilledButton.styleFrom(
            backgroundColor: VendorColors.green,
            foregroundColor: VendorColors.cream,
          ),
          icon: const Icon(Icons.add),
          label: const Text('Create item'),
        ),
        const SizedBox(height: 16),
        if (foods.isEmpty)
          const VendorPanel(child: Text('No food items in this view yet.')),
        for (final food in foods)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _foodCard(food),
          ),
      ],
    );
  }

  Widget _foodCard(VendorFood food) => VendorPanel(
    key: ValueKey('vendor-food-${food.id}'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VendorFoodImage(bytes: food.imageBytes, asset: food.assetImage),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    style: vendorText(19, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'RM ${food.price.toStringAsFixed(2)}',
                    style: vendorText(18, weight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (food.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            food.description,
            style: vendorText(14, color: VendorColors.muted),
          ),
        ],
        if (!food.isAvailable) ...[
          const SizedBox(height: 10),
          Text('Unavailable', style: vendorText(13, color: VendorColors.muted)),
        ],
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 4,
          children: [
            IconButton(
              key: ValueKey('edit-food-${food.id}'),
              tooltip: 'Edit ${food.name}',
              onPressed: () => _editFood(food),
              icon: const Icon(Icons.edit_outlined, color: VendorColors.green),
            ),
            IconButton(
              key: ValueKey('remove-food-${food.id}'),
              tooltip: 'Remove ${food.name}',
              onPressed: () => _removeFood(food),
              icon: const Icon(
                Icons.delete_outline,
                color: VendorColors.danger,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
