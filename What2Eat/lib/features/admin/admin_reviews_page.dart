import 'package:flutter/material.dart';

import 'vendor_application_details_page.dart';
import 'vendor_application_repository.dart';

const _ink = Color(0xFF253729);
const _green = Color(0xFF344B35);
const _muted = Color(0xFF596451);

/// Shows a spinner, an error with retry, or [builder] with the loaded
/// applications.
class ApplicationsLoader extends StatelessWidget {
  const ApplicationsLoader({
    super.key,
    required this.applications,
    required this.onRetry,
    required this.builder,
  });
  final Future<List<VendorApplication>> applications;
  final VoidCallback onRetry;
  final Widget Function(List<VendorApplication> applications) builder;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<VendorApplication>>(
    future: applications,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Padding(
          key: const ValueKey('applications-error'),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_outlined, color: _green, size: 36),
              const SizedBox(height: 8),
              Text(
                snapshot.error is VendorApplicationFailure
                    ? snapshot.error.toString()
                    : 'Could not load vendor applications.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: _muted),
              ),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return builder(snapshot.data!);
    },
  );
}

class AdminReviewsPage extends StatefulWidget {
  const AdminReviewsPage({
    super.key,
    required this.applications,
    required this.onOpen,
    required this.onRetry,
  });
  final Future<List<VendorApplication>> applications;
  final ValueChanged<VendorApplication> onOpen;
  final VoidCallback onRetry;
  @override
  State<AdminReviewsPage> createState() => _AdminReviewsPageState();
}

class _AdminReviewsPageState extends State<AdminReviewsPage> {
  ApplicationReviewStatus? _status;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Vendor application reviews',
        style: TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w600,
          color: _ink,
        ),
      ),
      const SizedBox(height: 10),
      const Text(
        'Browse applications by their review status.',
        style: TextStyle(fontSize: 14, color: _muted),
      ),
      const SizedBox(height: 20),
      ApplicationsLoader(
        applications: widget.applications,
        onRetry: widget.onRetry,
        builder: _list,
      ),
    ],
  );

  Widget _list(List<VendorApplication> all) {
    final shown = all
        .where(
          (application) => _status == null || application.status == _status,
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              key: const ValueKey('reviews-filter-all'),
              label: Text('All (${all.length})'),
              selected: _status == null,
              selectedColor: const Color(0xFFFFD85C),
              onSelected: (_) => setState(() => _status = null),
            ),
            for (final status in ApplicationReviewStatus.values)
              ChoiceChip(
                key: ValueKey('reviews-filter-${status.name}'),
                label: Text(
                  '${status.name[0].toUpperCase()}${status.name.substring(1)} (${all.where((application) => application.status == status).length})',
                ),
                selected: _status == status,
                selectedColor: const Color(0xFFFFD85C),
                onSelected: (_) => setState(() => _status = status),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              _status == null
                  ? 'No vendor applications have been submitted yet.'
                  : 'No ${_status!.name} applications.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: _muted),
            ),
          ),
        for (final application in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Material(
              key: ValueKey('review-${application.id}'),
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0xFFCBD2BE)),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => widget.onOpen(application),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ApplicationLogo(url: application.logoUrl),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              application.businessName,
                              style: const TextStyle(
                                fontSize: 19,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                                color: _ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        application.owner,
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Submitted ${formatApplicationDate(application.submittedAt)}',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: _muted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: switch (application.status) {
                              ApplicationReviewStatus.pending => const Color(
                                0xFFFFF0C0,
                              ),
                              ApplicationReviewStatus.approved => const Color(
                                0xFFEEF1E4,
                              ),
                              ApplicationReviewStatus.rejected => const Color(
                                0xFFFCEAE7,
                              ),
                            },
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            application.statusLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _ink,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Row(
                        children: [
                          Expanded(
                            child: Text(
                              'View application details',
                              style: TextStyle(fontSize: 15, color: _green),
                            ),
                          ),
                          Icon(Icons.arrow_forward, color: _green),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
