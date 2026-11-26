import 'dart:async';

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
  List<VendorProfile>? _searchResults;
  String? _selectedUniversityId;
  bool _hasInitializedUniversity = false;
  String _searchQuery = '';
  Timer? _searchDebounce;
  int _searchRequestToken = 0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? CustomerDiscoveryRepository();
    _loadData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
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

  /// Approved vendors that serve the selected university, narrowed by search.
  /// "Other university" is a regular university row, so it filters the same
  /// way. With no university selected yet, nothing is shown.
  List<VendorProfile> get _filteredVendors {
    final uniId = _selectedUniversityId;
    if (uniId == null) return const [];
    final query = _searchQuery.trim().toLowerCase();
    final source = query.isNotEmpty && _searchResults != null
        ? _searchResults!
        : _allVendors;

    return source.where((vendor) {
      if (!vendor.universityIds.contains(uniId)) return false;
      if (query.isNotEmpty &&
          !vendor.businessName.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      if (value.trim().isEmpty) {
        _searchResults = null;
      }
    });
    _searchDebounce?.cancel();
    if (value.trim().isEmpty) return;
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _runRemoteSearch();
    });
  }

  Future<void> _runRemoteSearch() async {
    final query = _searchQuery.trim();
    if (query.isEmpty) {
      if (mounted) setState(() => _searchResults = null);
      return;
    }
    final token = ++_searchRequestToken;
    try {
      final results = await _repository.searchVendors(
        universityId: _selectedUniversityId,
        query: query,
      );
      if (!mounted || token != _searchRequestToken || results == null) return;
      setState(() => _searchResults = results);
    } catch (_) {
      // Keep current filtered results if network search fails transiently.
    }
  }

  Future<void> _selectUniversity(String? universityId) async {
    if (_selectedUniversityId == universityId && _hasInitializedUniversity) {
      return;
    }
    setState(() {
      _selectedUniversityId = universityId;
      _hasInitializedUniversity = true;
      _searchResults = null;
    });
    if (_searchQuery.trim().isNotEmpty) {
      _runRemoteSearch();
    }
    try {
      await _repository.updateSelectedUniversity(universityId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save university selection. Please try again.',
            ),
          ),
        );
    }
  }

  void _openUniversityPicker() {
    // "Other university" is a regular database row (listed last).
    final pickerOptions = _universities;
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
                      final isSelected = uni.id == _selectedUniversityId;
                      final codeLabel = uni.code.toUpperCase();
                      final nameLabel = uni.name;
                      return InkWell(
                        onTap: () {
                          Navigator.of(context).pop();
                          _selectUniversity(uni.id);
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

  @override
  Widget build(BuildContext context) {
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
                        : 'Select your university',
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
      onChanged: _onSearchChanged,
      onSubmitted: (_) {
        FocusScope.of(context).unfocus();
        _runRemoteSearch();
      },
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
                  _onSearchChanged('');
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
            _searchQuery.trim().isNotEmpty
                ? 'No approved vendors at this university match "${_searchQuery.trim()}".'
                : _selectedUniversityId == null
                ? 'Select your university to see vendors that deliver to your campus.'
                : 'No approved vendors deliver to this university yet.',
          )
        else
          for (final vendor in vendors)
            _VendorDiscoveryCard(
              key: ValueKey('customer-vendor-${vendor.id}'),
              vendor: vendor,
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

/// Display-only vendor summary. Opening a vendor (profile, sessions, menus) is
/// not wired yet.
class _VendorDiscoveryCard extends StatelessWidget {
  const _VendorDiscoveryCard({super.key, required this.vendor});

  final VendorProfile vendor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: What2EatTheme.border),
      ),
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
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: What2EatTheme.softSurfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: vendor.logoUrl?.isNotEmpty == true
                      ? Image.network(
                          vendor.logoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const _VendorLogoFallback(),
                        )
                      : const _VendorLogoFallback(),
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
          ],
        ),
      ),
    );
  }
}

class _VendorLogoFallback extends StatelessWidget {
  const _VendorLogoFallback();

  @override
  Widget build(BuildContext context) => const Center(
    child: Icon(
      Icons.storefront_rounded,
      color: What2EatTheme.forestGreen,
      size: 28,
    ),
  );
}
