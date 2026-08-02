import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/social/application/friend_use_cases.dart';
import 'package:life_os/contexts/social/application/invite_use_cases.dart';
import 'package:life_os/contexts/social/domain/friend.dart';
import 'package:life_os/contexts/social/domain/friend_invite.dart';
import 'package:life_os/contexts/social/domain/invite_preview.dart';
import 'package:life_os/contexts/social/domain/social_exceptions.dart';
import 'package:life_os/contexts/social/domain/social_repository.dart';
import 'package:life_os/contexts/social/presentation/friends_controller.dart';

class _FakeSocialRepository implements SocialRepository {
  List<Friend> friends = const [];

  /// Completed by the test to release an in-flight `listFriends`, so a
  /// dispose can be interleaved with a request that has not landed yet.
  Completer<void>? gate;
  List<FriendInvite> invites = const [];

  Object? listFriendsError;
  Object? listInvitesError;
  Object? removeFriendError;
  Object? createInviteError;
  Object? revokeInviteError;

  ({String token, String expiresAt}) createInviteResult = (
    token: 'plaintext-token',
    expiresAt: '2026-09-01T00:00:00Z',
  );

  String? lastRemovedFriendUserId;
  String? lastRevokedInviteId;
  int removeFriendCalls = 0;
  int revokeInviteCalls = 0;

  @override
  Future<List<Friend>> listFriends(String idToken) async {
    final pending = gate;
    if (pending != null) await pending.future;
    final failure = listFriendsError;
    if (failure != null) throw failure;
    return friends;
  }

  @override
  Future<void> removeFriend(String idToken, String friendUserId) async {
    removeFriendCalls += 1;
    lastRemovedFriendUserId = friendUserId;
    final failure = removeFriendError;
    if (failure != null) throw failure;
    friends = friends.where((f) => f.userId != friendUserId).toList();
  }

  @override
  Future<({String token, String expiresAt})> createInvite(String idToken) async {
    final failure = createInviteError;
    if (failure != null) throw failure;
    return createInviteResult;
  }

  @override
  Future<List<FriendInvite>> listInvites(String idToken) async {
    final failure = listInvitesError;
    if (failure != null) throw failure;
    return invites;
  }

  @override
  Future<void> revokeInvite(String idToken, String id) async {
    revokeInviteCalls += 1;
    lastRevokedInviteId = id;
    final failure = revokeInviteError;
    if (failure != null) throw failure;
    invites = invites.where((i) => i.id != id).toList();
  }

  @override
  Future<InvitePreview> previewInvite(String idToken, String token) =>
      throw UnimplementedError();

  @override
  Future<AcceptInviteResult> acceptInvite(String idToken, String token) =>
      throw UnimplementedError();
}

FriendsController _controller(_FakeSocialRepository repository) => FriendsController(
  ListFriends(repository),
  RemoveFriend(repository),
  CreateInvite(repository),
  ListInvites(repository),
  RevokeInvite(repository),
);

const _alex = Friend(userId: 'u1', displayName: 'Alex');
final _outstandingInvite = FriendInvite(
  id: 'inv-1',
  expiresAt: '2026-09-01T00:00:00Z',
  createdAt: '2026-08-01T00:00:00Z',
);

void main() {
  group('FriendsController.load', () {
    test('loads friends and invites together', () async {
      final repository = _FakeSocialRepository()
        ..friends = [_alex]
        ..invites = [_outstandingInvite];
      final controller = _controller(repository);

      await controller.load('token-1');

      expect(controller.status, FriendsStatus.loaded);
      expect(controller.friends, [_alex]);
      expect(controller.invites, [_outstandingInvite]);
    });

    test('a fetch failure surfaces as an error status', () async {
      final repository = _FakeSocialRepository()
        ..listFriendsError = const SocialFetchFailure();
      final controller = _controller(repository);

      await controller.load('token-1');

      expect(controller.status, FriendsStatus.error);
      expect(controller.error, FriendsError.fetchFailed);
    });

    test('a 401 surfaces as needsReauth', () async {
      final repository = _FakeSocialRepository()
        ..listInvitesError = const SocialReauthenticationRequired();
      final controller = _controller(repository);

      await controller.load('token-1');

      expect(controller.status, FriendsStatus.needsReauth);
    });
  });

  group('FriendsController.removeFriend', () {
    test('removes the friend and refreshes the list on success', () async {
      final repository = _FakeSocialRepository()..friends = [_alex];
      final controller = _controller(repository);
      await controller.load('token-1');

      await controller.removeFriend('token-1', 'u1');

      expect(controller.friends, isEmpty);
      expect(repository.lastRemovedFriendUserId, 'u1');
      expect(controller.mutationError, isNull);
    });

    test(
      'a 404 (already gone) surfaces its own message distinct from generic '
      'failure, and still refreshes the list',
      () async {
        final repository = _FakeSocialRepository()..friends = [_alex];
        final controller = _controller(repository);
        await controller.load('token-1');

        repository.removeFriendError = const SocialNotFound();
        await controller.removeFriend('token-1', 'u1');

        expect(controller.mutationError, FriendsMutationError.removeNotFound);
        // The list was refreshed even though the removal itself failed.
        expect(controller.status, FriendsStatus.loaded);
      },
    );

    test('a generic failure keeps the existing list and surfaces its own message', () async {
      final repository = _FakeSocialRepository()
        ..friends = [_alex]
        ..removeFriendError = const SocialFetchFailure();
      final controller = _controller(repository);
      await controller.load('token-1');

      await controller.removeFriend('token-1', 'u1');

      expect(controller.friends, [_alex]);
      expect(controller.mutationError, FriendsMutationError.removeFailed);
    });

    test('a second call while one is in flight is ignored (busy guard)', () async {
      final repository = _FakeSocialRepository()..friends = [_alex];
      final controller = _controller(repository);
      await controller.load('token-1');

      final first = controller.removeFriend('token-1', 'u1');
      expect(controller.isFriendBusy('u1'), isTrue);
      final second = controller.removeFriend('token-1', 'u1');
      await Future.wait([first, second]);

      // The point of the guard: the *request* was sent once. Asserting only
      // on `isFriendBusy` proves nothing — a second, unguarded call would
      // re-add and re-remove the same id from the Set and leave both
      // assertions true.
      expect(repository.removeFriendCalls, 1);
      expect(controller.isFriendBusy('u1'), isFalse);
    });
  });

  group('FriendsController.createInvite', () {
    test(
      'stores the plaintext token and re-fetches the invite list (the '
      'create response has no id)',
      () async {
        final repository = _FakeSocialRepository()
          ..createInviteResult = (
            token: 'secret-token',
            expiresAt: '2026-09-05T00:00:00Z',
          )
          ..invites = [];
        final controller = _controller(repository);
        await controller.load('token-1');

        // The repository only returns the new invite once the list is
        // re-fetched, mirroring the real API's no-id create response.
        repository.invites = [_outstandingInvite];
        await controller.createInvite('token-1');

        expect(controller.newInviteToken, 'secret-token');
        expect(controller.newInviteExpiresAt, '2026-09-05T00:00:00Z');
        expect(controller.invites, [_outstandingInvite]);
      },
    );

    test(
      'a failed list refresh after a successful create keeps the page loaded '
      'and the one-time link intact',
      () async {
        final repository = _FakeSocialRepository()
          ..createInviteResult = (
            token: 'secret-token',
            expiresAt: '2026-09-05T00:00:00Z',
          );
        final controller = _controller(repository);
        await controller.load('token-1');

        // The invite is minted, then the follow-up re-fetch fails. The
        // plaintext token exists only in that create response, so blanking
        // the page to the error state would destroy it for good.
        repository.listFriendsError = const SocialFetchFailure();
        await controller.createInvite('token-1');

        expect(controller.status, FriendsStatus.loaded);
        expect(controller.newInviteToken, 'secret-token');
        expect(
          controller.mutationError,
          FriendsMutationError.createInviteRefreshFailed,
        );
      },
    );

    test(
      'a 401 during the post-create refresh keeps the re-auth requirement '
      'instead of presenting a healthy page on a dead session',
      () async {
        final repository = _FakeSocialRepository();
        final controller = _controller(repository);
        await controller.load('token-1');

        repository.listInvitesError = const SocialReauthenticationRequired();
        await controller.createInvite('token-1');

        // A 401 is not a refresh hiccup: forcing `loaded` here would leave a
        // stale, healthy-looking list on a session whose every next action
        // fails, with the re-authenticate exit hidden.
        expect(controller.status, FriendsStatus.needsReauth);
      },
    );

    test('a failure surfaces its own message and shows no link', () async {
      final repository = _FakeSocialRepository()
        ..createInviteError = const SocialFetchFailure();
      final controller = _controller(repository);
      await controller.load('token-1');

      await controller.createInvite('token-1');

      expect(controller.newInviteToken, isNull);
      expect(controller.mutationError, FriendsMutationError.createInviteFailed);
    });
  });

  group('FriendsController.revokeInvite', () {
    test('revoking removes the invite from the list', () async {
      final repository = _FakeSocialRepository()..invites = [_outstandingInvite];
      final controller = _controller(repository);
      await controller.load('token-1');

      await controller.revokeInvite('token-1', 'inv-1');

      expect(controller.invites, isEmpty);
      expect(repository.lastRevokedInviteId, 'inv-1');
    });

    test('a failure surfaces its own message', () async {
      final repository = _FakeSocialRepository()
        ..invites = [_outstandingInvite]
        ..revokeInviteError = const SocialFetchFailure();
      final controller = _controller(repository);
      await controller.load('token-1');

      await controller.revokeInvite('token-1', 'inv-1');

      expect(controller.invites, [_outstandingInvite]);
      expect(controller.mutationError, FriendsMutationError.revokeInviteFailed);
    });

    test(
      'a 404 (the invite is already gone) surfaces its own message distinct '
      'from the generic failure, and refreshes the stale list',
      () async {
        final repository = _FakeSocialRepository()..invites = [_outstandingInvite];
        final controller = _controller(repository);
        await controller.load('token-1');

        // Server truth: the invite is gone, so the listed row is stale.
        repository.revokeInviteError = const SocialNotFound();
        repository.invites = [];
        await controller.revokeInvite('token-1', 'inv-1');

        expect(controller.mutationError, FriendsMutationError.revokeNotFound);
        expect(controller.invites, isEmpty);
        expect(controller.status, FriendsStatus.loaded);
      },
    );

    test(
      'revoking the invite the on-screen link belongs to clears the link',
      () async {
        final repository = _FakeSocialRepository();
        final controller = _controller(repository);
        await controller.load('token-1');

        // The create response carries no id; the refresh is what reveals it.
        repository.invites = [_outstandingInvite];
        await controller.createInvite('token-1');
        expect(controller.newInviteToken, 'plaintext-token');
        expect(controller.newInviteId, 'inv-1');

        await controller.revokeInvite('token-1', 'inv-1');

        // The link is dead the moment the invite is — keeping it on screen
        // (with a live Copy button and a "copy it now" warning) would have
        // the user share a link that only ever fails for the recipient.
        expect(controller.newInviteToken, isNull);
        expect(controller.newInviteExpiresAt, isNull);
      },
    );

    test(
      'revoking a different invite leaves the on-screen link alone',
      () async {
        final repository = _FakeSocialRepository()
          ..invites = const [
            FriendInvite(
              id: 'inv-old',
              expiresAt: '2026-09-01T00:00:00Z',
              createdAt: '2026-08-01T00:00:00Z',
            ),
          ];
        final controller = _controller(repository);
        await controller.load('token-1');

        repository.invites = [...repository.invites, _outstandingInvite];
        await controller.createInvite('token-1');
        expect(controller.newInviteId, 'inv-1');

        await controller.revokeInvite('token-1', 'inv-old');

        expect(controller.newInviteToken, 'plaintext-token');
      },
    );

    test('a second call while one is in flight is ignored (busy guard)', () async {
      final repository = _FakeSocialRepository()..invites = [_outstandingInvite];
      final controller = _controller(repository);
      await controller.load('token-1');

      final first = controller.revokeInvite('token-1', 'inv-1');
      expect(controller.isInviteBusy('inv-1'), isTrue);
      final second = controller.revokeInvite('token-1', 'inv-1');
      await Future.wait([first, second]);

      expect(repository.revokeInviteCalls, 1);
      expect(controller.isInviteBusy('inv-1'), isFalse);
    });
  });

  // The page can be left while the initial load is still in flight, at which
  // point this controller is disposed before the response lands. Without the
  // dispose guard the follow-up notify throws "A FriendsController was used
  // after being disposed" — an unhandled async error, not a test failure, so
  // nothing else in the suite would have gone red. `InviteController` had the
  // same hole and the same guard.
  test('notifying after dispose does not throw', () async {
    final repository = _FakeSocialRepository()..gate = Completer<void>();
    final controller = _controller(repository);

    final loading = controller.load('token-1');
    controller.dispose();
    repository.gate!.complete();

    await expectLater(loading, completes);
  });
}