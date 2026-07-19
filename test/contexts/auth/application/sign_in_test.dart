import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/application/sign_in.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  Object? signInErrorToThrow;
  String? receivedEmail;
  String? receivedPassword;
  bool signOutCalled = false;

  @override
  Future<void> signIn(String email, String password) async {
    receivedEmail = email;
    receivedPassword = password;
    if (signInErrorToThrow != null) {
      throw signInErrorToThrow!;
    }
  }

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }

  @override
  Future<String?> idToken() async => 'fake-id-token';

  @override
  Stream<bool> get authStateChanges => const Stream.empty();
}

void main() {
  group('SignIn', () {
    test('delegates email and password to the repository', () async {
      final repository = FakeAuthRepository();
      final signIn = SignIn(repository);

      await signIn('user@example.com', 'correct-password');

      expect(repository.receivedEmail, 'user@example.com');
      expect(repository.receivedPassword, 'correct-password');
    });

    test('propagates a recognizable error on rejected credentials', () async {
      final repository = FakeAuthRepository()
        ..signInErrorToThrow = Exception('Invalid email or password.');
      final signIn = SignIn(repository);

      expect(
        () => signIn('user@example.com', 'wrong-password'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Invalid email or password.'),
          ),
        ),
      );
    });
  });
}
