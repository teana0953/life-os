import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/application/sign_up.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Future<void> sendPasswordReset(String email) async {}

  Object? signUpErrorToThrow;
  String? receivedEmail;
  String? receivedPassword;

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {
    receivedEmail = email;
    receivedPassword = password;
    if (signUpErrorToThrow != null) {
      throw signUpErrorToThrow!;
    }
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> idToken() async => 'fake-id-token';

  @override
  Stream<bool> get authStateChanges => const Stream.empty();
}

void main() {
  group('SignUp', () {
    test('delegates email and password to the repository', () async {
      final repository = FakeAuthRepository();
      final signUp = SignUp(repository);

      await signUp('new-user@example.com', 'a-new-password');

      expect(repository.receivedEmail, 'new-user@example.com');
      expect(repository.receivedPassword, 'a-new-password');
    });

    test('propagates a recognizable error on rejected creation', () async {
      final repository = FakeAuthRepository()
        ..signUpErrorToThrow = Exception('email-already-in-use');
      final signUp = SignUp(repository);

      expect(
        () => signUp('new-user@example.com', 'a-new-password'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('email-already-in-use'),
          ),
        ),
      );
    });
  });
}
