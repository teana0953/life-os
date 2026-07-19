import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/application/sign_in.dart';
import 'package:life_os/contexts/auth/application/sign_up.dart';
import 'package:life_os/contexts/auth/domain/auth_exceptions.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/auth/presentation/login_controller.dart';
import 'package:life_os/contexts/auth/presentation/login_screen.dart';
import 'package:life_os/contexts/auth/presentation/register_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';

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
      throw const AuthFailure(AuthFailureCode.invalidCredentials);
    }
  }

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> idToken() async => null;

  @override
  Stream<bool> get authStateChanges => const Stream.empty();
}

/// Throws an unrecognized exception type, simulating an unexpected failure
/// (e.g. a network error) that is not a known [AuthFailure].
class UnknownErrorAuthRepository implements AuthRepository {
  @override
  Future<void> signIn(String email, String password) async {
    throw Exception('SocketException: Connection refused at 10.0.0.5:443');
  }

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> idToken() async => null;

  @override
  Stream<bool> get authStateChanges => const Stream.empty();
}

/// Never completes sign-in, letting a test observe the loading state.
class HangingAuthRepository implements AuthRepository {
  final Completer<void> signInCompleter = Completer<void>();

  @override
  Future<void> signIn(String email, String password) => signInCompleter.future;

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> idToken() async => null;

  @override
  Stream<bool> get authStateChanges => const Stream.empty();
}

Future<void> pumpLoginScreen(
  WidgetTester tester,
  LoginController controller, {
  Locale locale = const Locale('en'),
  AuthRepository? authRepository,
}) async {
  final localeController = await testLocaleController();
  await tester.pumpWidget(
    l10nTestApp(
      locale: locale,
      localeController: localeController,
      home: LoginScreen(
        controller: controller,
        localeController: localeController,
        signUp: SignUp(authRepository ?? FakeAuthRepository()),
      ),
    ),
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
          find.text(
            lookupAppLocalizations(const Locale('en')).errorIncorrectCredentials,
          ),
          findsOneWidget,
        );
        // Stays on the login screen.
        expect(find.byKey(const Key('email-field')), findsOneWidget);
        expect(find.byKey(const Key('password-field')), findsOneWidget);
      },
    );

    testWidgets(
      'rejected credentials show the error message in Traditional Chinese '
      'when that is the active locale',
      (tester) async {
        final repository = FakeAuthRepository();
        final controller = LoginController(SignIn(repository));
        await pumpLoginScreen(
          tester,
          controller,
          locale: const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hant',
          ),
        );

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

        expect(
          find.text(
            lookupAppLocalizations(
              const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
            ).errorIncorrectCredentials,
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'unexpected errors show a generic message without leaking the '
      'original exception text',
      (tester) async {
        final repository = UnknownErrorAuthRepository();
        final controller = LoginController(SignIn(repository));
        await pumpLoginScreen(tester, controller);

        await tester.enterText(
          find.byKey(const Key('email-field')),
          'user@example.com',
        );
        await tester.enterText(
          find.byKey(const Key('password-field')),
          'some-password',
        );
        await tester.tap(find.byKey(const Key('submit-button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('error-message')), findsOneWidget);
        expect(find.textContaining('10.0.0.5'), findsNothing);
        expect(find.textContaining('SocketException'), findsNothing);
      },
    );

    testWidgets(
      'pressing enter in the password field submits the login form',
      (tester) async {
        final repository = FakeAuthRepository();
        final controller = LoginController(SignIn(repository));
        await pumpLoginScreen(tester, controller);

        await tester.enterText(
          find.byKey(const Key('email-field')),
          FakeAuthRepository.validEmail,
        );
        await tester.tap(find.byKey(const Key('password-field')));
        await tester.enterText(
          find.byKey(const Key('password-field')),
          FakeAuthRepository.validPassword,
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(repository.receivedEmail, FakeAuthRepository.validEmail);
        expect(repository.receivedPassword, FakeAuthRepository.validPassword);
        expect(find.byKey(const Key('error-message')), findsNothing);
      },
    );

    testWidgets(
      'text fields are disabled while a sign-in request is in flight',
      (tester) async {
        final repository = HangingAuthRepository();
        final controller = LoginController(SignIn(repository));
        await pumpLoginScreen(tester, controller);

        await tester.enterText(
          find.byKey(const Key('email-field')),
          'user@example.com',
        );
        await tester.enterText(
          find.byKey(const Key('password-field')),
          'some-password',
        );
        await tester.tap(find.byKey(const Key('submit-button')));
        await tester.pump();

        final emailField = tester.widget<TextField>(
          find.byKey(const Key('email-field')),
        );
        final passwordField = tester.widget<TextField>(
          find.byKey(const Key('password-field')),
        );
        expect(emailField.enabled, isFalse);
        expect(passwordField.enabled, isFalse);

        repository.signInCompleter.complete();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'selecting Traditional Chinese from the language switcher menu '
      'changes the locale',
      (tester) async {
        final repository = FakeAuthRepository();
        final controller = LoginController(SignIn(repository));
        await pumpLoginScreen(tester, controller);

        final en = lookupAppLocalizations(const Locale('en'));
        final zhHant = lookupAppLocalizations(
          const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        );
        expect(find.text(en.welcomeBack), findsOneWidget);

        await tester.tap(find.byKey(const Key('language-switcher')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('language-option-zh')));
        await tester.pumpAndSettle();

        expect(find.text(zhHant.welcomeBack), findsOneWidget);
        expect(find.text(en.welcomeBack), findsNothing);
      },
    );

    testWidgets(
      'tapping the register link pushes RegisterScreen',
      (tester) async {
        final repository = FakeAuthRepository();
        final controller = LoginController(SignIn(repository));
        await pumpLoginScreen(tester, controller, authRepository: repository);

        expect(find.byType(RegisterScreen), findsNothing);
        await tester.tap(find.byKey(const Key('register-link')));
        await tester.pumpAndSettle();

        expect(find.byType(RegisterScreen), findsOneWidget);
      },
    );
  });
}
