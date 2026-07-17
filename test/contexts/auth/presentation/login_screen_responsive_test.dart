import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/application/sign_in.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/auth/presentation/login_controller.dart';
import 'package:life_os/contexts/auth/presentation/login_screen.dart';
import 'package:life_os/shared/theme/app_theme.dart';

import '../../../support/l10n_test_app.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<void> signIn(String email, String password) async {}

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

  final controller = LoginController(SignIn(_FakeAuthRepository()));
  final localeController = await testLocaleController();
  await tester.pumpWidget(
    l10nTestApp(
      theme: lightTheme,
      home: LoginScreen(controller: controller, localeController: localeController),
    ),
  );
  await tester.pump();
}

void main() {
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
