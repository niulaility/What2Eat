import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:what2eat_starter/features/profile/profile_repository.dart';
import 'package:what2eat_starter/features/profile/profile_validation.dart';
import 'package:what2eat_starter/features/profile/user_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('validates names and optional phone numbers', () {
    expect(ProfileValidation.name('A'), isNotNull);
    expect(ProfileValidation.name('  Sara Abdullah  '), isNull);
    expect(ProfileValidation.phone(''), isNull);
    expect(ProfileValidation.phone('abc'), isNotNull);
    expect(ProfileValidation.phone('111111111'), isNotNull);
    expect(ProfileValidation.phone('+60 12-345 6789'), isNull);
    expect(
      ProfileValidation.normalizePhone('+60 (12) 345-6789'),
      '+60123456789',
    );
  });
  for (final extension in ['jpg', 'png']) {
    test(
      'decodes real $extension content instead of trusting the filename',
      () async {
        final image = await ProfileValidation.validateImage(
          await File('test/fixtures/profile-test.$extension').readAsBytes(),
        );
        expect(image.extension, extension);
        expect(
          image.contentType,
          extension == 'jpg' ? 'image/jpeg' : 'image/png',
        );
      },
    );
  }
  test('rejects unsupported, corrupted and oversized image content', () async {
    for (final bytes in [
      Uint8List.fromList([1, 2, 3]),
      Uint8List.fromList([255, 216, 255, 192, 0]),
      Uint8List(ProfileValidation.maxImageBytes + 1),
    ]) {
      await expectLater(
        ProfileValidation.validateImage(bytes),
        throwsA(isA<ProfileFailure>()),
      );
    }
  });
  test('private avatar references cannot target other users, origins or traversal paths', () {
    const user = 'user-a';
    const host = 'project.supabase.co';
    const valid = 'user-a/profile/image.jpg';
    expect(SupabaseProfileRepository.ownedAvatarPath(valid, user, host), valid);
    expect(
      SupabaseProfileRepository.ownedAvatarPath(
        'https://$host/storage/v1/object/public/avatars/$valid',
        user,
        host,
      ),
      valid,
    );
    for (final invalid in [
      'user-b/profile/image.jpg',
      'user-a/../user-b/image.jpg',
      'user-a/%2e%2e/image.jpg',
      'https://evil.example/storage/v1/object/public/avatars/$valid',
      'https://$host/storage/v1/object/public/vendor-logos/$valid',
    ]) {
      expect(
        SupabaseProfileRepository.ownedAvatarPath(invalid, user, host),
        isNull,
      );
    }
  });
}
