import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/infrastructure/firebase_auth_error_messages.dart';

void main() {
  group('friendlyAuthErrorMessage', () {
    test('maps invalid-credential to a friendly message', () {
      expect(
        friendlyAuthErrorMessage('invalid-credential'),
        'Incorrect email or password.',
      );
    });

    test('maps wrong-password to a friendly message', () {
      expect(
        friendlyAuthErrorMessage('wrong-password'),
        'Incorrect email or password.',
      );
    });

    test('maps user-not-found to a friendly message', () {
      expect(
        friendlyAuthErrorMessage('user-not-found'),
        'Incorrect email or password.',
      );
    });

    test('maps invalid-email to a friendly message', () {
      expect(
        friendlyAuthErrorMessage('invalid-email'),
        'That email address is invalid.',
      );
    });

    test('falls back to a generic message for unknown codes, without leaking the code', () {
      final message = friendlyAuthErrorMessage('internal-error-xyz');

      expect(message, 'Sign-in failed. Please try again.');
      expect(message, isNot(contains('internal-error-xyz')));
    });
  });
}
