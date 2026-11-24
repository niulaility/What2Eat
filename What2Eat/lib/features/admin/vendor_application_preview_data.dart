// Synthetic applications for interface review. Never linked to Supabase users.
class ApplicationDocumentPreview {
  const ApplicationDocumentPreview(
    this.id,
    this.title, {
    this.files = 1,
    this.optional = false,
  });
  final String id, title;
  final int files;
  final bool optional;
}

enum ApplicationReviewStatus { pending, approved, rejected }

class VendorApplicationPreview {
  const VendorApplicationPreview({
    required this.id,
    required this.businessName,
    required this.owner,
    required this.username,
    required this.email,
    required this.phone,
    required this.businessPhone,
    required this.address,
    required this.description,
    required this.submitted,
    required this.campuses,
    required this.logoAsset,
    this.status = ApplicationReviewStatus.pending,
    this.rejectionReason,
  });
  final String id, businessName, owner, username, email, phone, businessPhone;
  final String address, description, submitted, logoAsset;
  final List<String> campuses;
  final ApplicationReviewStatus status;
  final String? rejectionReason;
  String get statusLabel => switch (status) {
    ApplicationReviewStatus.pending => 'Pending',
    ApplicationReviewStatus.approved => 'Approved',
    ApplicationReviewStatus.rejected => 'Rejected',
  };
  List<ApplicationDocumentPreview> get documents => const [
    ApplicationDocumentPreview('ic-front', 'IC Photo — Front'),
    ApplicationDocumentPreview('ic-back', 'IC Photo — Back'),
    ApplicationDocumentPreview('selfie', 'Selfie with IC'),
    ApplicationDocumentPreview(
      'ssm',
      'SSM Business Registration Certificate',
      optional: true,
    ),
    ApplicationDocumentPreview(
      'kkm',
      'KKM Food Premises Registration',
      optional: true,
      files: 0,
    ),
    ApplicationDocumentPreview('typhoid', 'Typhoid Vaccination Evidence'),
    ApplicationDocumentPreview(
      'kitchen',
      'Food Preparation Area Photos',
      files: 2,
    ),
  ];
}

const vendorApplicationPreviews = [
  VendorApplicationPreview(
    id: 'W2E-V-0001',
    businessName: 'Fresh Campus Kitchen',
    owner: 'Aina Rahman',
    username: 'aina_kitchen_demo',
    email: 'aina@example.test',
    phone: '+60 12-000 0101',
    businessPhone: '+60 11-0000 0101',
    address: '12, Jalan Contoh, 81300 Johor Bahru, Johor',
    description: 'Freshly prepared rice bowls and light meals for students. Lunch preorders are prepared in small batches and delivered to campus pickup points.',
    submitted: '18 Nov 2026 · 9:40 AM',
    campuses: ['Universiti Teknologi Malaysia'],
    logoAsset: 'assets/dashboard/noodle-bowl.png',
  ),
  VendorApplicationPreview(
    id: 'W2E-V-0002',
    businessName: 'Daily Bento House',
    owner: 'Daniel Lim',
    username: 'daily_bento_demo',
    email: 'daniel@example.test',
    phone: '+60 12-000 0102',
    businessPhone: '+60 11-0000 0102',
    address: '8, Jalan Sampel, 50603 Kuala Lumpur',
    description: 'Homemade lunch sets with rotating daily menus, vegetable sides and clear meal-period pickup schedules.',
    submitted: '19 Nov 2026 · 2:15 PM',
    campuses: ['Universiti Malaya', 'Universiti Putra Malaysia'],
    logoAsset: 'assets/dashboard/teriyaki-bowl.png',
  ),
  VendorApplicationPreview(
    id: 'W2E-V-0003',
    businessName: 'Little Wrap Kitchen',
    owner: 'Sara Abdullah',
    username: 'little_wrap_demo',
    email: 'sara@example.test',
    phone: '+60 12-000 0103',
    businessPhone: '+60 11-0000 0103',
    address: '5, Jalan Contoh, 43600 Bangi, Selangor',
    description: 'Grilled wraps and breakfast packs made to preorder for the campus community.',
    submitted: '20 Nov 2026 · 8:30 AM',
    campuses: ['Universiti Kebangsaan Malaysia'],
    logoAsset: 'assets/dashboard/chicken-wrap.png',
  ),
  VendorApplicationPreview(
    id: 'W2E-V-0004',
    businessName: 'Campus Bento',
    owner: 'Alex Tan',
    username: 'campus_bento_demo',
    email: 'bento@example.test',
    phone: '+60 12-000 0104',
    businessPhone: '+60 11-0000 0104',
    address: '4, Jalan Sampel, Johor Bahru',
    description: 'Homemade lunch boxes and vegetable sides.',
    submitted: '14 Nov 2026 · 11:20 AM',
    campuses: ['Universiti Teknologi Malaysia'],
    logoAsset: 'assets/dashboard/teriyaki-bowl.png',
    status: ApplicationReviewStatus.approved,
  ),
  VendorApplicationPreview(
    id: 'W2E-V-0005',
    businessName: 'Morning Bowl',
    owner: 'Mei Wong',
    username: 'morning_bowl_demo',
    email: 'morning@example.test',
    phone: '+60 12-000 0105',
    businessPhone: '+60 11-0000 0105',
    address: '5, Jalan Sampel, Kuala Lumpur',
    description: 'Breakfast bowls and freshly prepared snacks.',
    submitted: '13 Nov 2026 · 9:00 AM',
    campuses: ['Universiti Malaya'],
    logoAsset: 'assets/dashboard/noodle-bowl.png',
    status: ApplicationReviewStatus.approved,
  ),
  VendorApplicationPreview(
    id: 'W2E-V-0006',
    businessName: 'Wrap & Go',
    owner: 'Amir Hassan',
    username: 'wrap_go_demo',
    email: 'wrap@example.test',
    phone: '+60 12-000 0106',
    businessPhone: '+60 11-0000 0106',
    address: '6, Jalan Sampel, Bangi',
    description: 'Grilled wraps prepared for campus pickup.',
    submitted: '12 Nov 2026 · 3:40 PM',
    campuses: ['Universiti Kebangsaan Malaysia'],
    logoAsset: 'assets/dashboard/chicken-wrap.png',
    status: ApplicationReviewStatus.rejected,
    rejectionReason: 'The submitted business registration document was not readable. Please provide a clearer copy.',
  ),
];
