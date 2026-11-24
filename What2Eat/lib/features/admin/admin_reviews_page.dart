import 'package:flutter/material.dart';

import 'vendor_application_details_page.dart';
import 'vendor_application_preview_data.dart';

class AdminReviewsPage extends StatefulWidget {
  const AdminReviewsPage({super.key});
  @override
  State<AdminReviewsPage> createState() => _AdminReviewsPageState();
}

class _AdminReviewsPageState extends State<AdminReviewsPage> {
  ApplicationReviewStatus? _status;
  @override
  Widget build(BuildContext context) {
    final applications = vendorApplicationPreviews
        .where(
          (application) => _status == null || application.status == _status,
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Vendor application reviews',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w600,
            color: Color(0xFF253729),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Browse applications by their review status.',
          style: TextStyle(fontSize: 14, color: Color(0xFF596451)),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              key: const ValueKey('reviews-filter-all'),
              label: Text('All (${vendorApplicationPreviews.length})'),
              selected: _status == null,
              selectedColor: const Color(0xFFFFD85C),
              onSelected: (_) => setState(() => _status = null),
            ),
            for (final status in ApplicationReviewStatus.values)
              ChoiceChip(
                key: ValueKey('reviews-filter-${status.name}'),
                label: Text(
                  '${status.name[0].toUpperCase()}${status.name.substring(1)} (${vendorApplicationPreviews.where((application) => application.status == status).length})',
                ),
                selected: _status == status,
                selectedColor: const Color(0xFFFFD85C),
                onSelected: (_) => setState(() => _status = status),
              ),
          ],
        ),
        const SizedBox(height: 20),
        for (final application in applications)
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
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) =>
                        VendorApplicationDetailsPage(application: application),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Image.asset(
                            application.logoAsset,
                            width: 48,
                            height: 48,
                            excludeFromSemantics: true,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              application.businessName,
                              style: const TextStyle(
                                fontSize: 19,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF253729),
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
                        'Submitted ${application.submitted}',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Color(0xFF596451),
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
                              color: Color(0xFF253729),
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
                              style: TextStyle(
                                fontSize: 15,
                                color: Color(0xFF344B35),
                              ),
                            ),
                          ),
                          Icon(Icons.arrow_forward, color: Color(0xFF344B35)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const Text(
          'Sample applications · Interface preview',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Color(0xFF596451)),
        ),
      ],
    );
  }
}
