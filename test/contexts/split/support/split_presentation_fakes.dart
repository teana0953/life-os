import 'package:life_os/contexts/social/domain/friend.dart';
import 'package:life_os/contexts/social/domain/friend_invite.dart';
import 'package:life_os/contexts/social/domain/invite_preview.dart';
import 'package:life_os/contexts/social/domain/social_repository.dart';
import 'package:life_os/contexts/user/domain/profile_repository.dart';
import 'package:life_os/contexts/user/domain/user_profile.dart';

/// Shared fakes for split-presentation tests (controllers/widgets need a
/// caller profile and a friends list, neither of which `SplitRepository`
/// itself provides — design D5b/D5c).
class FakeProfileRepository implements ProfileRepository {
  UserProfile? profileToReturn;
  Object? failNext;

  @override
  Future<UserProfile> getProfile(String idToken) async {
    if (failNext != null) {
      final failure = failNext!;
      failNext = null;
      throw failure;
    }
    return profileToReturn!;
  }
}

class FakeSocialRepositoryForSplit implements SocialRepository {
  List<Friend> friends = const [];
  Object? failNext;

  @override
  Future<List<Friend>> listFriends(String idToken) async {
    if (failNext != null) {
      final failure = failNext!;
      failNext = null;
      throw failure;
    }
    return friends;
  }

  @override
  Future<void> removeFriend(String idToken, String friendUserId) async {}

  @override
  Future<({String token, String expiresAt})> createInvite(String idToken) =>
      throw UnimplementedError();

  @override
  Future<List<FriendInvite>> listInvites(String idToken) => throw UnimplementedError();

  @override
  Future<void> revokeInvite(String idToken, String id) => throw UnimplementedError();

  @override
  Future<InvitePreview> previewInvite(String idToken, String token) => throw UnimplementedError();

  @override
  Future<AcceptInviteResult> acceptInvite(String idToken, String token) =>
      throw UnimplementedError();
}

UserProfile testProfile({String id = 'self-1'}) => UserProfile(
  id: id,
  firebaseUid: 'fb-$id',
  email: 'self@example.test',
  displayName: 'Self',
  createdAt: '2026-01-01T00:00:00.000Z',
  isAdmin: false,
);
