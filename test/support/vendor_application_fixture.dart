import 'package:what2eat_starter/features/admin/vendor_application_repository.dart';

VendorApplication sampleApplication(
  String id, {
  String business = 'Sample Kitchen',
  ApplicationReviewStatus status = ApplicationReviewStatus.pending,
  int day = 18,
  String? rejectionReason,
  List<VendorApplicationDocument> documents = const [],
}) => VendorApplication(
  id: id,
  businessName: business,
  description: 'Freshly prepared rice bowls and light meals for students.',
  businessPhone: '+60 11-0000 0101',
  address: '12, Jalan Contoh, 81300 Johor Bahru, Johor',
  status: status,
  submittedAt: DateTime(2026, 11, day, 9, 40),
  owner: 'Owner $id',
  username: 'owner_$id',
  email: '$id@example.test',
  phone: '+60 12-000 0101',
  rejectionReason: rejectionReason,
  universities: const ['Universiti Teknologi Malaysia'],
  documents: documents,
);

final sampleApplications = [
  sampleApplication(
    'app-001',
    business: 'Fresh Campus Kitchen',
    day: 18,
    documents: const [
      VendorApplicationDocument(id: 'd1', type: 'ic_front', path: 'u/ic.jpg'),
      VendorApplicationDocument(id: 'd2', type: 'kitchen', path: 'u/k0.jpg'),
      VendorApplicationDocument(id: 'd3', type: 'kitchen', path: 'u/k1.jpg'),
    ],
  ),
  sampleApplication('app-002', business: 'Daily Bento House', day: 19),
  sampleApplication('app-003', business: 'Little Wrap Kitchen', day: 20),
  sampleApplication(
    'app-004',
    business: 'Campus Bento',
    status: ApplicationReviewStatus.approved,
    day: 14,
  ),
  sampleApplication(
    'app-006',
    business: 'Wrap & Go',
    status: ApplicationReviewStatus.rejected,
    day: 12,
    rejectionReason: 'The business registration document was not readable.',
  ),
];

class FakeVendorApplicationRepository implements VendorApplicationRepository {
  FakeVendorApplicationRepository([List<VendorApplication>? applications])
    : applications = applications ?? sampleApplications;
  List<VendorApplication> applications;
  Object? failure;
  int loads = 0;
  final requestedPaths = <String>[];

  @override
  Future<List<VendorApplication>> loadApplications() async {
    loads++;
    if (failure != null) throw failure!;
    return applications;
  }

  @override
  Future<String> documentUrl(String path) async {
    requestedPaths.add(path);
    // Never fetched by the test image provider; errors render the retry state.
    throw const VendorApplicationFailure('Could not open this document.');
  }
}
