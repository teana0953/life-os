import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/social/application/invite_use_cases.dart';
import 'package:life_os/contexts/social/domain/friend.dart';
import 'package:life_os/contexts/social/domain/friend_invite.dart';
import 'package:life_os/contexts/social/domain/invite_preview.dart';
import 'package:life_os/contexts/social/domain/social_exceptions.dart';
import 'package:life_os/contexts/social/domain/social_repository.dart';

class _FakeSocialRepository implements SocialRepository {
  String? gotIdToken;
  String? gotId;
  String? gotToken;
  Object? failNext;

  ({String token, String expiresAt}) createInviteToReturn = (
    token: 'plaintext-token',
    expiresAt: '2026-08-09T00:00:00.000Z',
  );
  List<FriendInvite> invitesToReturn = const [];
  InvitePreview previewToReturn = const InvitePreview(
    inviterDisplayName: 'Alex',
    alreadyFriends: false,
  );
  AcceptInviteResult acceptToReturn = const AcceptInviteResult(
    friend: Friend(userId: 'u1', displayName: 'Alex'),
    alreadyFriends: false,
  );

  @override
  Future<List<Friend>> listFriends(String idToken) => throw UnimplementedError();

  @override
  Future<void> removeFriend(String idToken, String friendUserId) =>
      throw UnimplementedError();

  @override
  Future<({String token, String expiresAt})> createInvite(String idToken) async {
    gotIdToken = idToken;
    final failure = failNext;
    if (failure != null) throw failure;
    return createInviteToReturn;
  }

  @override
  Future<List<FriendInvite>> listInvites(String idToken) async {
    gotIdToken = idToken;
    final failure = failNext;
    if (failure != null) throw failure;
    return invitesToReturn;
  }

  @override
  Future<void> revokeInvite(String idToken, String id) async {
    gotIdToken = idToken;
    gotId = id;
    final failure = failNext;
    if (failure != null) throw failure;
  }

  @override
  Future<InvitePreview> previewInvite(String idToken, String token) async {
    gotIdToken = idToken;
    gotToken = token;
    final failure = failNext;
    if (failure != null) throw failure;
    return previewToReturn;
  }

  @override
  Future<AcceptInviteResult> acceptInvite(String idToken, String token) async {
    gotIdToken = idToken;
    gotToken = token;
    final failure = failNext;
    if (failure != null) throw failure;
    return acceptToReturn;
  }
}

void main() {
  test('CreateInvite delegates to the repository', () async {
    final repository = _FakeSocialRepository();

    final result = await CreateInvite(repository)('token-1');

    expect(repository.gotIdToken, 'token-1');
    expect(result.token, 'plaintext-token');
    expect(result.expiresAt, '2026-08-09T00:00:00.000Z');
  });

  test('ListInvites delegates to the repository', () async {
    final repository = _FakeSocialRepository()
      ..invitesToReturn = const [
        FriendInvite(
          id: 'i1',
          expiresAt: '2026-08-09T00:00:00.000Z',
          createdAt: '2026-08-02T00:00:00.000Z',
        ),
      ];

    final invites = await ListInvites(repository)('token-1');

    expect(repository.gotIdToken, 'token-1');
    expect(invites.single.id, 'i1');
  });

  test('RevokeInvite delegates to the repository', () async {
    final repository = _FakeSocialRepository();

    await RevokeInvite(repository)('token-1', 'invite-1');

    expect(repository.gotIdToken, 'token-1');
    expect(repository.gotId, 'invite-1');
  });

  test('RevokeInvite lets the repository error propagate', () async {
    final repository = _FakeSocialRepository()..failNext = const SocialNotFound();

    expect(
      () => RevokeInvite(repository)('token-1', 'invite-1'),
      throwsA(isA<SocialNotFound>()),
    );
  });

  test('PreviewInvite delegates to the repository', () async {
    final repository = _FakeSocialRepository();

    final preview = await PreviewInvite(repository)('token-1', 'invite-token');

    expect(repository.gotIdToken, 'token-1');
    expect(repository.gotToken, 'invite-token');
    expect(preview.inviterDisplayName, 'Alex');
  });

  test('PreviewInvite lets the repository error propagate', () async {
    final repository = _FakeSocialRepository()..failNext = const InviteExpired();

    expect(
      () => PreviewInvite(repository)('token-1', 'invite-token'),
      throwsA(isA<InviteExpired>()),
    );
  });

  test('AcceptInvite delegates to the repository', () async {
    final repository = _FakeSocialRepository();

    final result = await AcceptInvite(repository)('token-1', 'invite-token');

    expect(repository.gotIdToken, 'token-1');
    expect(repository.gotToken, 'invite-token');
    expect(result.friend.displayName, 'Alex');
  });

  test('AcceptInvite lets the repository error propagate', () async {
    final repository = _FakeSocialRepository()..failNext = const CannotFriendSelf();

    expect(
      () => AcceptInvite(repository)('token-1', 'invite-token'),
      throwsA(isA<CannotFriendSelf>()),
    );
  });
}
