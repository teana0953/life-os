import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/contexts/user/domain/profile_repository.dart';
import 'package:life_os/contexts/user/domain/user_profile.dart';

class FakeProfileRepository implements ProfileRepository {
  UserProfile? profileToReturn;
  Object? errorToThrow;
  String? receivedIdToken;

  @override
  Future<UserProfile> getProfile(String idToken) async {
    receivedIdToken = idToken;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return profileToReturn!;
  }
}

void main() {
  group('GetProfile', () {
    test('returns the profile fetched via the repository', () async {
      final repository = FakeProfileRepository()
        ..profileToReturn = UserProfile(
          id: 'user-1',
          firebaseUid: 'firebase-abc',
          email: 'test@example.com',
          displayName: 'Test User',
          createdAt: '2026-01-01T00:00:00.000Z',
          isAdmin: false,
        );
      final getProfile = GetProfile(repository);

      final profile = await getProfile('id-token-123');

      expect(profile.id, 'user-1');
      expect(repository.receivedIdToken, 'id-token-123');
    });

    test('propagates repository errors', () async {
      final repository = FakeProfileRepository()
        ..errorToThrow = Exception('boom');
      final getProfile = GetProfile(repository);

      expect(() => getProfile('id-token-123'), throwsException);
    });
  });
}
