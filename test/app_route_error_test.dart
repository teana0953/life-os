import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/contexts/auth/application/sign_in.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/presentation/login_controller.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/contexts/user/domain/user_profile.dart';
import 'package:life_os/contexts/user/presentation/home_controller.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import 'app_test.dart';
import 'support/l10n_test_app.dart';

const _zhHant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');

final _testProfile = UserProfile(
  id: 'user-1',
  firebaseUid: 'firebase-abc',
  email: 'user@example.com',
  displayName: 'Test User',
  createdAt: '2026-01-01T00:00:00.000Z',
  isAdmin: false,
);

/// Drives the app to a location no route matches — a stale bookmark, a
/// hand-typed URL, the Pages SPA fallback. A hand-over cannot get here any
/// more (it is dropped before navigating, design D2), which is why this test
/// goes through the router directly rather than through the store.
Future<void> _goToUnmatched(WidgetTester tester) async {
  GoRouter.of(
    tester.element(find.byType(Scaffold).first),
  ).go('/no-such-route');
  await tester.pumpAndSettle();
}

void main() {
  group('unmatched location', () {
    testWidgets('is explained in the user language, with a way out', (
      tester,
    ) async {
      final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
      final profileRepository = FakeProfileRepository(_testProfile);
      final localeController = await testLocaleController();
      await localeController.setLocale(_zhHant);
      await pumpApp(
        tester,
        authRepository: authRepository,
        loginController: LoginController(SignIn(authRepository)),
        homeController: HomeController(
          GetProfile(profileRepository),
          SignOut(authRepository),
        ),
        localeController: localeController,
      );
      await tester.pumpAndSettle();

      await _goToUnmatched(tester);

      final zh = lookupAppLocalizations(_zhHant);
      expect(find.text(zh.routeNotFound), findsOneWidget);
      expect(find.text(zh.routeNotFoundGoHome), findsOneWidget);
      // go_router's own default, which is untranslated whatever the user has
      // chosen — the thing this screen exists to replace.
      expect(find.text('Page Not Found'), findsNothing);
    });

    testWidgets('is in English when the app is in English', (tester) async {
      final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
      final profileRepository = FakeProfileRepository(_testProfile);
      final localeController = await testLocaleController();
      await localeController.setLocale(const Locale('en'));
      await pumpApp(
        tester,
        authRepository: authRepository,
        loginController: LoginController(SignIn(authRepository)),
        homeController: HomeController(
          GetProfile(profileRepository),
          SignOut(authRepository),
        ),
        localeController: localeController,
      );
      await tester.pumpAndSettle();

      await _goToUnmatched(tester);

      final en = lookupAppLocalizations(const Locale('en'));
      expect(find.text(en.routeNotFound), findsOneWidget);
      // Both locales assert their own copy: a screen that hard-coded one
      // language would pass whichever half matched it and fail the other.
      expect(find.text(en.routeNotFoundGoHome), findsOneWidget);
    });

    testWidgets('the way out actually leaves', (tester) async {
      final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
      final profileRepository = FakeProfileRepository(_testProfile);
      await pumpApp(
        tester,
        authRepository: authRepository,
        loginController: LoginController(SignIn(authRepository)),
        homeController: HomeController(
          GetProfile(profileRepository),
          SignOut(authRepository),
        ),
      );
      await tester.pumpAndSettle();

      await _goToUnmatched(tester);
      expect(find.byKey(const Key('route-error-screen')), findsOneWidget);

      await tester.tap(find.byKey(const Key('route-error-home-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('health-dashboard-section')), findsOneWidget);
      expect(find.byKey(const Key('route-error-screen')), findsNothing);
      // `go`, not `push`: the unmatched location must not stay in the stack
      // the back affordance walks.
      final context = tester.element(
        find.byKey(const Key('health-dashboard-section')),
      );
      expect(Navigator.canPop(context), isFalse);
    });
  });
}
