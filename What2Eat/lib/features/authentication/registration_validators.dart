/// Frontend checks only; account uniqueness and ownership require a backend.
class RegistrationValidators {
  static String? username(String? input) {
    final value = (input ?? '').trim();
    if (value.isEmpty) return 'Enter a username.';
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]{2,29}$').hasMatch(value)) {
      return 'Use 3–30 characters: start with a letter, then letters, numbers or underscores.';
    }
    return null;
  }

  static String? email(String? input) {
    final value = (input ?? '').trim();
    if (value.isEmpty) return 'Enter your email address.';
    if (value.length > 254 ||
        value.contains('..') ||
        !RegExp(
          r"^[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$",
        ).hasMatch(value) ||
        value.split('@').first.length > 64) {
      return 'Enter a valid email, such as name@example.com.';
    }
    return null;
  }

  static String? phone(String? input) {
    final value = (input ?? '').trim();
    if (value.isEmpty) return 'Enter your phone number.';
    final compact = value.replaceAll(RegExp(r'[\s()-]'), '');
    if (!RegExp(r'^\+?[0-9]+$').hasMatch(compact)) {
      return 'Use digits with an optional leading + country code.';
    }
    final digits = compact.replaceFirst('+', '');
    if (digits.length < 8 ||
        digits.length > 15 ||
        RegExp(r'^(\d)\1+$').hasMatch(digits)) {
      return 'Enter a valid phone number with 8–15 digits.';
    }
    return null;
  }

  static String? password(String? input) {
    final value = input ?? '';
    if (value.isEmpty) return 'Enter a password.';
    if (value.length < 8 || value.length > 128) return 'Use 8–128 characters.';
    if (value.trim() != value) return 'Remove spaces at the start or end.';
    if (!RegExp(r'[A-Za-z]').hasMatch(value) ||
        !RegExp(r'[0-9]').hasMatch(value)) {
      return 'Include at least one letter and one number.';
    }
    return null;
  }

  static String? confirmation(String? input, String password) {
    if (input == null || input.isEmpty) return 'Confirm your password.';
    return input == password ? null : 'Passwords do not match.';
  }
}
