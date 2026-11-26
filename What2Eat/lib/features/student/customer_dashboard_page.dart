import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../authentication/auth_page.dart';
import '../profile/account_page.dart';
import '../messaging/messaging_pages.dart';
import '../messaging/messaging_repository.dart';
import '../../shared/widgets/dashboard_backdrop.dart';
import 'data/customer_discovery_repository.dart';
import 'models/customer_discovery_models.dart';
import 'theme/what2eat_theme.dart';
import 'vendor_profile_page.dart';

class CustomerDashboardPage extends StatefulWidget {
  const CustomerDashboardPage({
    super.key,
    required this.name,
    this.repository,
    this.messagingRepository,
  });

  final String name;
  final CustomerDiscoveryRepository? repository;
  final MessagingRepository? messagingRepository;

  @override
  State<CustomerDashboardPage> createState() => _CustomerDashboardPageState();
}

class _CustomerDashboardPageState extends State<CustomerDashboardPage> {
  late String _name = widget.name;
  late final CustomerDiscoveryRepository _repository;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;

  List<UniversityOption> _universities = [];
  List<VendorProfile> _allVendors = [];
  String? _selectedUniversityId;
  bool _hasInitializedUniversity = false;
  DateTime? _selectedDate;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? CustomerDiscoveryRepository();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _repository.loadDiscoveryData();
      if (!mounted) return;
      setState(() {
        _universities = data.universities;
        _allVendors = data.vendors;
        if (!_hasInitializedUniversity) {
          _selectedUniversityId = data.defaultUniversityId;
          _hasInitializedUniversity = true;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load campus vendors. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const AuthPage()),
      (route) => false,
    );
  }

  UniversityOption? get _selectedUniversity {
    final id = _selectedUniversityId;
    if (id == null) return null;
    for (final uni in _universities) {
      if (uni.id == id) return uni;
    }
    return null;
  }

  List<VendorProfile> get _filteredVendors {
    final uniId = _selectedUniversityId;
    final query = _searchQuery.trim().toLowerCase();
    final date = _selectedDate;

    return _allVendors.where((vendor) {
      final servesUni = uniId == null || vendor.universityIds.contains(uniId);
      if (!servesUni) return false;
      if (query.isNotEmpty &&
          !vendor.businessName.toLowerCase().contains(query)) {
        return false;
      }
      if (date != null && vendor.sessionsForDate(date).isEmpty) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _pickMealDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 14)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: What2EatTheme.forestGreen,
              onPrimary: Colors.white,
              surface: What2EatTheme.creamBackground,
              onSurface: What2EatTheme.darkGreenText,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectUniversity(String? universityId) async {
    if (_selectedUniversityId == universityId && _hasInitializedUniversity) {
      return;
    }
    setState(() {
      _selectedUniversityId = universityId;
      _hasInitializedUniversity = true;
    });
    try {
      await _repository.updateSelectedUniversity(universityId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not save university selection. Please try again.'),
          ),
        );
    }
  }

  void _openUniversityPicker() {
    final pickerOptions = <UniversityOption?>[..._universities, null];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: What2EatTheme.creamBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Your University',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: What2EatTheme.darkGreenText,
                  ),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: pickerOptions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final uni = pickerOptions[index];
                      final isSelected = uni?.id == _selectedUniversityId;
                      final codeLabel =
                          uni != null ? uni.code.toUpperCase() : 'OTHER';
                      final nameLabel =
                          uni != null ? uni.name : 'Other / not listed';
                      return InkWell(
                        onTap: () {
                          Navigator.of(context).pop();
                          _selectUniversity(uni?.id);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? What2EatTheme.softSurfaceAlt
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? What2EatTheme.forestGreen
                                  : What2EatTheme.border,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? What2EatTheme.goldenYellow
                                      : What2EatTheme.softSurface,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  codeLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: What2EatTheme.darkGreenText,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  nameLabel,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: What2EatTheme.darkGreenText,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: What2EatTheme.forestGreen,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openVendorProfile(VendorProfile vendor, {MealSession? initialSession}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VendorProfilePage(
          vendor: vendor,
          universities: _universities,
          initialDate: _selectedDate,
          initialSession: initialSession,
          messagingRepository: widget.messagingRepository,
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatDateShort(DateTime date) {
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
    return '${date.day} ${months[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final selectedUni = _selectedUniversity;
    final firstName = _name.trim().isEmpty
        ? 'there'
        : _name.trim().split(RegExp(r'\s+')).first;

    return Scaffold(
      backgroundColor: What2EatTheme.creamBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: What2EatTheme.creamBackground,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 72,
        titleSpacing: 16,
        elevation: 0,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: What2EatTheme.goldenYellow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.ramen_dining_rounded,
                  size: 28,
                  color: What2EatTheme.darkGreenText,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'What2Eat',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: What2EatTheme.forestGreen,
                ),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.account_circle_outlined,
              size: 28,
              color: What2EatTheme.forestGreen,
            ),
            tooltip: 'Account options',
            onSelected: (value) {
              if (value == 'profile') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AccountPage(
                      onUpdated: (profile) {
                        if (mounted) {
                          setState(() {
                            _name = profile.displayName;
                            if (profile.universityId == null ||
                                _universities.any(
                                  (u) => u.id == profile.universityId,
                                )) {
                              _selectedUniversityId = profile.universityId;
                              _hasInitializedUniversity = true;
                            }
                          });
                        }
                      },
                    ),
                  ),
                );
              } else if (value == 'logout') {
                _logout(context);
              }
            },
            itemBuilder: (context) => const [
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
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: What2EatTheme.forestGreen,
                  ),
                )
              : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_outlined,
                          size: 44,
                          color: What2EatTheme.oliveAccent,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: What2EatTheme.darkGreenText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: _loadData,
                          style: FilledButton.styleFrom(
                            backgroundColor: What2EatTheme.goldenYellow,
                            foregroundColor: What2EatTheme.darkGreenText,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: RefreshIndicator(
                    color: What2EatTheme.forestGreen,
                    onRefresh: _loadData,
                    child: ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Welcome back, ',
                                  style: TextStyle(
                                    fontSize: 22,
                                    color: What2EatTheme.mutedText,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                TextSpan(
                                  text: '$firstName! 👋',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: What2EatTheme.darkGreenText,
                                  ),
                                ),
                              ],
                            ),
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 22,
                              height: 1.4,
                            ),
                          ),
                        ),
                        _buildUniversitySelector(selectedUni),
                        const SizedBox(height: 12),
                        _buildSearchField(),
                        const SizedBox(height: 12),
                        _buildMealDateFilter(today, tomorrow),
                        const SizedBox(height: 18),
                        _buildVendorsList(),
                      ],
                    ),
                  ),
                ),
        ),
      ),
      bottomNavigationBar: _buildNavigationBar(),
    );
  }

  Widget _buildNavigationBar() => SafeArea(
    top: false,
    child: Container(
      key: const ValueKey('customer-navigation'),
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      decoration: BoxDecoration(
        color: What2EatTheme.creamBackground,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: What2EatTheme.darkGreenText, width: .8),
      ),
      child: Row(
        children: [
          for (final tab in const [
            (label: 'Home', icon: Icons.home_outlined),
            (label: 'Explore', icon: Icons.search_rounded),
            (label: 'Orders', icon: Icons.inventory_2_outlined),
            (label: 'Messages', icon: Icons.chat_bubble_outline_rounded),
            (label: 'Settings', icon: Icons.settings_outlined),
          ])
            Expanded(
              child: Semantics(
                selected: tab.label == 'Home',
                button: true,
                enabled: tab.label == 'Home' || tab.label == 'Messages',
                child: InkWell(
                  key: ValueKey('customer-tab-${tab.label}'),
                  onTap: tab.label == 'Messages'
                      ? () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => MessagesPage(
                              repository: widget.messagingRepository,
                            ),
                          ),
                        )
                      : tab.label == 'Home'
                      ? () {}
                      : null,
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
                            color: tab.label == 'Home'
                                ? What2EatTheme.goldenYellow
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            tab.icon,
                            size: 25,
                            color: tab.label == 'Home'
                                ? What2EatTheme.forestGreen
                                : What2EatTheme.mutedText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tab.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            color: What2EatTheme.darkGreenText,
                          ),
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
  );

  Widget _buildUniversitySelector(UniversityOption? selectedUni) {
    return InkWell(
      onTap: _openUniversityPicker,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: What2EatTheme.goldenYellow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5B628)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.school_outlined,
                size: 20,
                color: What2EatTheme.forestGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delivering to campus',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: What2EatTheme.mutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    selectedUni != null
                        ? '${selectedUni.code.toUpperCase()} • ${selectedUni.name}'
                        : 'OTHER • Other / not listed',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: What2EatTheme.darkGreenText,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: What2EatTheme.darkGreenText,
              size: 26,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onChanged: (value) => setState(() => _searchQuery = value),
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      decoration: InputDecoration(
        hintText: 'Search vendor',
        hintStyle: const TextStyle(fontSize: 14, color: What2EatTheme.hintText),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: What2EatTheme.forestGreen,
        ),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                icon: const Icon(Icons.close_rounded, size: 20),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: What2EatTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: What2EatTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: What2EatTheme.forestGreen,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildMealDateFilter(DateTime today, DateTime tomorrow) {
    final bool isCustomDate =
        _selectedDate != null &&
        !_isSameDay(_selectedDate!, today) &&
        !_isSameDay(_selectedDate!, tomorrow);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Meal Date',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: What2EatTheme.darkGreenText,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _DateFilterChip(
                label: 'All Dates',
                selected: _selectedDate == null,
                onTap: () => setState(() => _selectedDate = null),
              ),
              const SizedBox(width: 8),
              _DateFilterChip(
                label: 'Today (${_formatDateShort(today)})',
                selected:
                    _selectedDate != null && _isSameDay(_selectedDate!, today),
                onTap: () => setState(() => _selectedDate = today),
              ),
              const SizedBox(width: 8),
              _DateFilterChip(
                label: 'Tomorrow (${_formatDateShort(tomorrow)})',
                selected:
                    _selectedDate != null &&
                    _isSameDay(_selectedDate!, tomorrow),
                onTap: () => setState(() => _selectedDate = tomorrow),
              ),
              const SizedBox(width: 8),
              _DateFilterChip(
                label: isCustomDate
                    ? _formatDateShort(_selectedDate!)
                    : 'Pick Date',
                icon: Icons.calendar_today_outlined,
                selected: isCustomDate,
                onTap: _pickMealDate,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVendorsList() {
    final vendors = _filteredVendors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Featured Vendors',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: What2EatTheme.darkGreenText,
                ),
              ),
            ),
            Text(
              '${vendors.length} found',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: What2EatTheme.subtleText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (vendors.isEmpty)
          _buildEmptyVendorsCard(
            _selectedDate == null
                ? 'No approved vendors match your current university or search.'
                : 'No vendors available on ${_formatDateShort(_selectedDate!)}. Try another date or select "All Dates".',
          )
        else
          for (final vendor in vendors)
            _VendorDiscoveryCard(
              key: ValueKey('customer-vendor-${vendor.id}'),
              vendor: vendor,
              sessions: _selectedDate == null
                  ? vendor.offeredSessions
                  : vendor.sessionsForDate(_selectedDate!),
              onTap: () => _openVendorProfile(vendor),
            ),
      ],
    );
  }

  Widget _buildEmptyVendorsCard(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: What2EatTheme.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.storefront_outlined,
            size: 42,
            color: What2EatTheme.oliveAccent,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: What2EatTheme.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateFilterChip extends StatelessWidget {
  const _DateFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? What2EatTheme.goldenYellow : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected ? What2EatTheme.goldenYellow : What2EatTheme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: What2EatTheme.darkGreenText),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: What2EatTheme.darkGreenText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VendorDiscoveryCard extends StatelessWidget {
  const _VendorDiscoveryCard({
    super.key,
    required this.vendor,
    required this.sessions,
    required this.onTap,
  });

  final VendorProfile vendor;
  final List<MealSession> sessions;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: What2EatTheme.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: What2EatTheme.softSurfaceAlt,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: What2EatTheme.forestGreen,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            vendor.businessName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: What2EatTheme.darkGreenText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: What2EatTheme.softYellowBadge,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 13,
                                color: What2EatTheme.darkGreenText,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                vendor.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: What2EatTheme.darkGreenText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                vendor.businessDescription,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: What2EatTheme.mutedText,
                ),
              ),
              if (sessions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final session in (List<MealSession>.of(
                      sessions,
                    )..sort((a, b) => a.sortOrder.compareTo(b.sortOrder))))
                      Container(
                        key: ValueKey(
                          'vendor-${vendor.id}-session-${session.id}',
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: What2EatTheme.softSurfaceAlt,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              session.icon,
                              size: 16,
                              color: What2EatTheme.forestGreen,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              session.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: What2EatTheme.darkGreenText,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
