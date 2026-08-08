import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/application/sign_in.dart';
import 'package:life_os/contexts/auth/application/send_password_reset.dart';
import 'package:life_os/contexts/auth/application/sign_up.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/auth/presentation/login_controller.dart';
import 'package:life_os/contexts/auth/presentation/login_screen.dart';
import 'package:life_os/contexts/auth/presentation/password_reset_screen.dart';
import 'package:life_os/shared/theme/app_theme.dart';

import '../../../support/l10n_test_app.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<void> sendPasswordReset(String email) async {}

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

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repository = _FakeAuthRepository();
  final controller = LoginController(SignIn(repository));
  final localeController = await testLocaleController();
  await tester.pumpWidget(
    l10nTestApp(
      theme: lightTheme,
      home: LoginScreen(
        controller: controller,
        localeController: localeController,
        signUp: SignUp(repository),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  _passwordResetLayoutTests();

  group('LoginScreen responsive layout', () {
    testWidgets('narrow phone width: card fills the available width, no overflow', (
      tester,
    ) async {
      await _pumpAt(tester, const Size(360, 800));

      expect(tester.takeException(), isNull);
      final cardSize = tester.getSize(find.byKey(const Key('login-card')));
      expect(cardSize.width, lessThan(420));
      expect(cardSize.width, greaterThan(200));
    });

    testWidgets('wide desktop width: card is capped at maxWidth ~420', (
      tester,
    ) async {
      await _pumpAt(tester, const Size(1200, 800));

      expect(tester.takeException(), isNull);
      final cardSize = tester.getSize(find.byKey(const Key('login-card')));
      expect(cardSize.width, 420);
    });
  });
}

/// The reset screen at the widths the sign-in screen is guarded at. It is the
/// same card shape, and it is reached from a phone in a hurry — a user who
/// just failed to sign in.
void _passwordResetLayoutTests() {
  Future<void> pumpResetAt(WidgetTester tester, Size size, {double textScale = 1.0}) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final localeController = await testLocaleController();
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: l10nTestApp(
          theme: lightTheme,
          home: PasswordResetScreen(
            sendPasswordReset: SendPasswordReset(_FakeAuthRepository()),
            localeController: localeController,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('PasswordResetScreen responsive layout', () {
    for (final size in [const Size(320, 800), const Size(360, 800)]) {
      for (final textScale in [1.0, 2.0]) {
        testWidgets(
          'lays out at ${size.width.toInt()}dp, textScale=$textScale',
          (tester) async {
            // The confirmation copy is three lines of prose naming the spam
            // folder, so this screen is taller than the sign-in card it was
            // copied from — the width guard alone would not have noticed.
            await pumpResetAt(tester, size, textScale: textScale);
            expect(tester.takeException(), isNull);

            final cardWidth = tester.getSize(find.byKey(const Key('password-reset-card'))).width;
            expect(cardWidth, lessThanOrEqualTo(size.width));
          },
        );
      }
    }
  });
}
