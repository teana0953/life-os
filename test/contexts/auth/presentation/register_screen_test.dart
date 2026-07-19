import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/application/sign_up.dart';
import 'package:life_os/contexts/auth/domain/auth_exceptions.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/auth/presentation/register_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';

class FakeAuthRepository implements AuthRepository {
  static const validEmail = 'new-user@example.com';

  bool signUpCalled = false;
  String? receivedEmail;
  String? receivedPassword;
  Object? signUpErrorToThrow;

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

Future<void> pumpRegisterScreen(
  WidgetTester tester,
  AuthRepository repository, {
  Locale locale = const Locale('en'),
}) async {
  final localeController = await testLocaleController();
  await tester.pumpWidget(
    l10nTestApp(
      locale: locale,
      localeController: localeController,
      home: RegisterScreen(
        signUp: SignUp(repository),
        localeController: localeController,
      ),
    ),
  );
}

void main() {
  group('RegisterScreen', () {
    testWidgets('renders email, password, and confirm-password fields', (
      tester,
    ) async {
      await pumpRegisterScreen(tester, FakeAuthRepository());

      expect(find.byKey(const Key('email-field')), findsOneWidget);
      expect(find.byKey(const Key('password-field')), findsOneWidget);
      expect(find.byKey(const Key('confirm-password-field')), findsOneWidget);
      expect(find.byKey(const Key('submit-button')), findsOneWidget);
    });

    testWidgets(
      'mismatched passwords show a localized error and do not call sign-up',
      (tester) async {
        final repository = FakeAuthRepository();
        await pumpRegisterScreen(tester, repository);

        await tester.enterText(
          find.byKey(const Key('email-field')),
          FakeAuthRepository.validEmail,
        );
        await tester.enterText(
          find.byKey(const Key('password-field')),
          'password1',
        );
        await tester.enterText(
          find.byKey(const Key('confirm-password-field')),
          'password2',
        );
        await tester.tap(find.byKey(const Key('submit-button')));
        await tester.pumpAndSettle();

        expect(
          find.text(lookupAppLocalizations(const Locale('en')).errorPasswordMismatch),
          findsOneWidget,
        );
        expect(repository.signUpCalled, isFalse);
      },
    );

    testWidgets(
      'email already in use shows the localized error and stays on the register screen',
      (tester) async {
        final repository = FakeAuthRepository()
          ..signUpErrorToThrow = const AuthFailure(
            AuthFailureCode.emailAlreadyInUse,
          );
        await pumpRegisterScreen(tester, repository);

        await tester.enterText(
          find.byKey(const Key('email-field')),
          FakeAuthRepository.validEmail,
        );
        await tester.enterText(
          find.byKey(const Key('password-field')),
          'password1',
        );
        await tester.enterText(
          find.byKey(const Key('confirm-password-field')),
          'password1',
        );
        await tester.tap(find.byKey(const Key('submit-button')));
        await tester.pumpAndSettle();

        expect(
          find.text(
            lookupAppLocalizations(const Locale('en')).errorEmailAlreadyInUse,
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('email-field')), findsOneWidget);
      },
    );

    testWidgets(
      'weak password shows the localized error',
      (tester) async {
        final repository = FakeAuthRepository()
          ..signUpErrorToThrow = const AuthFailure(AuthFailureCode.weakPassword);
        await pumpRegisterScreen(tester, repository);

        await tester.enterText(
          find.byKey(const Key('email-field')),
          FakeAuthRepository.validEmail,
        );
        await tester.enterText(
          find.byKey(const Key('password-field')),
          'abc',
        );
        await tester.enterText(
          find.byKey(const Key('confirm-password-field')),
          'abc',
        );
        await tester.tap(find.byKey(const Key('submit-button')));
        await tester.pumpAndSettle();

        expect(
          find.text(lookupAppLocalizations(const Locale('en')).errorWeakPassword),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'invalid email shows the localized error',
      (tester) async {
        final repository = FakeAuthRepository()
          ..signUpErrorToThrow = const AuthFailure(AuthFailureCode.invalidEmail);
        await pumpRegisterScreen(tester, repository);

        await tester.enterText(
          find.byKey(const Key('email-field')),
          'not-an-email',
        );
        await tester.enterText(
          find.byKey(const Key('password-field')),
          'password1',
        );
        await tester.enterText(
          find.byKey(const Key('confirm-password-field')),
          'password1',
        );
        await tester.tap(find.byKey(const Key('submit-button')));
        await tester.pumpAndSettle();

        expect(
          find.text(lookupAppLocalizations(const Locale('en')).errorInvalidEmail),
          findsOneWidget,
        );
      },
    );

    testWidgets('successful registration pops the pushed register screen', (
      tester,
    ) async {
      final repository = FakeAuthRepository();
      final localeController = await testLocaleController();
      await tester.pumpWidget(
        l10nTestApp(
          localeController: localeController,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open-register'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RegisterScreen(
                          signUp: SignUp(repository),
                          localeController: localeController,
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open-register')));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('email-field')),
        FakeAuthRepository.validEmail,
      );
      await tester.enterText(
        find.byKey(const Key('password-field')),
        'password1',
      );
      await tester.enterText(
        find.byKey(const Key('confirm-password-field')),
        'password1',
      );
      await tester.tap(find.byKey(const Key('submit-button')));
      await tester.pumpAndSettle();

      expect(repository.signUpCalled, isTrue);
      expect(find.byType(RegisterScreen), findsNothing);
      expect(find.byKey(const Key('open-register')), findsOneWidget);
    });

    testWidgets('the sign-in link pops back to the previous screen', (
      tester,
    ) async {
      final repository = FakeAuthRepository();
      final localeController = await testLocaleController();
      await tester.pumpWidget(
        l10nTestApp(
          localeController: localeController,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open-register'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RegisterScreen(
                          signUp: SignUp(repository),
                          localeController: localeController,
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open-register')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sign-in-link')));
      await tester.pumpAndSettle();

      expect(find.byType(RegisterScreen), findsNothing);
      expect(find.byKey(const Key('open-register')), findsOneWidget);
    });
  });
}
