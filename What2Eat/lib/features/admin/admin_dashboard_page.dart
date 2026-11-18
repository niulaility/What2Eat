import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../authentication/auth_page.dart';
import '../profile/account_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key, required this.name});

  final String name;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late String _name = widget.name;
  final _client = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _applications;

  @override
  void initState() {
    super.initState();
    _applications = _loadApplications();
  }

  Future<List<Map<String, dynamic>>> _loadApplications() async {
    final rows = await _client
        .from('vendors')
        .select(
          'id, user_id, business_name, business_description, '
          'business_contact_number, business_address, logo_url, submitted_at',
        )
        .eq('status', 'pending')
        .order('submitted_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  void _refresh() {
    setState(() => _applications = _loadApplications());
  }

  Future<void> _review(
      Map<String, dynamic> application, String decision) async {
    String? reason;
    if (decision == 'rejected') {
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Reject application'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Reason for rejection',
              hintText: 'Tell the vendor what needs to be corrected',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) Navigator.pop(dialogContext, value);
              },
              child: const Text('Reject'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (reason == null || !mounted) return;
    }

    try {
      await _client.rpc(
        'review_vendor_application',
        params: {
          'p_vendor_id': application['id'],
          'p_decision': decision,
          'p_rejection_reason': reason,
        },
      );
      var decisionEmailSent = false;
      try {
        final response = await _client.functions.invoke(
          'vendor-review-notification',
          body: {'vendor_id': application['id']},
        );
        decisionEmailSent = response.status >= 200 &&
            response.status < 300 &&
            response.data is Map &&
            response.data['sent'] == true;
      } catch (error) {
        debugPrint('Vendor decision email failed: $error');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${decision == 'approved' ? 'Vendor approved. They can now sign in.' : 'Application rejected.'}'
            '${decisionEmailSent ? '' : ' Decision email could not be sent; check the Edge Function and Resend settings.'}',
          ),
        ),
      );
      _refresh();
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Could not review application: ${error.message}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not review application: $error')),
      );
    }
  }

  Future<void> _logout() async {
    await _client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const AuthPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFCF5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFCF5),
        elevation: 0,
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF253729),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh applications',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined,
                size: 28, color: Color(0xFF344B35)),
            tooltip: 'Account options',
            onSelected: (value) {
              if (value == 'logout') _logout();
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
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'profile',
                child: Row(children: [
                  Icon(Icons.person_outline, size: 20),
                  SizedBox(width: 12),
                  Text('Profile'),
                ]),
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
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _applications,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  Text('Could not load applications: ${snapshot.error}'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                      onPressed: _refresh, child: const Text('Retry')),
                ],
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final applications = snapshot.data!;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Text(
                  'Welcome, $_name',
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF253729),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Review vendor applications before granting access.',
                  style: TextStyle(color: Color(0xFF596451)),
                ),
                const SizedBox(height: 24),
                Text(
                  'Pending applications (${applications.length})',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF253729),
                  ),
                ),
                const SizedBox(height: 12),
                if (applications.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child:
                          Text('There are no vendor applications to review.'),
                    ),
                  ),
                ...applications.map((application) => _ApplicationCard(
                      application: application,
                      onApprove: () => _review(application, 'approved'),
                      onReject: () => _review(application, 'rejected'),
                    )),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.application,
    required this.onApprove,
    required this.onReject,
  });

  final Map<String, dynamic> application;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  Future<void> _showDocuments(BuildContext context) async {
    try {
      final client = Supabase.instance.client;
      final rows = await client
          .from('vendor_documents')
          .select('document_type, file_url')
          .eq('vendor_id', application['id']);
      final documents = <Map<String, String>>[];
      for (final row in rows) {
        final path = row['file_url'] as String;
        documents.add({
          'type': row['document_type'] as String,
          'url': await client.storage
              .from('vendor-documents')
              .createSignedUrl(path, 300),
        });
      }
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Application documents'),
          content: SizedBox(
            width: 520,
            child: documents.isEmpty
                ? const Text('No documents were submitted.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: documents.length,
                    itemBuilder: (context, index) {
                      final document = documents[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              document['type']!
                                  .replaceAll('_', ' ')
                                  .toUpperCase(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Image.network(
                              document['url']!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Text(
                                  'Could not display this document image.'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load application documents: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final logoUrl = application['logo_url'] as String?;
    final submittedAt =
        DateTime.tryParse(application['submitted_at'] as String? ?? '');
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFFFFEDAA),
                  backgroundImage:
                      logoUrl == null ? null : NetworkImage(logoUrl),
                  child: logoUrl == null
                      ? const Icon(Icons.storefront_outlined,
                          color: Color(0xFF344B35))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        application['business_name'] as String? ?? 'Vendor',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      if (submittedAt != null)
                        Text(
                            'Submitted ${submittedAt.toLocal().toString().substring(0, 16)}'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(application['business_description'] as String? ?? ''),
            const SizedBox(height: 10),
            _DetailLine(
                icon: Icons.phone_outlined,
                text: application['business_contact_number'] as String? ?? ''),
            _DetailLine(
                icon: Icons.location_on_outlined,
                text: application['business_address'] as String? ?? ''),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showDocuments(context),
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('View documents'),
                ),
                OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close, color: Colors.redAccent),
                  label: const Text('Reject'),
                ),
                FilledButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF667A43)),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );
}
