import '../lib/features/authentication/registration_validators.dart';

void main() {
  var checks = 0;
  void check(bool condition, String description) {
    checks++;
    if (!condition) throw StateError(description);
  }

  for (final value in ['', '   ', 'ab', '123user', 'user name', 'user@name']) {
    check(
      RegistrationValidators.username(value) != null,
      'Reject username: $value',
    );
  }
  check(
    RegistrationValidators.username('student_01') == null,
    'Valid username',
  );
  for (final value in [
    '',
    'name',
    'a@@example.com',
    '.a@example.com',
    'a..b@example.com',
    'a@-example.com',
    'a@exam ple.com',
    'a@example',
  ]) {
    check(RegistrationValidators.email(value) != null, 'Reject email: $value');
  }
  for (final value in [
    'student@example.com',
    ' user.name+campus@students.example.edu.my ',
  ]) {
    check(RegistrationValidators.email(value) == null, 'Valid email: $value');
  }
  for (final value in [
    '',
    'abc12345678',
    '123',
    '0000000000',
    '1234567890123456',
    '60+12345678',
  ]) {
    check(RegistrationValidators.phone(value) != null, 'Reject phone: $value');
  }
  for (final value in ['012 345 6789', '+60 12-345 6789']) {
    check(RegistrationValidators.phone(value) == null, 'Valid phone: $value');
  }
  for (final value in ['', 'short1', 'abcdefgh', '12345678', ' password1 ']) {
    check(RegistrationValidators.password(value) != null, 'Reject password');
  }
  check(
    RegistrationValidators.password('Campus2026!') == null,
    'Valid password',
  );
  check(
    RegistrationValidators.confirmation('', 'Campus2026!') != null,
    'Empty confirmation',
  );
  check(
    RegistrationValidators.confirmation('Campus2025!', 'Campus2026!') != null,
    'Mismatch',
  );
  check(
    RegistrationValidators.confirmation('Campus2026!', 'Campus2026!') == null,
    'Matching confirmation',
  );
  print('Passed $checks registration validation checks.');
}
