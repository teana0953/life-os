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

Future<void> pumpHomeScreen(WidgetTester tester, HomeController controller) {
  return tester.pumpWidget(
    MaterialApp(home: HomeScreen(controller: controller)),
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
      'unexpected errors show a generic message without leaking the '
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

        expect(controller.errorMessage, isNot(contains('10.0.0.5')));
        expect(controller.errorMessage, isNot(contains('SocketException')));
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
  });
}
