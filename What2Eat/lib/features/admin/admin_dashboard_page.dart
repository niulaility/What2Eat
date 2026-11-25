import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../authentication/auth_page.dart';
import '../profile/account_page.dart';
import '../profile/profile_repository.dart';
import '../../shared/widgets/dashboard_backdrop.dart';
import 'vendor_application_details_page.dart';
import 'vendor_application_preview_data.dart';
import 'admin_accounts_page.dart';
import 'admin_reviews_page.dart';
import 'admin_universities_page.dart';

const _cream = Color(0xFFFFFCF5);
const _ink = Color(0xFF253729);
const _green = Color(0xFF344B35);
const _muted = Color(0xFF596451);
const _line = Color(0xFFCBD2BE);
const _gold = Color(0xFFFFD85C);

/// The admin home interface. Application data is illustrative and read-only.
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({
    super.key,
    required this.name,
    this.profileRepository,
  });
  final String name;
  final ProfileRepository? profileRepository;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late String _name = widget.name;
  bool _expanded = false;
  int _selectedTab = 0;
  final _scroll = ScrollController();
  final _universities = ValueNotifier<List<String>>(
    List.of(sampleUniversityNames),
  );

  void _selectTab(int index) {
    setState(() => _selectedTab = index);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _universities.dispose();
    super.dispose();
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AccountPage(
          repository: widget.profileRepository,
          onUpdated: (profile) {
            if (mounted) setState(() => _name = profile.displayName);
          },
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const AuthPage()),
      (_) => false,
    );
  }

  TextStyle _text(
    double size, {
    Color color = _ink,
    FontWeight weight = FontWeight.w400,
  }) => TextStyle(
    fontFamily: 'Roboto',
    fontSize: size,
    height: 1.4,
    color: color,
    fontWeight: weight,
  );

  @override
  Widget build(BuildContext context) {
    final firstName = _name.trim().isEmpty
        ? 'Admin'
        : _name.trim().split(RegExp(r'\s+')).first;
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: _cream,
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
                  color: _gold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.ramen_dining_rounded,
                  size: 28,
                  color: _ink,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'What2Eat',
                style: _text(24, color: _green, weight: FontWeight.w700),
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
              color: _green,
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
            controller: _scroll,
            key: const ValueKey('admin-dashboard-scroll'),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_selectedTab == 1)
                      const AdminReviewsPage()
                    else if (_selectedTab == 2)
                      const AdminAccountsPage()
                    else if (_selectedTab == 3)
                      AdminUniversitiesPage(universities: _universities)
                    else ...[
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Welcome back, ',
                              style: _text(22, color: _muted),
                            ),
                            TextSpan(
                              text: '$firstName! 👋',
                              style: _text(28, weight: FontWeight.w700),
                            ),
                          ],
                        ),
                        style: _text(22),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        key: const ValueKey('pending-applications-panel'),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: _line),
                          boxShadow: [
                            BoxShadow(
                              color: _green.withValues(alpha: .05),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Pending vendor applications',
                              style: _text(21, weight: FontWeight.w600),
                            ),
                            const SizedBox(height: 20),
                            for (final application
                                in vendorApplicationPreviews
                                    .where(
                                      (application) =>
                                          application.status ==
                                          ApplicationReviewStatus.pending,
                                    )
                                    .take(
                                      _expanded
                                          ? vendorApplicationPreviews.length
                                          : 2,
                                    )) ...[
                              _applicationCard(application),
                              const SizedBox(height: 16),
                            ],
                            OutlinedButton.icon(
                              key: const ValueKey('toggle-applications'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                foregroundColor: _green,
                                side: const BorderSide(color: _muted),
                              ),
                              onPressed: () =>
                                  setState(() => _expanded = !_expanded),
                              icon: Icon(
                                _expanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                              ),
                              label: Text(
                                _expanded ? 'Show less' : 'Show more (1)',
                                style: _text(16, color: _green),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        key: const ValueKey('new-accounts-panel'),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: _line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Newly registered accounts',
                              style: _text(21, weight: FontWeight.w600),
                            ),
                            const SizedBox(height: 16),
                            for (final account in accountPreviews.take(2))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: AdminAccountCard(
                                  account: account,
                                  compact: true,
                                ),
                              ),
                            TextButton.icon(
                              onPressed: () => _selectTab(2),
                              icon: const Icon(Icons.people_outline),
                              label: const Text('View all accounts'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Sample content · Interface preview',
                        textAlign: TextAlign.center,
                        style: _text(12, color: _muted),
                      ),
                    ],
                  ],
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
            color: _cream,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: _ink, width: .8),
          ),
          child: Row(
            children: [
              for (final tab in const [
                (label: 'Home', icon: Icons.home_outlined),
                (label: 'Reviews', icon: Icons.fact_check_outlined),
                (label: 'Accounts', icon: Icons.people_outline),
                (label: 'Universities', icon: Icons.school_outlined),
                (label: 'Settings', icon: Icons.settings_outlined),
              ])
                Expanded(
                  child: Semantics(
                    selected: _tabSelected(tab.label),
                    button: true,
                    enabled: _tabEnabled(tab.label),
                    child: InkWell(
                      key: ValueKey('admin-tab-${tab.label}'),
                      onTap: _tabEnabled(tab.label)
                          ? () => _selectTab(_tabIndex(tab.label))
                          : null,
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _tabSelected(tab.label)
                                    ? _gold
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                tab.icon,
                                size: 25,
                                color: _tabSelected(tab.label)
                                    ? _green
                                    : _muted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              tab.label,
                              textAlign: TextAlign.center,
                              style: _text(
                                12,
                                color: _tabSelected(tab.label) ? _ink : _muted,
                                weight: FontWeight.w600,
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
      ),
    );
  }

  int _tabIndex(String label) => switch (label) {
    'Reviews' => 1,
    'Accounts' => 2,
    'Universities' => 3,
    _ => 0,
  };
  bool _tabEnabled(String label) =>
      ['Home', 'Reviews', 'Accounts', 'Universities'].contains(label);
  bool _tabSelected(String label) =>
      _tabEnabled(label) && _tabIndex(label) == _selectedTab;

  Widget _applicationCard(VendorApplicationPreview application) => Material(
    key: ValueKey(
      'admin-application-${application.id.substring(application.id.length - 3)}',
    ),
    color: _cream,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: _line),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              VendorApplicationDetailsPage(application: application),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF1E4),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Image.asset(
                    application.logoAsset,
                    excludeFromSemantics: true,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        application.businessName,
                        style: _text(20, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(application.owner, style: _text(14, color: _muted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.schedule, color: _green, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Submitted ${application.submitted}',
                    style: _text(14, color: _muted),
                  ),
                ),
              ],
            ),
            const Divider(height: 28, color: _line),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'View application details',
                    style: _text(15, color: _green, weight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, color: _green),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
