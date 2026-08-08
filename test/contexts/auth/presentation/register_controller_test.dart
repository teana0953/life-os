import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/application/sign_up.dart';
import 'package:life_os/contexts/auth/domain/auth_exceptions.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/auth/presentation/register_controller.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Future<void> sendPasswordReset(String email) async {}

  Object? signUpErrorToThrow;
  bool signUpCalled = false;
  String? receivedEmail;
  String? receivedPassword;

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {
    signUpCalled = true;
    receivedEmail = email;
    receivedPassword = password;
    if (signUpErrorToThrow != null) {
      throw signUpErrorToThrow!;
    }
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> idToken() async => null;

  @override
  Stream<bool> get authStateChanges => const Stream.empty();
}

void main() {
  group('RegisterController', () {
    test(
      'mismatched passwords set passwordMismatch and do not call SignUp',
      () async {
        final repository = FakeAuthRepository();
        final controller = RegisterController(SignUp(repository));

        await controller.submit('user@example.com', 'password1', 'password2');

        expect(controller.error, RegisterError.passwordMismatch);
        expect(repository.signUpCalled, isFalse);
        expect(controller.succeeded, isFalse);
      },
    );

    test('matching passwords call SignUp with the email and password', () async {
      final repository = FakeAuthRepository();
      final controller = RegisterController(SignUp(repository));

      await controller.submit('user@example.com', 'password1', 'password1');

      expect(repository.receivedEmail, 'user@example.com');
      expect(repository.receivedPassword, 'password1');
    });

    test('success sets succeeded to true and clears any error', () async {
      final repository = FakeAuthRepository();
      final controller = RegisterController(SignUp(repository));

      await controller.submit('user@example.com', 'password1', 'password1');

      expect(controller.succeeded, isTrue);
      expect(controller.error, isNull);
    });

    test('maps emailAlreadyInUse to RegisterError.emailAlreadyInUse', () async {
      final repository = FakeAuthRepository()
        ..signUpErrorToThrow = const AuthFailure(
          AuthFailureCode.emailAlreadyInUse,
        );
      final controller = RegisterController(SignUp(repository));

      await controller.submit('user@example.com', 'password1', 'password1');

      expect(controller.error, RegisterError.emailAlreadyInUse);
      expect(controller.succeeded, isFalse);
    });

    test('maps weakPassword to RegisterError.weakPassword', () async {
      final repository = FakeAuthRepository()
        ..signUpErrorToThrow = const AuthFailure(AuthFailureCode.weakPassword);
      final controller = RegisterController(SignUp(repository));

      await controller.submit('user@example.com', 'password1', 'password1');

      expect(controller.error, RegisterError.weakPassword);
    });

    test('maps invalidEmail to RegisterError.invalidEmail', () async {
      final repository = FakeAuthRepository()
        ..signUpErrorToThrow = const AuthFailure(AuthFailureCode.invalidEmail);
      final controller = RegisterController(SignUp(repository));

      await controller.submit('user@example.com', 'password1', 'password1');

      expect(controller.error, RegisterError.invalidEmail);
    });

    test('maps every other AuthFailureCode to RegisterError.unknown', () async {
      for (final code in [
        AuthFailureCode.invalidCredentials,
        AuthFailureCode.accountDisabled,
        AuthFailureCode.tooManyRequests,
        AuthFailureCode.unknown,
      ]) {
        final repository = FakeAuthRepository()..signUpErrorToThrow = AuthFailure(code);
        final controller = RegisterController(SignUp(repository));

        await controller.submit('user@example.com', 'password1', 'password1');

        expect(controller.error, RegisterError.unknown);
      }
    });

    test('an unrecognized exception type maps to RegisterError.unknown', () async {
      final repository = FakeAuthRepository()
        ..signUpErrorToThrow = Exception('boom');
      final controller = RegisterController(SignUp(repository));

      await controller.submit('user@example.com', 'password1', 'password1');

      expect(controller.error, RegisterError.unknown);
    });

    test('isLoading toggles true then false around a SignUp call', () async {
      final repository = FakeAuthRepository();
      final controller = RegisterController(SignUp(repository));
      final loadingStates = <bool>[];
      controller.addListener(() => loadingStates.add(controller.isLoading));

      final future = controller.submit(
        'user@example.com',
        'password1',
        'password1',
      );
      expect(controller.isLoading, isTrue);
      await future;

      expect(controller.isLoading, isFalse);
      expect(loadingStates, contains(true));
      expect(loadingStates.last, isFalse);
    });
  });
}
