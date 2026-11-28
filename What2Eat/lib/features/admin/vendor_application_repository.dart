import 'package:supabase_flutter/supabase_flutter.dart';

enum ApplicationReviewStatus { pending, approved, rejected }

/// One `vendor_doc_type` entry as shown to administrators, in the same order
/// and with the same required/optional rules as vendor registration.
typedef VendorDocumentType = ({String type, String title, bool optional});

const vendorDocumentTypes = <VendorDocumentType>[
  (type: 'ic_front', title: 'IC Photo — Front', optional: false),
  (type: 'ic_back', title: 'IC Photo — Back', optional: false),
  (type: 'selfie', title: 'Selfie with IC', optional: false),
  (type: 'ssm', title: 'SSM Business Registration Certificate', optional: true),
  (type: 'kkm', title: 'KKM Food Premises Registration', optional: true),
  (type: 'typhoid', title: 'Typhoid Vaccination Evidence', optional: false),
  (type: 'kitchen', title: 'Food Preparation Area Photos', optional: false),
];

class VendorApplicationDocument {
  const VendorApplicationDocument({
    required this.id,
    required this.type,
    required this.path,
    this.verificationStatus = 'pending',
  });
  final String id, type, verificationStatus;

  /// Object path inside the private `vendor-documents` storage bucket.
  final String path;
}

class VendorApplication {
  const VendorApplication({
    required this.id,
    required this.businessName,
    required this.description,
    required this.businessPhone,
    required this.address,
    required this.status,
    required this.submittedAt,
    required this.owner,
    required this.username,
    required this.email,
    required this.phone,
    this.logoUrl,
    this.rejectionReason,
    this.reviewedAt,
    this.universities = const [],
    this.documents = const [],
  });

  final String id, businessName, description, businessPhone, address;
  final String owner, username, email, phone;
  final String? logoUrl, rejectionReason;
  final ApplicationReviewStatus status;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final List<String> universities;
  final List<VendorApplicationDocument> documents;

  /// Short reference shown to admins, e.g. `W2E-V-6E00AA`.
  String get reference => 'W2E-V-${id.substring(0, 6).toUpperCase()}';

  String get statusLabel => switch (status) {
    ApplicationReviewStatus.pending => 'Pending',
    ApplicationReviewStatus.approved => 'Approved',
    ApplicationReviewStatus.rejected => 'Rejected',
  };

  List<VendorApplicationDocument> documentsOf(String type) =>
      documents.where((document) => document.type == type).toList();

  factory VendorApplication.fromRow(Map<String, dynamic> row) {
    final owner = Map<String, dynamic>.from(row['owner'] as Map? ?? {});
    String text(Object? value) => value?.toString().trim() ?? '';
    return VendorApplication(
      id: row['id'] as String,
      businessName: text(row['business_name']),
      description: text(row['business_description']),
      businessPhone: text(row['business_contact_number']),
      address: text(row['business_address']),
      logoUrl: (row['logo_url'] as String?)?.trim().isEmpty ?? true
          ? null
          : row['logo_url'] as String,
      status: ApplicationReviewStatus.values.byName(row['status'] as String),
      rejectionReason:
          (row['rejection_reason'] as String?)?.trim().isEmpty ?? true
          ? null
          : (row['rejection_reason'] as String).trim(),
      submittedAt: DateTime.parse(row['submitted_at'] as String).toLocal(),
      reviewedAt: row['reviewed_at'] == null
          ? null
          : DateTime.parse(row['reviewed_at'] as String).toLocal(),
      owner: text(owner['full_name']).isEmpty
          ? text(owner['username'])
          : text(owner['full_name']),
      username: text(owner['username']),
      email: text(owner['email']),
      phone: text(owner['phone_number']),
      universities: [
        for (final link in row['vendor_universities'] as List? ?? const [])
          if ((link as Map)['university'] case {'name': final String name})
            name,
      ]..sort(),
      documents: [
        for (final document in row['vendor_documents'] as List? ?? const [])
          VendorApplicationDocument(
            id: document['id'] as String,
            type: document['document_type'] as String,
            path: document['file_url'] as String,
            verificationStatus:
                document['verification_status'] as String? ?? 'pending',
          ),
      ],
    );
  }
}

/// `18 Nov 2026 · 9:40 AM` in the device's local time.
String formatApplicationDate(DateTime value) {
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
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  // Non-breaking spaces keep the date and the time each on one line.
  const nb = ' ';
  return '${value.day}$nb${months[value.month - 1]}$nb${value.year} · '
      '$hour:$minute$nb${value.hour < 12 ? 'AM' : 'PM'}';
}

class VendorApplicationFailure implements Exception {
  const VendorApplicationFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class VendorApplicationRepository {
  /// Every vendor application, newest submission first.
  Future<List<VendorApplication>> loadApplications();

  /// A short-lived URL for a file in the private `vendor-documents` bucket.
  Future<String> documentUrl(String path);
}

class SupabaseVendorApplicationRepository
    implements VendorApplicationRepository {
  SupabaseVendorApplicationRepository([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  static const _columns =
      'id,business_name,business_description,business_contact_number,'
      'business_address,logo_url,status,rejection_reason,submitted_at,'
      'reviewed_at,'
      'owner:profiles(full_name,username,email,phone_number),'
      'vendor_universities(university:universities(name)),'
      'vendor_documents(id,document_type,file_url,verification_status,uploaded_at)';

  @override
  Future<List<VendorApplication>> loadApplications() async {
    try {
      // RLS returns every application only to administrators.
      final rows = await _client
          .from('vendors')
          .select(_columns)
          .order('submitted_at', ascending: false)
          .order('uploaded_at', referencedTable: 'vendor_documents')
          .timeout(const Duration(seconds: 20));
      return [
        for (final row in rows)
          VendorApplication.fromRow(Map<String, dynamic>.from(row)),
      ];
    } on Exception catch (error) {
      throw VendorApplicationFailure(
        error is PostgrestException && error.code == '42501'
            ? 'Only administrators can view vendor applications.'
            : 'Could not load vendor applications. Check your connection and try again.',
      );
    }
  }

  @override
  Future<String> documentUrl(String path) async {
    try {
      return await _client.storage
          .from('vendor-documents')
          .createSignedUrl(path, 300)
          .timeout(const Duration(seconds: 20));
    } on Exception {
      throw const VendorApplicationFailure('Could not open this document.');
    }
  }
}
