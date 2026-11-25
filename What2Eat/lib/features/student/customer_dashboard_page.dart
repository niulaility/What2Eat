import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../authentication/auth_page.dart';
import 'data/customer_discovery_repository.dart';
import 'models/customer_discovery_models.dart';
import 'theme/what2eat_theme.dart';
import 'vendor_profile_page.dart';

class CustomerDashboardPage extends StatefulWidget {
  const CustomerDashboardPage({
    super.key,
    required this.name,
    this.repository,
  });
import '../profile/account_page.dart';

class CustomerDashboardPage extends StatefulWidget {
  const CustomerDashboardPage({super.key, required this.name});

  final String name;
  final CustomerDiscoveryRepository? repository;

  @override
  State<CustomerDashboardPage> createState() => _CustomerDashboardPageState();
}

class _CustomerDashboardPageState extends State<CustomerDashboardPage> {
  late final CustomerDiscoveryRepository _repository;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;

  List<UniversityOption> _universities = [];
  List<VendorProfile> _allVendors = [];
  String? _selectedUniversityId;
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
        _selectedUniversityId =
            _selectedUniversityId ?? data.defaultUniversityId;
        if (_selectedUniversityId == null && _universities.isNotEmpty) {
          _selectedUniversityId = _universities.first.id;
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

  @override
  State<CustomerDashboardPage> createState() => _CustomerDashboardPageState();
}

class _CustomerDashboardPageState extends State<CustomerDashboardPage> {
  late String _name = widget.name;

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const AuthPage()),
      (route) => false,
    );
  }

  UniversityOption? get _selectedUniversity {
    for (final uni in _universities) {
      if (uni.id == _selectedUniversityId) return uni;
    }
    return _universities.isNotEmpty ? _universities.first : null;
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

  void _openUniversityPicker() {
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
                    itemCount: _universities.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final uni = _universities[index];
                      final isSelected = uni.id == _selectedUniversityId;
                      return InkWell(
                        onTap: () {
                          setState(() => _selectedUniversityId = uni.id);
                          Navigator.of(context).pop();
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
                                  uni.code.toUpperCase(),
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
                                  uni.name,
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

  void _openVendorProfile(
    VendorProfile vendor, {
    MealSession? initialSession,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VendorProfilePage(
          vendor: vendor,
          universities: _universities,
          initialDate: _selectedDate,
          initialSession: initialSession,
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

    return Scaffold(
      backgroundColor: What2EatTheme.creamBackground,
      appBar: AppBar(
        backgroundColor: What2EatTheme.creamBackground,
        elevation: 0,
        title: Text(
          'Welcome, ${widget.name}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: What2EatTheme.darkGreenText,
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
                          setState(() => _name = profile.displayName);
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
      body: _isLoading
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
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                      children: [
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
    );
  }

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
                        : 'Select University',
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
        hintStyle: const TextStyle(
          fontSize: 14,
          color: What2EatTheme.hintText,
        ),
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
    final bool isCustomDate = _selectedDate != null &&
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
                selected: _selectedDate != null &&
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
              vendor: vendor,
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
            color: selected
                ? What2EatTheme.goldenYellow
                : What2EatTheme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: What2EatTheme.darkGreenText,
              ),
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
    required this.vendor,
    required this.onTap,
  });

  final VendorProfile vendor;
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
                'Welcome, $_name',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: What2EatTheme.mutedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
