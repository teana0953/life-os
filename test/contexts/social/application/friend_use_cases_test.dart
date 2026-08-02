import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/social/application/friend_use_cases.dart';
import 'package:life_os/contexts/social/domain/friend.dart';
import 'package:life_os/contexts/social/domain/friend_invite.dart';
import 'package:life_os/contexts/social/domain/invite_preview.dart';
import 'package:life_os/contexts/social/domain/social_exceptions.dart';
import 'package:life_os/contexts/social/domain/social_repository.dart';

class _FakeSocialRepository implements SocialRepository {
  String? gotIdToken;
  String? gotFriendUserId;
  Object? failNext;

  List<Friend> friendsToReturn = const [];

  @override
  Future<List<Friend>> listFriends(String idToken) async {
    gotIdToken = idToken;
    final failure = failNext;
    if (failure != null) throw failure;
    return friendsToReturn;
  }

  @override
  Future<void> removeFriend(String idToken, String friendUserId) async {
    gotIdToken = idToken;
    gotFriendUserId = friendUserId;
    final failure = failNext;
    if (failure != null) throw failure;
  }

  @override
  Future<({String token, String expiresAt})> createInvite(String idToken) =>
      throw UnimplementedError();

  @override
  Future<List<FriendInvite>> listInvites(String idToken) => throw UnimplementedError();

  @override
  Future<void> revokeInvite(String idToken, String id) => throw UnimplementedError();

  @override
  Future<InvitePreview> previewInvite(String idToken, String token) =>
      throw UnimplementedError();

  @override
  Future<AcceptInviteResult> acceptInvite(String idToken, String token) =>
      throw UnimplementedError();
}

void main() {
  test('ListFriends delegates to the repository', () async {
    final repository = _FakeSocialRepository()
      ..friendsToReturn = const [Friend(userId: 'u1', displayName: 'Alex')];

    final friends = await ListFriends(repository)('token-1');

    expect(repository.gotIdToken, 'token-1');
    expect(friends.single.displayName, 'Alex');
  });

  test('ListFriends lets the repository error propagate', () async {
    final repository = _FakeSocialRepository()..failNext = const SocialFetchFailure();

    expect(
      () => ListFriends(repository)('token-1'),
      throwsA(isA<SocialFetchFailure>()),
    );
  });

  test('RemoveFriend delegates to the repository', () async {
    final repository = _FakeSocialRepository();

    await RemoveFriend(repository)('token-1', 'friend-1');

    expect(repository.gotIdToken, 'token-1');
    expect(repository.gotFriendUserId, 'friend-1');
  });

  test('RemoveFriend lets the repository error propagate', () async {
    final repository = _FakeSocialRepository()..failNext = const SocialNotFound();

    expect(
      () => RemoveFriend(repository)('token-1', 'friend-1'),
      throwsA(isA<SocialNotFound>()),
    );
  });
}
