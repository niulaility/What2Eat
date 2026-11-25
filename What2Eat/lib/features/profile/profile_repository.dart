import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'user_profile.dart';

abstract class ProfileRepository {
  Future<UserProfile> load();
  Future<List<UniversityChoice>> universities();
  Future<Uint8List?> readAvatar(String? reference);
  Future<String> uploadAvatar(ProfileImage image);
  Future<UserProfile> save(ProfileChanges changes);
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this.client);
  final SupabaseClient client;

  String get _userId {
    final user = client.auth.currentUser;
    if (user == null) {
      throw const ProfileFailure(
        'Your session has expired. Sign in again to edit your profile.',
      );
    }
    return user.id;
  }

  @override
  Future<UserProfile> load() => _guard(() async {
    final user = (await client.auth.getUser()).user;
    if (user == null) {
      throw const ProfileFailure('Your session has expired. Sign in again.');
    }
    final row = await client
        .from('profiles')
        .select(
          'id, role, full_name, username, email, phone_number, avatar_url, updated_at',
        )
        .eq('id', user.id)
        .single();
    String? universityId;
    if (row['role'] == 'student') {
      final customer = await client
          .from('customers')
          .select('university_id')
          .eq('user_id', user.id)
          .maybeSingle();
      universityId = customer?['university_id'] as String?;
    }
    return UserProfile.fromJson({
      ...row,
      'university_id': universityId,
    }, email: user.email);
  });

  @override
  Future<List<UniversityChoice>> universities() => _guard(() async {
    final rows = await client
        .from('universities')
        .select('id, name')
        .eq('is_active', true)
        .order('name');
    return rows
        .map(
          (row) => UniversityChoice(row['id'] as String, row['name'] as String),
        )
        .toList();
  });

  /// Never fetch external avatar URLs or another user's storage folder.
  static String? ownedAvatarPath(
    String? reference,
    String userId,
    String projectHost,
  ) {
    if (reference == null || reference.isEmpty) return null;
    var path = reference;
    final uri = Uri.tryParse(reference);
    if (uri != null && uri.hasScheme) {
      if (uri.scheme != 'https' ||
          uri.host != projectHost ||
          uri.userInfo.isNotEmpty) {
        return null;
      }
      final parts = uri.pathSegments;
      if (parts.length < 7 ||
          parts[0] != 'storage' ||
          parts[1] != 'v1' ||
          parts[2] != 'object' ||
          !['public', 'sign', 'authenticated'].contains(parts[3]) ||
          parts[4] != 'avatars') {
        return null;
      }
      path = parts.skip(5).join('/');
    }
    final parts = path.split('/');
    if (parts.length < 2 ||
        parts.first != userId ||
        parts.any(
          (part) =>
              part.isEmpty ||
              part == '.' ||
              part == '..' ||
              !RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(part),
        )) {
      return null;
    }
    return path;
  }

  @override
  Future<Uint8List?> readAvatar(String? reference) => _guard(() async {
    final path = ownedAvatarPath(
      reference,
      _userId,
      // URL construction only; downloads below still require authentication.
      Uri.parse(client.storage.from('avatars').getPublicUrl('_')).host,
    );
    if (path == null) return null;
    return await client.storage
        .from('avatars')
        .download(path)
        .timeout(const Duration(seconds: 15));
  });

  @override
  Future<String> uploadAvatar(ProfileImage image) => _guard(() async {
    final userId = _userId;
    final random = Random.secure();
    final suffix = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final path = '$userId/profile/$suffix.${image.extension}';
    await client.storage
        .from('avatars')
        .uploadBinary(
          path,
          image.bytes,
          fileOptions: FileOptions(
            contentType: image.contentType,
            cacheControl: '0',
            upsert: false,
          ),
        );
    if (_userId != userId) {
      throw const ProfileFailure(
        'Your signed-in account changed. Reopen your profile.',
      );
    }
    return path;
  });

  @override
  Future<UserProfile> save(ProfileChanges changes) => _guard(() async {
    final userId = _userId;
    if (userId != changes.userId) {
      throw const ProfileFailure(
        'Your signed-in account changed. Reopen your profile.',
      );
    }
    final result = await client.rpc(
      'update_my_personal_profile',
      params: {
        'p_full_name': changes.fullName.trim(),
        'p_username': changes.username.trim(),
        'p_phone_number': changes.phone,
        'p_university_id': changes.universityId,
        'p_avatar_path': changes.avatarPath,
        'p_expected_updated_at': changes.expectedUpdatedAt,
      },
    );
    if (_userId != userId) {
      throw const ProfileFailure(
        'Your signed-in account changed. Reopen your profile.',
      );
    }
    return UserProfile.fromJson(Map<String, dynamic>.from(result as Map));
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action().timeout(const Duration(seconds: 30));
    } on ProfileFailure {
      rethrow;
    } on AuthException {
      throw const ProfileFailure(
        'Your session has expired. Sign in again to continue.',
      );
    } on PostgrestException catch (error) {
      if (['PGRST301', 'PGRST302', 'PGRST303'].contains(error.code)) {
        throw const ProfileFailure(
          'Your session has expired. Sign in again to continue.',
        );
      }
      if (error.code == '23505') {
        throw const ProfileFailure(
          'That username is already taken. Choose another one.',
        );
      }
      if (error.code == '40001') {
        throw const ProfileFailure(
          'Your profile changed elsewhere. Cancel and reopen it before saving again.',
        );
      }
      if (error.code == 'PGRST202' || error.code == '42501') {
        throw const ProfileFailure(
          'Profile editing is not available yet. Please contact support.',
        );
      }
      if (error.code == '22023' || error.code == '23514') {
        throw const ProfileFailure(
          'Check your profile details and selected photo, then try again.',
        );
      }
      throw ProfileFailure(
        error.message.isNotEmpty
            ? error.message
            : 'Could not save or load your profile. Check your connection and try again.',
      );
    } on StorageException {
      throw const ProfileFailure(
        'Could not access your photo. Check your connection and try again.',
      );
    } on TimeoutException {
      throw const ProfileFailure(
        'The request took too long. Reopen your profile to check the latest saved details before retrying.',
      );
    } catch (_) {
      throw const ProfileFailure(
        'Could not connect. Check your connection and try again.',
      );
    }
  }
}
