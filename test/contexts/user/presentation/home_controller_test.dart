import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/contexts/user/domain/profile_exceptions.dart';
import 'package:life_os/contexts/user/domain/profile_repository.dart';
import 'package:life_os/contexts/user/domain/user_profile.dart';
import 'package:life_os/contexts/user/presentation/home_controller.dart';

class _CountingProfileRepository implements ProfileRepository {
  int callCount = 0;
  UserProfile? profileToReturn;
  Object? errorToThrow;

  @override
  Future<UserProfile> getProfile(String idToken) async {
    callCount++;
    if (errorToThrow != null) throw errorToThrow!;
    return profileToReturn!;
  }
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> idToken() async => 'fake-token';

  @override
  Stream<bool> get authStateChanges => const Stream.empty();
}

UserProfile _profile() => UserProfile(
  id: 'user-1',
  firebaseUid: 'firebase-abc',
  email: 'test@example.com',
  displayName: 'Test User',
  createdAt: '2026-01-01T00:00:00.000Z',
  isAdmin: false,
);

void main() {
  group('HomeController.ensureLoaded', () {
    test('calls GetProfile exactly once when invoked repeatedly while loaded', () async {
      final repository = _CountingProfileRepository()..profileToReturn = _profile();
      final controller = HomeController(
        GetProfile(repository),
        SignOut(_FakeAuthRepository()),
      );

      await controller.ensureLoaded('token');
      await controller.ensureLoaded('token');
      await controller.ensureLoaded('token');

      expect(repository.callCount, 1);
    });

    test('does not fire a second fetch while the first is in flight', () async {
      final repository = _CountingProfileRepository()..profileToReturn = _profile();
      final controller = HomeController(
        GetProfile(repository),
        SignOut(_FakeAuthRepository()),
      );

      final first = controller.ensureLoaded('token');
      final second = controller.ensureLoaded('token');
      await Future.wait(<Future<void>>[first, second]);

      expect(repository.callCount, 1);
    });

    test('retries after a failed load', () async {
      final repository = _CountingProfileRepository()
        ..errorToThrow = const ProfileFetchFailure('failed');
      final controller = HomeController(
        GetProfile(repository),
        SignOut(_FakeAuthRepository()),
      );

      await controller.ensureLoaded('token');
      expect(repository.callCount, 1);
      expect(controller.profile, isNull);

      repository.errorToThrow = null;
      repository.profileToReturn = _profile();
      await controller.ensureLoaded('token');

      expect(repository.callCount, 2);
      expect(controller.profile, isNotNull);
    });
  });

  group('HomeController.reset', () {
    test('clears the profile so a later ensureLoaded fetches again', () async {
      final repository = _CountingProfileRepository()..profileToReturn = _profile();
      final controller = HomeController(
        GetProfile(repository),
        SignOut(_FakeAuthRepository()),
      );

      await controller.ensureLoaded('token');
      expect(repository.callCount, 1);

      controller.reset();
      expect(controller.profile, isNull);

      await controller.ensureLoaded('token');
      expect(repository.callCount, 2);
    });
  });
}
