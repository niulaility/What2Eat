import 'dart:typed_data';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.role,
    required this.fullName,
    required this.username,
    required this.email,
    required this.phone,
    required this.updatedAt,
    this.universityId,
    this.avatarPath,
    this.servedUniversityIds = const [],
  });

  factory UserProfile.fromJson(
    Map<String, dynamic> row, {
    String? email,
    List<String> servedUniversityIds = const [],
  }) => UserProfile(
    id: row['id'] as String,
    role: row['role'] as String,
    fullName: row['full_name'] as String? ?? '',
    username: row['username'] as String? ?? '',
    email: email ?? row['email'] as String? ?? '',
    phone: row['phone_number'] as String? ?? '',
    updatedAt: row['updated_at'] as String,
    universityId: row['university_id'] as String?,
    avatarPath: row['avatar_url'] as String?,
    servedUniversityIds: servedUniversityIds,
  );

  final String id, role, fullName, username, email, phone, updatedAt;
  final String? universityId, avatarPath;

  /// Vendors only: the universities their kitchen delivers to (may include the
  /// "Other university" directory row).
  final List<String> servedUniversityIds;
  bool get isStudent => role == 'student';
  bool get isVendor => role == 'vendor';
  String get displayName => fullName.trim().isEmpty ? username : fullName;
  String get roleLabel => switch (role) {
    'student' => 'Student',
    'vendor' => 'Vendor',
    'admin' => 'Administrator',
    _ => 'Member',
  };
}

class ProfileChanges {
  const ProfileChanges({
    required this.userId,
    required this.fullName,
    required this.username,
    required this.phone,
    required this.expectedUpdatedAt,
    this.universityId,
    this.avatarPath,
    this.servedUniversityIds,
  });
  final String userId, fullName, username, phone, expectedUpdatedAt;
  final String? universityId, avatarPath;

  /// Vendors only. `null` leaves served universities unchanged.
  final List<String>? servedUniversityIds;
}

class UniversityChoice {
  const UniversityChoice(this.id, this.name, [this.code = '']);
  final String id, name, code;
}

class ProfileImage {
  const ProfileImage(this.bytes, this.extension, this.contentType);
  final Uint8List bytes;
  final String extension, contentType;
}

class ProfileFailure implements Exception {
  const ProfileFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
