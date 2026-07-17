import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/app.dart';
import 'package:life_os/contexts/auth/application/sign_in.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/domain/auth_exceptions.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/auth/presentation/login_controller.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/contexts/user/domain/profile_repository.dart';
import 'package:life_os/contexts/user/domain/user_profile.dart';
import 'package:life_os/contexts/user/presentation/home_controller.dart';

class FakeAuthRepository implements AuthRepository {
  static const validEmail = 'user@example.com';
  static const validPassword = 'correct-password';

  FakeAuthRepository({bool initiallyAuthenticated = false})
      : _isAuthenticated = initiallyAuthenticated;

  bool _isAuthenticated;
  bool signOutCalled = false;
  final _controller = StreamController<bool>.broadcast();

  @override
  Future<void> signIn(String email, String password) async {
    if (email != validEmail || password != validPassword) {
      throw const AuthFailure('Incorrect email or password.');
    }
    _isAuthenticated = true;
    _controller.add(true);
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
    _isAuthenticated = false;
    _controller.add(false);
  }

  @override
  Future<String?> idToken() async => _isAuthenticated ? 'fake-token' : null;

  @override
  Stream<bool> get authStateChanges async* {
    yield _isAuthenticated;
    yield* _controller.stream;
  }
}

class ErroringAuthRepository implements AuthRepository {
  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> idToken() async => null;

  @override
  Stream<bool> get authStateChanges =>
      Stream<bool>.error(Exception('boom: internal stream detail'));
}

class FakeProfileRepository implements ProfileRepository {
  final UserProfile profile;

  FakeProfileRepository(this.profile);

  @override
  Future<UserProfile> getProfile(String idToken) async => profile;
}

final _testProfile = UserProfile(
  id: 'user-1',
  firebaseUid: 'firebase-abc',
  email: 'user@example.com',
  displayName: 'Test User',
  createdAt: '2026-01-01T00:00:00.000Z',
);

void main() {
  group('App auth-state routing', () {
    testWidgets('starts unauthenticated shows the login screen', (
      tester,
    ) async {
      final authRepository = FakeAuthRepository();
      final profileRepository = FakeProfileRepository(_testProfile);
      await tester.pumpWidget(
        App(
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: HomeController(
            GetProfile(profileRepository),
            SignOut(authRepository),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('email-field')), findsOneWidget);
    });

    testWidgets(
      'starts authenticated fetches the profile and shows the home screen',
      (tester) async {
        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = FakeProfileRepository(_testProfile);
        await tester.pumpWidget(
          App(
            authRepository: authRepository,
            loginController: LoginController(SignIn(authRepository)),
            homeController: HomeController(
              GetProfile(profileRepository),
              SignOut(authRepository),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('user@example.com'), findsOneWidget);
        expect(find.text('user-1'), findsOneWidget);
      },
    );

    testWidgets('successful sign-in transitions to the home screen', (
      tester,
    ) async {
      final authRepository = FakeAuthRepository();
      final profileRepository = FakeProfileRepository(_testProfile);
      await tester.pumpWidget(
        App(
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: HomeController(
            GetProfile(profileRepository),
            SignOut(authRepository),
          ),
        ),
      );
      await tester.pump();

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

      expect(find.text('user@example.com'), findsOneWidget);
      expect(find.text('user-1'), findsOneWidget);
    });

    testWidgets('sign-out returns to the login screen', (tester) async {
      final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
      final profileRepository = FakeProfileRepository(_testProfile);
      await tester.pumpWidget(
        App(
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: HomeController(
            GetProfile(profileRepository),
            SignOut(authRepository),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sign-out-button')));
      await tester.pumpAndSettle();

      expect(authRepository.signOutCalled, isTrue);
      expect(find.byKey(const Key('email-field')), findsOneWidget);
    });

    testWidgets(
      'auth stream error shows a recoverable error screen instead of an '
      'infinite spinner',
      (tester) async {
        final authRepository = ErroringAuthRepository();
        final profileRepository = FakeProfileRepository(_testProfile);
        await tester.pumpWidget(
          App(
            authRepository: authRepository,
            loginController: LoginController(SignIn(authRepository)),
            homeController: HomeController(
              GetProfile(profileRepository),
              SignOut(authRepository),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byKey(const Key('auth-retry-button')), findsOneWidget);
      },
    );
  });
}
