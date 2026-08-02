import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/social/application/invite_use_cases.dart';
import 'package:life_os/contexts/social/domain/friend.dart';
import 'package:life_os/contexts/social/domain/friend_invite.dart';
import 'package:life_os/contexts/social/domain/invite_preview.dart';
import 'package:life_os/contexts/social/domain/social_exceptions.dart';
import 'package:life_os/contexts/social/domain/social_repository.dart';
import 'package:life_os/contexts/social/presentation/invite_controller.dart';

class _FakeSocialRepository implements SocialRepository {
  InvitePreview previewResult = const InvitePreview(
    inviterDisplayName: 'Alex',
    alreadyFriends: false,
  );
  AcceptInviteResult acceptResult = const AcceptInviteResult(
    friend: Friend(userId: 'u1', displayName: 'Alex'),
    alreadyFriends: false,
  );
  Object? previewError;
  Object? acceptError;
  String? lastPreviewToken;
  String? lastAcceptToken;
  int acceptInviteCalls = 0;

  @override
  Future<InvitePreview> previewInvite(String idToken, String token) async {
    lastPreviewToken = token;
    final failure = previewError;
    if (failure != null) throw failure;
    return previewResult;
  }

  @override
  Future<AcceptInviteResult> acceptInvite(String idToken, String token) async {
    acceptInviteCalls += 1;
    lastAcceptToken = token;
    final failure = acceptError;
    if (failure != null) throw failure;
    return acceptResult;
  }

  @override
  Future<List<Friend>> listFriends(String idToken) => throw UnimplementedError();

  @override
  Future<void> removeFriend(String idToken, String friendUserId) =>
      throw UnimplementedError();

  @override
  Future<({String token, String expiresAt})> createInvite(String idToken) =>
      throw UnimplementedError();

  @override
  Future<List<FriendInvite>> listInvites(String idToken) => throw UnimplementedError();

  @override
  Future<void> revokeInvite(String idToken, String id) => throw UnimplementedError();
}

InviteController _controller(_FakeSocialRepository repository) =>
    InviteController(PreviewInvite(repository), AcceptInvite(repository));

void main() {
  group('InviteController.preview', () {
    test('a blank/missing token goes to invalidLink without a request', () async {
      final repository = _FakeSocialRepository();
      final controller = _controller(repository);

      await controller.preview('token-1', null);
      expect(controller.status, InviteStatus.invalidLink);
      expect(repository.lastPreviewToken, isNull);

      await controller.preview('token-1', '   ');
      expect(controller.status, InviteStatus.invalidLink);
      expect(repository.lastPreviewToken, isNull);
    });

    test('a successful preview shows the inviter and does not accept', () async {
      final repository = _FakeSocialRepository();
      final controller = _controller(repository);

      await controller.preview('token-1', 'abc');

      expect(controller.status, InviteStatus.ready);
      expect(controller.inviterDisplayName, 'Alex');
      expect(repository.lastAcceptToken, isNull);
    });

    test('already_friends on preview shows the already-friends state', () async {
      final repository = _FakeSocialRepository()
        ..previewResult = const InvitePreview(
          inviterDisplayName: 'Alex',
          alreadyFriends: true,
        );
      final controller = _controller(repository);

      await controller.preview('token-1', 'abc');

      expect(controller.status, InviteStatus.alreadyFriends);
    });

    for (final entry in {
      const InviteNotFound(): InviteStatus.invalidLink,
      const InviteExpired(): InviteStatus.expired,
      const InviteAlreadyUsed(): InviteStatus.alreadyUsed,
      const InviteRevoked(): InviteStatus.revoked,
      const SocialReauthenticationRequired(): InviteStatus.needsReauth,
    }.entries) {
      test('preview maps ${entry.key.runtimeType} to ${entry.value}', () async {
        final repository = _FakeSocialRepository()..previewError = entry.key;
        final controller = _controller(repository);

        await controller.preview('token-1', 'abc');

        expect(controller.status, entry.value);
      });
    }
  });

  group('InviteController.accept', () {
    test('accepting succeeds after a successful preview', () async {
      final repository = _FakeSocialRepository();
      final controller = _controller(repository);
      await controller.preview('token-1', 'abc');

      await controller.accept('token-1');

      expect(controller.status, InviteStatus.accepted);
      expect(repository.lastAcceptToken, 'abc');
    });

    test('already_friends on accept shows the already-friends state', () async {
      final repository = _FakeSocialRepository()
        ..acceptResult = const AcceptInviteResult(
          friend: Friend(userId: 'u1', displayName: 'Alex'),
          alreadyFriends: true,
        );
      final controller = _controller(repository);
      await controller.preview('token-1', 'abc');

      await controller.accept('token-1');

      expect(controller.status, InviteStatus.alreadyFriends);
    });

    test(
      "the user's own invite previews fine but only errors on accept "
      '(design D10)',
      () async {
        final repository = _FakeSocialRepository()
          ..acceptError = const CannotFriendSelf();
        final controller = _controller(repository);

        await controller.preview('token-1', 'abc');
        expect(controller.status, InviteStatus.ready);

        await controller.accept('token-1');
        expect(controller.status, InviteStatus.ownInvite);
      },
    );

    test('the accept action is disabled (a no-op) while already in flight', () async {
      final repository = _FakeSocialRepository();
      final controller = _controller(repository);
      await controller.preview('token-1', 'abc');

      final first = controller.accept('token-1');
      expect(controller.accepting, isTrue);
      final second = controller.accept('token-1');
      await Future.wait([first, second]);

      // The invite is consumed once. `lastAcceptToken` cannot show this —
      // it is the same value both times — and `accepting`/`status` end up
      // identical with or without the guard, so count the calls.
      expect(repository.acceptInviteCalls, 1);
      expect(controller.accepting, isFalse);
      expect(controller.status, InviteStatus.accepted);
    });

    test('accepting without a prior successful preview is a no-op', () async {
      final repository = _FakeSocialRepository();
      final controller = _controller(repository);

      await controller.accept('token-1');

      expect(repository.lastAcceptToken, isNull);
      expect(controller.status, InviteStatus.previewing);
    });
  });

  test(
    'a second, different invite link previewed on the same controller shows '
    'the second inviter (mirrors what a fresh ValueKey(token) State does in '
    'production, design D13)',
    () async {
      final repository = _FakeSocialRepository()
        ..previewResult = const InvitePreview(
          inviterDisplayName: 'Alex',
          alreadyFriends: false,
        );
      final controller = _controller(repository);
      await controller.preview('token-1', 'token-a');
      expect(controller.inviterDisplayName, 'Alex');

      repository.previewResult = const InvitePreview(
        inviterDisplayName: 'Jamie',
        alreadyFriends: false,
      );
      await controller.preview('token-1', 'token-b');

      expect(controller.inviterDisplayName, 'Jamie');
      await controller.accept('token-1');
      expect(repository.lastAcceptToken, 'token-b');
    },
  );
}
