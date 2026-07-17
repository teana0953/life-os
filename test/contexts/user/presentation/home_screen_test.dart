import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/contexts/user/domain/profile_exceptions.dart';
import 'package:life_os/contexts/user/domain/profile_repository.dart';
import 'package:life_os/contexts/user/domain/user_profile.dart';
import 'package:life_os/contexts/user/presentation/home_controller.dart';
import 'package:life_os/contexts/user/presentation/home_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';

class FakeProfileRepository implements ProfileRepository {
  UserProfile? profileToReturn;
  Object? errorToThrow;

  @override
  Future<UserProfile> getProfile(String idToken) async {
    if (errorToThrow != null) throw errorToThrow!;
    return profileToReturn!;
  }
}

class FakeAuthRepository implements AuthRepository {
  bool signOutCalled = false;

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }

  @override
  Future<String?> idToken() async => 'fake-token';

  @override
  Stream<bool> get authStateChanges => const Stream.empty();
}

Future<void> pumpHomeScreen(
  WidgetTester tester,
  HomeController controller, {
  DateTime Function()? clock,
  Locale locale = const Locale('en'),
}) async {
  final localeController = await testLocaleController();
  await tester.pumpWidget(
    l10nTestApp(
      locale: locale,
      localeController: localeController,
      home: HomeScreen(
        controller: controller,
        localeController: localeController,
        clock: clock ?? DateTime.now,
      ),
    ),
  );
}

void main() {
  group('HomeScreen', () {
    testWidgets('shows the loaded profile email and id', (tester) async {
      final profileRepository = FakeProfileRepository()
        ..profileToReturn = UserProfile(
          id: 'user-1',
          firebaseUid: 'firebase-abc',
          email: 'test@example.com',
          displayName: 'Test User',
          createdAt: '2026-01-01T00:00:00.000Z',
        );
      final authRepository = FakeAuthRepository();
      final controller = HomeController(
        GetProfile(profileRepository),
        SignOut(authRepository),
      );
      await controller.load('token-123');
      await pumpHomeScreen(tester, controller);

      expect(find.text('test@example.com'), findsOneWidget);
      expect(find.text('user-1'), findsOneWidget);
    });

    testWidgets(
      'shows an error state and a sign-out option when the profile request fails',
      (tester) async {
        final profileRepository = FakeProfileRepository()
          ..errorToThrow = const ProfileFetchFailure('server error');
        final authRepository = FakeAuthRepository();
        final controller = HomeController(
          GetProfile(profileRepository),
          SignOut(authRepository),
        );
        await controller.load('token-123');
        await pumpHomeScreen(tester, controller);

        expect(find.byKey(const Key('error-message')), findsOneWidget);
        final signOutButton = find.byKey(const Key('sign-out-button'));
        expect(signOutButton, findsOneWidget);

        await tester.tap(signOutButton);
        await tester.pumpAndSettle();

        expect(authRepository.signOutCalled, isTrue);
      },
    );

    testWidgets(
      'shows the profile-load error message in Traditional Chinese when '
      'that is the active locale',
      (tester) async {
        final profileRepository = FakeProfileRepository()
          ..errorToThrow = const ProfileFetchFailure('server error');
        final authRepository = FakeAuthRepository();
        final controller = HomeController(
          GetProfile(profileRepository),
          SignOut(authRepository),
        );
        await controller.load('token-123');
        await pumpHomeScreen(
          tester,
          controller,
          locale: const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hant',
          ),
        );

        expect(
          find.text(
            lookupAppLocalizations(
              const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
            ).errorProfileLoadFailed,
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'unexpected errors set a generic, untyped error without leaking the '
      'original exception text',
      (tester) async {
        final profileRepository = FakeProfileRepository()
          ..errorToThrow = Exception(
            'SocketException: Connection refused at 10.0.0.5:443',
          );
        final authRepository = FakeAuthRepository();
        final controller = HomeController(
          GetProfile(profileRepository),
          SignOut(authRepository),
        );
        await controller.load('token-123');

        // The error is a typed enum, not a string — it structurally cannot
        // leak exception text.
        expect(controller.error, ProfileError.unknown);
      },
    );

    testWidgets(
      '401 shows a "sign in again" exit rather than a dead end',
      (tester) async {
        final profileRepository = FakeProfileRepository()
          ..errorToThrow = const ReauthenticationRequired();
        final authRepository = FakeAuthRepository();
        final controller = HomeController(
          GetProfile(profileRepository),
          SignOut(authRepository),
        );
        await controller.load('token-123');
        await pumpHomeScreen(tester, controller);

        final signInAgainButton = find.byKey(
          const Key('sign-in-again-button'),
        );
        expect(signInAgainButton, findsOneWidget);

        await tester.tap(signInAgainButton);
        await tester.pumpAndSettle();

        expect(authRepository.signOutCalled, isTrue);
      },
    );

    testWidgets('tapping the language switcher toggles the locale', (
      tester,
    ) async {
      final profileRepository = FakeProfileRepository()
        ..profileToReturn = UserProfile(
          id: 'user-1',
          firebaseUid: 'firebase-abc',
          email: 'test@example.com',
          displayName: 'Test User',
          createdAt: '2026-01-01T00:00:00.000Z',
        );
      final authRepository = FakeAuthRepository();
      final controller = HomeController(
        GetProfile(profileRepository),
        SignOut(authRepository),
      );
      await controller.load('token-123');
      await pumpHomeScreen(
        tester,
        controller,
        clock: () => DateTime(2026, 1, 1, 8),
      );

      final en = lookupAppLocalizations(const Locale('en'));
      final zhHant = lookupAppLocalizations(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      );
      expect(find.text(en.greetingMorning), findsOneWidget);

      await tester.tap(find.byKey(const Key('language-switcher')));
      await tester.pump();

      expect(find.text(zhHant.greetingMorning), findsOneWidget);
      expect(find.text(en.greetingMorning), findsNothing);
    });
  });

  group('HomeScreen greeting', () {
    Future<HomeController> loadedController() async {
      final profileRepository = FakeProfileRepository()
        ..profileToReturn = UserProfile(
          id: 'user-1',
          firebaseUid: 'firebase-abc',
          email: 'test@example.com',
          displayName: 'Test User',
          createdAt: '2026-01-01T00:00:00.000Z',
        );
      final controller = HomeController(
        GetProfile(profileRepository),
        SignOut(FakeAuthRepository()),
      );
      await controller.load('token-123');
      return controller;
    }

    testWidgets('shows a morning greeting before noon', (tester) async {
      final controller = await loadedController();
      await pumpHomeScreen(
        tester,
        controller,
        clock: () => DateTime(2026, 1, 1, 8),
      );

      expect(
        find.text(lookupAppLocalizations(const Locale('en')).greetingMorning),
        findsOneWidget,
      );
    });

    testWidgets('shows an afternoon greeting from noon until evening', (
      tester,
    ) async {
      final controller = await loadedController();
      await pumpHomeScreen(
        tester,
        controller,
        clock: () => DateTime(2026, 1, 1, 14),
      );

      expect(
        find.text(
          lookupAppLocalizations(const Locale('en')).greetingAfternoon,
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows an evening greeting after 6pm', (tester) async {
      final controller = await loadedController();
      await pumpHomeScreen(
        tester,
        controller,
        clock: () => DateTime(2026, 1, 1, 20),
      );

      expect(
        find.text(lookupAppLocalizations(const Locale('en')).greetingEvening),
        findsOneWidget,
      );
    });
  });
}
