import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/domain/auth_exceptions.dart';
import 'package:life_os/contexts/auth/infrastructure/firebase_auth_error_messages.dart';

void main() {
  group('authFailureCodeFor', () {
    test('maps invalid-credential to invalidCredentials', () {
      expect(
        authFailureCodeFor('invalid-credential'),
        AuthFailureCode.invalidCredentials,
      );
    });

    test('maps wrong-password to invalidCredentials', () {
      expect(
        authFailureCodeFor('wrong-password'),
        AuthFailureCode.invalidCredentials,
      );
    });

    test('maps user-not-found to invalidCredentials', () {
      expect(
        authFailureCodeFor('user-not-found'),
        AuthFailureCode.invalidCredentials,
      );
    });

    test('maps invalid-email to invalidEmail', () {
      expect(authFailureCodeFor('invalid-email'), AuthFailureCode.invalidEmail);
    });

    test('maps user-disabled to accountDisabled', () {
      expect(
        authFailureCodeFor('user-disabled'),
        AuthFailureCode.accountDisabled,
      );
    });

    test('maps too-many-requests to tooManyRequests', () {
      expect(
        authFailureCodeFor('too-many-requests'),
        AuthFailureCode.tooManyRequests,
      );
    });

    test('falls back to unknown for unrecognized codes, without leaking the code', () {
      final code = authFailureCodeFor('internal-error-xyz');

      expect(code, AuthFailureCode.unknown);
    });
  });
}
