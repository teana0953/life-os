import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/application/send_password_reset.dart';
import 'package:life_os/contexts/auth/domain/auth_exceptions.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';

class _FakeAuthRepository implements AuthRepository {
  Object? resetErrorToThrow;
  String? receivedEmail;

  @override
  Future<void> sendPasswordReset(String email) async {
    receivedEmail = email;
    if (resetErrorToThrow != null) throw resetErrorToThrow!;
  }

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> idToken() async => null;

  @override
  Stream<bool> get authStateChanges => const Stream.empty();
}

void main() {
  group('SendPasswordReset', () {
    test('asks the auth service to mail the address', () async {
      final repository = _FakeAuthRepository();

      await SendPasswordReset(repository)('user@example.com');

      expect(repository.receivedEmail, 'user@example.com');
    });

    test('an address with no account succeeds, exactly like one that has', () async {
      // The whole point. Firebase reports an unknown address as an error, and
      // surfacing it makes this an account-enumeration oracle: anyone with a
      // list of addresses could ask which of them use this app — and this app
      // holds financial and health records, so "has an account here" is
      // itself worth not leaking.
      final repository = _FakeAuthRepository()
        ..resetErrorToThrow = const AuthFailure(AuthFailureCode.invalidCredentials);

      // No throw, and nothing in the outcome distinguishes it from the case
      // above: the caller has nothing to render differently even if it wanted
      // to.
      await expectLater(SendPasswordReset(repository)('nobody@example.com'), completes);
    });

    test('a malformed address is still reported', () async {
      // Not the same thing. An address that is not an address cannot be
      // anybody's account, so saying so leaks nothing — and swallowing it
      // would leave the user waiting for a mail that was never going to be
      // sent.
      final repository = _FakeAuthRepository()
        ..resetErrorToThrow = const AuthFailure(AuthFailureCode.invalidEmail);

      await expectLater(
        SendPasswordReset(repository)('not-an-address'),
        throwsA(isA<AuthFailure>().having((e) => e.code, 'code', AuthFailureCode.invalidEmail)),
      );
    });

    test('a rate limit is still reported', () async {
      // Firebase throttles repeated resets. Swallowing it would show "check
      // your inbox" for a mail that will never arrive.
      final repository = _FakeAuthRepository()
        ..resetErrorToThrow = const AuthFailure(AuthFailureCode.tooManyRequests);

      await expectLater(
        SendPasswordReset(repository)('user@example.com'),
        throwsA(isA<AuthFailure>().having((e) => e.code, 'code', AuthFailureCode.tooManyRequests)),
      );
    });
  });
}
