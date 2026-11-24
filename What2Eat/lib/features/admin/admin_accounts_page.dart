import 'package:flutter/material.dart';

const accountPreviews = [
  (
    id: 'C001',
    name: 'Sarah Lim',
    username: 'sarah_demo',
    email: 'sarah@example.test',
    role: 'Customer',
    joined: '23 Nov 2026',
    status: 'Active',
  ),
  (
    id: 'C002',
    name: 'Ryan Lee',
    username: 'ryan_demo',
    email: 'ryan@example.test',
    role: 'Customer',
    joined: '22 Nov 2026',
    status: 'Suspended',
  ),
  (
    id: 'V001',
    name: 'Campus Bento',
    username: 'campus_bento_demo',
    email: 'bento@example.test',
    role: 'Vendor',
    joined: '21 Nov 2026',
    status: 'Active',
  ),
  (
    id: 'C003',
    name: 'Nadia Ali',
    username: 'nadia_demo',
    email: 'nadia@example.test',
    role: 'Customer',
    joined: '20 Nov 2026',
    status: 'Deactivated',
  ),
  (
    id: 'V002',
    name: 'Morning Bowl',
    username: 'morning_bowl_demo',
    email: 'morning@example.test',
    role: 'Vendor',
    joined: '19 Nov 2026',
    status: 'Active',
  ),
  (
    id: 'V003',
    name: 'Daily Greens',
    username: 'daily_greens_demo',
    email: 'greens@example.test',
    role: 'Vendor',
    joined: '18 Nov 2026',
    status: 'Suspended',
  ),
];

typedef AccountPreview = ({
  String id,
  String name,
  String username,
  String email,
  String role,
  String joined,
  String status,
});

class AdminAccountsPage extends StatefulWidget {
  const AdminAccountsPage({super.key});
  @override
  State<AdminAccountsPage> createState() => _AdminAccountsPageState();
}

class _AdminAccountsPageState extends State<AdminAccountsPage> {
  String _role = 'Customer';
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final accounts = accountPreviews
        .where(
          (account) =>
              account.role == _role &&
              '${account.name} ${account.email} ${account.username}'
                  .toLowerCase()
                  .contains(_query.trim().toLowerCase()),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Registered accounts',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w600,
            color: Color(0xFF253729),
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            for (final role in ['Customer', 'Vendor'])
              ChoiceChip(
                key: ValueKey('accounts-filter-$role'),
                label: Text(
                  '$role (${accountPreviews.where((account) => account.role == role).length})',
                ),
                selected: _role == role,
                selectedColor: const Color(0xFFFFD85C),
                onSelected: (_) => setState(() => _role = role),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('account-search'),
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            hintText: 'Search name, username or email',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${accounts.length} ${accounts.length == 1 ? 'account' : 'accounts'}',
          style: const TextStyle(fontSize: 14, color: Color(0xFF596451)),
        ),
        const SizedBox(height: 12),
        if (accounts.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No accounts match your search.',
              textAlign: TextAlign.center,
            ),
          ),
        for (final account in accounts)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AdminAccountCard(account: account),
          ),
        const SizedBox(height: 8),
        const Text(
          'Sample accounts · Interface preview',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Color(0xFF596451)),
        ),
      ],
    );
  }
}

class AdminAccountCard extends StatelessWidget {
  const AdminAccountCard({
    super.key,
    required this.account,
    this.compact = false,
  });
  final AccountPreview account;
  final bool compact;

  Future<void> _confirmSuspension(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Suspend account?'),
        scrollable: true,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              account.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(account.email),
            const SizedBox(height: 16),
            const Text(
              'Suspending an account would prevent the user from accessing What2Eat until access is restored.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Interface preview only. This confirmation will not change the account.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFA3342D),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm suspension'),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Suspension preview only. No account was changed.'),
      ),
    );
  }

  Widget _statusBadge() => Container(
    key: ValueKey('account-status-${account.id}'),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: switch (account.status) {
        'Active' => const Color(0xFFEEF1E4),
        'Suspended' => const Color(0xFFFFF0C0),
        _ => const Color(0xFFF1F1EF),
      },
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      account.status,
      style: const TextStyle(fontSize: 13, color: Color(0xFF344B35)),
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('account-${account.id}'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFCBD2BE)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFEEF1E4),
              foregroundColor: const Color(0xFF344B35),
              child: Icon(
                account.role == 'Vendor'
                    ? Icons.storefront_outlined
                    : Icons.person_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF253729),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${account.role} · Joined ${account.joined}',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Color(0xFF596451),
                    ),
                  ),
                ],
              ),
            ),
            if (!compact) ...[const SizedBox(width: 10), _statusBadge()],
          ],
        ),
        if (!compact) ...[
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.email,
                      style: const TextStyle(fontSize: 15, height: 1.2),
                    ),
                    Text(
                      '@${account.username}',
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.2,
                        color: Color(0xFF596451),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                key: ValueKey('suspend-account-${account.id}'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  foregroundColor: const Color(0xFFA3342D),
                  side: BorderSide(
                    color: account.status == 'Active'
                        ? const Color(0xFFA3342D)
                        : const Color(0xFFCBD2BE),
                  ),
                ),
                onPressed: account.status == 'Active'
                    ? () => _confirmSuspension(context)
                    : null,
                child: Text(
                  account.status == 'Active' ? 'Suspend' : account.status,
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
