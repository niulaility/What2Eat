import 'package:flutter/material.dart';

import 'models/customer_discovery_models.dart';
import 'theme/what2eat_theme.dart';
import 'vendor_session_menu_page.dart';
import '../messaging/messaging_pages.dart';
import '../messaging/messaging_repository.dart';

class VendorProfilePage extends StatelessWidget {
  const VendorProfilePage({
    super.key,
    required this.vendor,
    required this.universities,
    this.initialDate,
    this.initialSession,
    this.messagingRepository,
  });

  final VendorProfile vendor;
  final List<UniversityOption> universities;
  final DateTime? initialDate;
  final MealSession? initialSession;
  final MessagingRepository? messagingRepository;

  List<MealSession> get _availableSessions {
    if (initialDate != null) {
      final forDate = vendor.sessionsForDate(initialDate!);
      if (forDate.isNotEmpty) return forDate;
    }
    return vendor.offeredSessions;
  }

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    if (target == today) return 'Today';
    if (target == today.add(const Duration(days: 1))) return 'Tomorrow';
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

  void _openSessionMenu(BuildContext context, MealSession session) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VendorSessionMenuPage(
          vendor: vendor,
          session: session,
          selectedDate: initialDate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _availableSessions;

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
            repository: messagingRepository,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Choose Meal Session',
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
          for (final session in sessions)
            _MealSessionTile(
              session: session,
              itemCount: vendor.menuForSession(session.id).length,
              onTap: () => _openSessionMenu(context, session),
            ),
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
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: What2EatTheme.border),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: What2EatTheme.forestGreen,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vendor.businessName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: What2EatTheme.darkGreenText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: Color(0xFFE5B628),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          vendor.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: What2EatTheme.darkGreenText,
                          ),
                        ),
                      ],
                    ),
                  ],
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
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: What2EatTheme.oliveAccent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  vendor.businessAddress,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: What2EatTheme.mutedText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.phone_outlined,
                size: 16,
                color: What2EatTheme.oliveAccent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  vendor.businessContactNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: What2EatTheme.mutedText,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MealSessionTile extends StatelessWidget {
  const _MealSessionTile({
    required this.session,
    required this.itemCount,
    required this.onTap,
  });

  final MealSession session;
  final int itemCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: What2EatTheme.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
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
                    Text(
                      session.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: What2EatTheme.darkGreenText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${session.timeRange} ($itemCount ${itemCount == 1 ? 'item' : 'items'})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: What2EatTheme.subtleText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_outlined,
                          size: 13,
                          color: What2EatTheme.oliveAccent,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Last order: ${session.lastOrderTime}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: What2EatTheme.oliveAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: What2EatTheme.forestGreen,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
