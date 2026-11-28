import 'dart:typed_data';

import 'package:what2eat_starter/features/profile/profile_repository.dart';
import 'package:what2eat_starter/features/profile/user_profile.dart';

/// Synthetic, in-memory test data. Never used by the app's account pages.
class SampleProfileRepository implements ProfileRepository {
  SampleProfileRepository({String role = 'student', String? avatarPath})
    : current = UserProfile(
        id: '00000000-0000-4000-8000-000000000001',
        role: role,
        fullName: role == 'vendor'
            ? 'Aina Kitchen Owner'
            : role == 'admin'
            ? 'Amir Administrator'
            : 'Sara Abdullah',
        username: '${role}_demo',
        email: '$role@example.test',
        phone: '+60123456789',
        universityId: role == 'student' ? 'campus-utm' : null,
        avatarPath: avatarPath,
        updatedAt: '2026-11-17T00:00:00Z',
      );

  UserProfile current;
  int saves = 0, uploads = 0;
  bool failUpload = false,
      failRead = false,
      failSave = false,
      duplicateUsername = false;
  Duration saveDelay = Duration.zero;
  final Map<String, Uint8List> images = {};

  @override
  Future<UserProfile> load() async => current;
  @override
  Future<List<UniversityChoice>> universities() async => const [
    UniversityChoice('campus-utm', 'Universiti Teknologi Malaysia'),
    UniversityChoice('campus-um', 'Universiti Malaya'),
    UniversityChoice('campus-upm', 'Universiti Putra Malaysia'),
    UniversityChoice('campus-ukm', 'Universiti Kebangsaan Malaysia'),
    UniversityChoice('campus-usm', 'Universiti Sains Malaysia'),
    UniversityChoice('campus-uitm', 'Universiti Teknologi MARA'),
  ];
  @override
  Future<Uint8List?> readAvatar(String? reference) async {
    if (failRead) throw const ProfileFailure('Photo unavailable.');
    return images[reference];
  }

  @override
  Future<String> uploadAvatar(ProfileImage image) async {
    uploads++;
    if (failUpload) {
      throw const ProfileFailure(
        'Could not access your photo. Check your connection and try again.',
      );
    }
    final path = '${current.id}/profile/sample-$uploads.${image.extension}';
    images[path] = image.bytes;
    return path;
  }

  @override
  Future<UserProfile> save(ProfileChanges changes) async {
    saves++;
    await Future<void>.delayed(saveDelay);
    if (duplicateUsername || changes.username == 'already_taken') {
      throw const ProfileFailure(
        'That username is already taken. Choose another one.',
      );
    }
    if (failSave) {
      throw const ProfileFailure(
        'Could not save your profile. Check your connection and try again.',
      );
    }
    if (changes.userId != current.id) {
      throw const ProfileFailure('Your signed-in account changed.');
    }
    current = UserProfile(
      id: current.id,
      role: current.role,
      fullName: changes.fullName,
      username: changes.username,
      email: current.email,
      phone: changes.phone,
      universityId: current.isStudent
          ? changes.universityId
          : current.universityId,
      avatarPath: changes.avatarPath,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );
    return current;
  }
}
