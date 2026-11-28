import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';

import '../authentication/registration_validators.dart';
import 'user_profile.dart';

class ProfileValidation {
  static const maxImageBytes = 5 * 1024 * 1024;

  static String? name(String? value) {
    final name = (value ?? '').trim();
    if (name.length < 2 || name.length > 100) {
      return 'Use 2–100 characters for your name.';
    }
    return null;
  }

  static String? phone(String? value) =>
      (value ?? '').trim().isEmpty ? null : RegistrationValidators.phone(value);

  static String normalizePhone(String value) =>
      value.trim().replaceAll(RegExp(r'[\s()-]'), '');

  static Future<ProfileImage> readImage(XFile file) async {
    if (await file.length() > maxImageBytes) {
      throw const ProfileFailure('Choose a photo smaller than 5 MB.');
    }
    return validateImage(await file.readAsBytes());
  }

  static Future<ProfileImage> validateImage(Uint8List bytes) async {
    if (bytes.length > maxImageBytes) {
      throw const ProfileFailure('Choose a photo smaller than 5 MB.');
    }
    final png =
        bytes.length >= 24 &&
        _same(bytes.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
    final jpeg =
        bytes.length >= 4 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    if (!png && !jpeg) {
      throw const ProfileFailure('Choose a valid JPEG or PNG photo.');
    }
    final dimensions = png
        ? (
            ByteData.sublistView(bytes).getUint32(16),
            ByteData.sublistView(bytes).getUint32(20),
          )
        : _jpegDimensions(bytes);
    if (dimensions == null ||
        dimensions.$1 <= 0 ||
        dimensions.$2 <= 0 ||
        dimensions.$1 > 8192 ||
        dimensions.$2 > 8192 ||
        dimensions.$1 * dimensions.$2 > 16000000) {
      throw const ProfileFailure(
        'Choose a photo up to 16 megapixels and 8192 pixels per side.',
      );
    }
    ui.Codec? codec;
    try {
      codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 512,
        allowUpscaling: false,
      );
      final frame = await codec.getNextFrame();
      frame.image.dispose();
    } catch (_) {
      throw const ProfileFailure(
        'This photo could not be opened. Choose another JPEG or PNG.',
      );
    } finally {
      codec?.dispose();
    }
    return ProfileImage(
      bytes,
      png ? 'png' : 'jpg',
      png ? 'image/png' : 'image/jpeg',
    );
  }

  static bool _same(List<int> a, List<int> b) {
    for (var i = 0; i < b.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static (int, int)? _jpegDimensions(Uint8List bytes) {
    var offset = 2;
    while (offset + 3 < bytes.length) {
      if (bytes[offset] != 255) return null;
      while (offset < bytes.length && bytes[offset] == 255) {
        offset++;
      }
      if (offset >= bytes.length) return null;
      final marker = bytes[offset++];
      if (marker == 217 || marker == 218) return null;
      if (marker == 1 || (marker >= 208 && marker <= 215)) continue;
      if (offset + 1 >= bytes.length) return null;
      final length = (bytes[offset] << 8) + bytes[offset + 1];
      if (length < 2 || offset + length > bytes.length) return null;
      if ([
        192,
        193,
        194,
        195,
        197,
        198,
        199,
        201,
        202,
        203,
        205,
        206,
        207,
      ].contains(marker)) {
        if (length < 7) return null;
        return (
          (bytes[offset + 5] << 8) + bytes[offset + 6],
          (bytes[offset + 3] << 8) + bytes[offset + 4],
        );
      }
      offset += length;
    }
    return null;
  }
}
