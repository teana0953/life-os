import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/application/sign_in.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/auth/presentation/login_controller.dart';
import 'package:life_os/contexts/auth/presentation/login_screen.dart';

class FakeAuthRepository implements AuthRepository {
  static const validEmail = 'user@example.com';
  static const validPassword = 'correct-password';

  String? receivedEmail;
  String? receivedPassword;

  @override
  Future<void> signIn(String email, String password) async {
    receivedEmail = email;
    receivedPassword = password;
    if (email != validEmail || password != validPassword) {
      throw Exception('Incorrect email or password.');
    }
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> idToken() async => null;

  @override
  Stream<bool> get authStateChanges => const Stream.empty();
}

Future<void> pumpLoginScreen(
  WidgetTester tester,
  LoginController controller,
) {
  return tester.pumpWidget(
    MaterialApp(home: LoginScreen(controller: controller)),
  );
}

void main() {
  group('LoginScreen', () {
    testWidgets('valid credentials call sign-in and show no error', (
      tester,
    ) async {
      final repository = FakeAuthRepository();
      final controller = LoginController(SignIn(repository));
      await pumpLoginScreen(tester, controller);

      await tester.enterText(
        find.byKey(const Key('email-field')),
        FakeAuthRepository.validEmail,
      );
      await tester.enterText(
        find.byKey(const Key('password-field')),
        FakeAuthRepository.validPassword,
      );
      await tester.tap(find.byKey(const Key('submit-button')));
      await tester.pumpAndSettle();

      expect(repository.receivedEmail, FakeAuthRepository.validEmail);
      expect(repository.receivedPassword, FakeAuthRepository.validPassword);
      expect(find.byKey(const Key('error-message')), findsNothing);
    });

    testWidgets(
      'rejected credentials show an error message and stay on the login screen',
      (tester) async {
        final repository = FakeAuthRepository();
        final controller = LoginController(SignIn(repository));
        await pumpLoginScreen(tester, controller);

        await tester.enterText(
          find.byKey(const Key('email-field')),
          'user@example.com',
        );
        await tester.enterText(
          find.byKey(const Key('password-field')),
          'wrong-password',
        );
        await tester.tap(find.byKey(const Key('submit-button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('error-message')), findsOneWidget);
        expect(
          find.text('Incorrect email or password.'),
          findsOneWidget,
        );
        // Stays on the login screen.
        expect(find.byKey(const Key('email-field')), findsOneWidget);
        expect(find.byKey(const Key('password-field')), findsOneWidget);
      },
    );
  });
}
