import 'dart:async';

import 'package:flutter/material.dart';

import 'data/customer_menu_repository.dart';
import 'models/customer_discovery_models.dart';
import 'theme/what2eat_theme.dart';
import 'widgets/menu_status_badge.dart';
import '../messaging/messaging_pages.dart';
import '../messaging/messaging_repository.dart';
import 'vendor_session_menu_page.dart';

/// Vendor profile for customers: business details, messaging, and every meal
/// session the vendor published for the selected date with its ordering
/// status. Only sessions within their ordering window open a menu.
class VendorProfilePage extends StatefulWidget {
  const VendorProfilePage({
    super.key,
    required this.vendor,
    required this.universities,
    this.initialDate,
    this.initialSession,
    this.menus,
    this.messagingRepository,
    this.menuRepository,
  });

  final VendorProfile vendor;
  final List<UniversityOption> universities;
  final DateTime? initialDate;
  final MealSession? initialSession;

  /// The vendor's published menus on [initialDate] (from `public.menus`), in
  /// any ordering status. `null` falls back to the vendor's sample sessions
  /// without ordering times (offline widget tests).
  final List<MenuSessionWindow>? menus;
  final MessagingRepository? messagingRepository;
  final CustomerMenuRepository? menuRepository;

  @override
  State<VendorProfilePage> createState() => _VendorProfilePageState();
}

class _VendorProfilePageState extends State<VendorProfilePage>
    with WidgetsBindingObserver {
  Timer? _boundary;
  VendorProfile get vendor => widget.vendor;
  DateTime? get initialDate => widget.initialDate;
  List<MenuSessionWindow>? get menus => widget.menus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  @override
  void didUpdateWidget(covariant VendorProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _schedule() {
    _boundary?.cancel();
    final now = DateTime.now();
    final times = [
      for (final menu in menus ?? <MenuSessionWindow>[]) ...[
        menu.orderOpeningAt,
        menu.orderClosingAt,
      ],
    ].where((time) => time.isAfter(now)).toList()..sort();
    if (times.isNotEmpty) {
      _boundary = Timer(
        times.first.difference(now) + const Duration(milliseconds: 1),
        () {
          if (!mounted) return;
          setState(() {});
          _schedule();
        },
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      _schedule();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _boundary?.cancel();
    super.dispose();
  }

  Future<void> _openMenu(MenuSessionWindow menu) async {
    if (!menu.isOpenAt(DateTime.now())) {
      setState(() {});
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => VendorSessionMenuPage(
          vendor: vendor,
          menu: menu,
          repository: widget.menuRepository,
        ),
      ),
    );
    if (mounted) {
      setState(() {});
      _schedule();
    }
  }

  static const _months = [
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

  List<MealSession> get _sampleSessions {
    if (initialDate != null) {
      final forDate = vendor.sessionsForDate(initialDate!);
      if (forDate.isNotEmpty) return forDate;
    }
    return vendor.offeredSessions;
  }

  /// e.g. "28 Nov, 10:00 AM".
  static String _formatDateTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour < 12 ? 'AM' : 'PM';
    return '${value.day} ${_months[value.month - 1]}, $hour:$minute $period';
  }

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    if (target == today) return 'Today';
    if (target == today.add(const Duration(days: 1))) return 'Tomorrow';
    return '${date.day} ${_months[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final tiles = menus == null
        ? [
            for (final s in _sampleSessions)
              _MealSessionTile(
                key: ValueKey('profile-session-${s.id}'),
                session: s,
              ),
          ]
        : [
            for (final menu in menus!)
              _MealSessionTile(
                key: ValueKey('profile-menu-${menu.menuId}'),
                session: menu.session,
                dateLabel: initialDate == null
                    ? _formatDateLabel(menu.menuDate)
                    : null,
                status: menu.statusAt(now),
                onTap: menu.isOpenAt(now) ? () => _openMenu(menu) : null,
                orderingWindow:
                    '${_formatDateTime(menu.orderOpeningAt)} – ${_formatDateTime(menu.orderClosingAt)}',
              ),
          ];

    return Scaffold(
      backgroundColor: What2EatTheme.creamBackground,
      appBar: AppBar(
        backgroundColor: What2EatTheme.creamBackground,
        elevation: 0,
        foregroundColor: What2EatTheme.darkGreenText,
        title: Text(
          vendor.businessName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: What2EatTheme.darkGreenText,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _buildVendorProfileCard(),
          const SizedBox(height: 16),
          MessageVendorButton(
            vendorId: vendor.id,
            vendorName: vendor.businessName,
            repository: widget.messagingRepository,
          ),
          const SizedBox(height: 20),
          if (tiles.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: What2EatTheme.border),
              ),
              child: Text(
                initialDate != null
                    ? 'No menu for ${_formatDateLabel(initialDate!)}.'
                    : 'No menu yet.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: What2EatTheme.mutedText,
                ),
              ),
            )
          else ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Meal Sessions',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: What2EatTheme.darkGreenText,
                    ),
                  ),
                ),
                if (initialDate != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: What2EatTheme.softYellowBadge,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: What2EatTheme.darkGreenText,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _formatDateLabel(initialDate!),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: What2EatTheme.darkGreenText,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...tiles,
          ],
        ],
      ),
    );
  }

  Widget _buildVendorProfileCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: What2EatTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: What2EatTheme.border),
                ),
                child: vendor.logoUrl?.isNotEmpty == true
                    ? Image.network(
                        vendor.logoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const _LogoFallback(),
                      )
                    : const _LogoFallback(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  vendor.businessName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: What2EatTheme.darkGreenText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            vendor.businessDescription,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: What2EatTheme.mutedText,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: What2EatTheme.divider, height: 1),
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.location_on_outlined,
            text: vendor.businessAddress,
          ),
          const SizedBox(height: 6),
          _DetailRow(
            icon: Icons.phone_outlined,
            text: vendor.businessContactNumber,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 16, color: What2EatTheme.oliveAccent),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12.5,
            color: What2EatTheme.mutedText,
          ),
        ),
      ),
    ],
  );
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback();

  @override
  Widget build(BuildContext context) => const Center(
    child: Icon(
      Icons.storefront_rounded,
      color: What2EatTheme.forestGreen,
      size: 30,
    ),
  );
}

/// Closed and scheduled sessions remain visible but cannot be opened.
class _MealSessionTile extends StatelessWidget {
  const _MealSessionTile({
    super.key,
    required this.session,
    this.dateLabel,
    this.status,
    this.orderingWindow,
    this.onTap,
  });

  final MealSession session;

  /// Meal date, shown when no date is selected (e.g. "Tomorrow").
  final String? dateLabel;

  /// Ordering status now; null for offline sample data.
  final MenuOrderStatus? status;

  /// "opens – closes" ordering window text; null for offline sample data.
  final String? orderingWindow;
  final VoidCallback? onTap;

  /// Only sessions in their ordering window are tappable.
  bool get isOrderable => status == MenuOrderStatus.open;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: status == null || isOrderable ? 1 : 0.6,
      child: Semantics(
        button: true,
        enabled: onTap != null,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: _buildTile(),
          ),
        ),
      ),
    );
  }

  Widget _buildTile() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: What2EatTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: What2EatTheme.softYellowBadge,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              session.icon,
              size: 24,
              color: What2EatTheme.darkGreenText,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      dateLabel == null
                          ? session.name
                          : '${session.name} · $dateLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: What2EatTheme.darkGreenText,
                      ),
                    ),
                    if (status != null) MenuStatusBadge(status: status!),
                  ],
                ),
                if (orderingWindow != null) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Ordering window',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: What2EatTheme.oliveAccent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.schedule_outlined,
                          size: 13,
                          color: What2EatTheme.subtleText,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          orderingWindow!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: What2EatTheme.subtleText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: What2EatTheme.forestGreen),
          ],
        ],
      ),
    );
  }
}
