import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/contexts/social/domain/social_exceptions.dart';
import 'package:life_os/contexts/social/infrastructure/http_social_repository.dart';

void main() {
  group('HttpSocialRepository', () {
    test('listFriends GETs {baseUrl}/api/friends with a bearer token', () async {
      Uri? capturedUri;
      String? capturedAuthHeader;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedAuthHeader = request.headers['Authorization'];
        return http.Response(
          jsonEncode({
            'friends': [
              {'user_id': 'u1', 'display_name': 'Alex'},
            ],
          }),
          200,
        );
      });
      final repository = HttpSocialRepository(baseUrl: 'https://example.test', client: client);

      final friends = await repository.listFriends('token-123');

      expect(capturedUri, Uri.parse('https://example.test/api/friends'));
      expect(capturedAuthHeader, 'Bearer token-123');
      expect(friends.single.displayName, 'Alex');
    });

    test('removeFriend DELETEs to /api/friends/:friendUserId', () async {
      Uri? capturedUri;
      String? capturedMethod;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        return http.Response('{"deleted":true}', 200);
      });
      final repository = HttpSocialRepository(baseUrl: 'https://example.test', client: client);

      await repository.removeFriend('token-123', 'friend-1');

      expect(capturedUri, Uri.parse('https://example.test/api/friends/friend-1'));
      expect(capturedMethod, 'DELETE');
    });

    test('createInvite POSTs to /api/friends/invites', () async {
      Uri? capturedUri;
      String? capturedMethod;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        return http.Response(
          jsonEncode({'token': 'plaintext', 'expires_at': '2026-08-09T00:00:00.000Z'}),
          200,
        );
      });
      final repository = HttpSocialRepository(baseUrl: 'https://example.test', client: client);

      final result = await repository.createInvite('token-123');

      expect(capturedUri, Uri.parse('https://example.test/api/friends/invites'));
      expect(capturedMethod, 'POST');
      expect(result.token, 'plaintext');
      expect(result.expiresAt, '2026-08-09T00:00:00.000Z');
    });

    test('listInvites GETs /api/friends/invites', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            'invites': [
              {
                'id': 'i1',
                'expires_at': '2026-08-09T00:00:00.000Z',
                'created_at': '2026-08-02T00:00:00.000Z',
              },
            ],
          }),
          200,
        );
      });
      final repository = HttpSocialRepository(baseUrl: 'https://example.test', client: client);

      final invites = await repository.listInvites('token-123');

      expect(capturedUri, Uri.parse('https://example.test/api/friends/invites'));
      expect(invites.single.id, 'i1');
    });

    test('revokeInvite DELETEs to /api/friends/invites/:id', () async {
      Uri? capturedUri;
      String? capturedMethod;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        return http.Response('{"revoked":true}', 200);
      });
      final repository = HttpSocialRepository(baseUrl: 'https://example.test', client: client);

      await repository.revokeInvite('token-123', 'invite-1');

      expect(capturedUri, Uri.parse('https://example.test/api/friends/invites/invite-1'));
      expect(capturedMethod, 'DELETE');
    });

    test('previewInvite POSTs the token in the body, and the URL carries no token', () async {
      Uri? capturedUri;
      String? capturedMethod;
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'inviter_display_name': 'Alex', 'already_friends': false}),
          200,
        );
      });
      final repository = HttpSocialRepository(baseUrl: 'https://example.test', client: client);

      final preview = await repository.previewInvite('token-123', 'invite-token-abc');

      expect(capturedUri, Uri.parse('https://example.test/api/friends/invites/preview'));
      expect(capturedMethod, 'POST');
      expect(capturedUri!.toString(), isNot(contains('invite-token-abc')));
      expect(capturedBody!['token'], 'invite-token-abc');
      expect(preview.inviterDisplayName, 'Alex');
      expect(preview.alreadyFriends, isFalse);
    });

    test('acceptInvite POSTs the token in the body, and the URL carries no token', () async {
      Uri? capturedUri;
      String? capturedMethod;
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'friend': {'user_id': 'u1', 'display_name': 'Alex'},
            'already_friends': false,
          }),
          200,
        );
      });
      final repository = HttpSocialRepository(baseUrl: 'https://example.test', client: client);

      final result = await repository.acceptInvite('token-123', 'invite-token-abc');

      expect(capturedUri, Uri.parse('https://example.test/api/friends/invites/accept'));
      expect(capturedMethod, 'POST');
      expect(capturedUri!.toString(), isNot(contains('invite-token-abc')));
      expect(capturedBody!['token'], 'invite-token-abc');
      expect(result.friend.displayName, 'Alex');
      expect(result.alreadyFriends, isFalse);
    });

    test('throws SocialReauthenticationRequired on 401', () async {
      final client = MockClient((request) async => http.Response('', 401));
      final repository = HttpSocialRepository(baseUrl: 'https://example.test', client: client);

      expect(
        () => repository.listFriends('token-123'),
        throwsA(isA<SocialReauthenticationRequired>()),
      );
    });

    test('throws SocialFetchFailure (not a crash) on a network error', () async {
      final client = MockClient((request) async => throw Exception('boom'));
      final repository = HttpSocialRepository(baseUrl: 'https://example.test', client: client);

      expect(
        () => repository.listFriends('token-123'),
        throwsA(isA<SocialFetchFailure>()),
      );
    });

    group('remove/revoke 404 -> SocialNotFound (never InviteNotFound)', () {
      test('removeFriend 404 throws SocialNotFound', () async {
        final client = MockClient(
          (request) async => http.Response(jsonEncode({'error': 'not_found'}), 404),
        );
        final repository = HttpSocialRepository(baseUrl: 'https://example.test', client: client);

        expect(
          () => repository.removeFriend('token-123', 'friend-1'),
          throwsA(isA<SocialNotFound>()),
        );
      });

      test('revokeInvite 404 throws SocialNotFound, not InviteNotFound', () async {
        final client = MockClient(
          (request) async => http.Response(jsonEncode({'error': 'not_found'}), 404),
        );
        final repository = HttpSocialRepository(baseUrl: 'https://example.test', client: client);

        expect(
          () => repository.revokeInvite('token-123', 'invite-1'),
          throwsA(isA<SocialNotFound>()),
        );
      });

      test('listFriends 500 throws SocialFetchFailure', () async {
        final client = MockClient(
          (request) async => http.Response(jsonEncode({'error': 'internal'}), 500),
        );
        final repository = HttpSocialRepository(baseUrl: 'https://example.test', client: client);

        expect(
          () => repository.listFriends('token-123'),
          throwsA(isA<SocialFetchFailure>()),
        );
      });
    });

    group('preview/accept 404 -> InviteNotFound', () {
      test('previewInvite 404 throws InviteNotFound', () async {
        final client = MockClient(
          (request) async => http.Response(jsonEncode({'error': 'not_found'}), 404),
        );
        final repository = HttpSocialRepository(baseUrl: 'https://example.test', client: client);

        expect(
          () => repository.previewInvite('token-123', 'invite-token'),
          throwsA(isA<InviteNotFound>()),
        );
      });

      test('acceptInvite 404 throws InviteNotFound', () async {
        final client = MockClient(
          (request) async => http.Response(jsonEncode({'error': 'not_found'}), 404),
        );
        final repository = HttpSocialRepository(baseUrl: 'https://example.test', client: client);

        expect(
          () => repository.acceptInvite('token-123', 'invite-token'),
          throwsA(isA<InviteNotFound>()),
        );
      });
    });

    group('preview/accept 400 error codes', () {
      test('invite_expired throws InviteExpired', () async {
        final client = MockClient(
          (request) async => http.Response(jsonEncode({'error': 'invite_expired'}), 400),
        );
        final repository = HttpSocialRepository(baseUrl: 'https://example.test', client: client);

        expect(
          () => repository.previewInvite('token-123', 'invite-token'),
          throwsA(isA<InviteExpired>()),
        );
      });

      test('invite_already_used throws InviteAlreadyUsed', () async {
        final client = MockClient(
          (request) async => http.Response(jsonEncode({'error': 'invite_already_used'}), 400),
        );
        final repository = HttpSocialRepository(baseUrl: 'https://example.test', client: client);

        expect(
          () => repository.acceptInvite('token-123', 'invite-token'),
          throwsA(isA<InviteAlreadyUsed>()),
        );
      });

      test('invite_revoked throws InviteRevoked', () async {
        final client = MockClient(
          (request) async => http.Response(jsonEncode({'error': 'invite_revoked'}), 400),
        );
        final repository = HttpSocialRepository(baseUrl: 'https://example.test', client: client);

        expect(
          () => repository.previewInvite('token-123', 'invite-token'),
          throwsA(isA<InviteRevoked>()),
        );
      });

      test('cannot_friend_self throws CannotFriendSelf (accept only)', () async {
        final client = MockClient(
          (request) async => http.Response(jsonEncode({'error': 'cannot_friend_self'}), 400),
        );
        final repository = HttpSocialRepository(baseUrl: 'https://example.test', client: client);

        expect(
          () => repository.acceptInvite('token-123', 'invite-token'),
          throwsA(isA<CannotFriendSelf>()),
        );
      });

      test('bad_request throws InviteNotFound (invalid link to the user)', () async {
        final client = MockClient(
          (request) async => http.Response(jsonEncode({'error': 'bad_request'}), 400),
        );
        final repository = HttpSocialRepository(baseUrl: 'https://example.test', client: client);

        expect(
          () => repository.previewInvite('token-123', 'invite-token'),
          throwsA(isA<InviteNotFound>()),
        );
      });

      test('internal (500) throws SocialFetchFailure', () async {
        final client = MockClient(
          (request) async => http.Response(jsonEncode({'error': 'internal'}), 500),
        );
        final repository = HttpSocialRepository(baseUrl: 'https://example.test', client: client);

        expect(
          () => repository.acceptInvite('token-123', 'invite-token'),
          throwsA(isA<SocialFetchFailure>()),
        );
      });

      test('unrecognised 400 error code throws SocialFetchFailure', () async {
        final client = MockClient(
          (request) async => http.Response(jsonEncode({'error': 'something_else'}), 400),
        );
        final repository = HttpSocialRepository(baseUrl: 'https://example.test', client: client);

        expect(
          () => repository.previewInvite('token-123', 'invite-token'),
          throwsA(isA<SocialFetchFailure>()),
        );
      });
    });

    group('malformed error bodies never throw a decode error', () {
      test('empty body on a 400 falls back to SocialFetchFailure', () async {
        final client = MockClient((request) async => http.Response('', 400));
        final repository = HttpSocialRepository(baseUrl: 'https://example.test', client: client);

        expect(
          () => repository.previewInvite('token-123', 'invite-token'),
          throwsA(isA<SocialFetchFailure>()),
        );
      });

      test('non-JSON body on a 400 falls back to SocialFetchFailure', () async {
        final client = MockClient(
          (request) async => http.Response('<html>not json</html>', 400),
        );
        final repository = HttpSocialRepository(baseUrl: 'https://example.test', client: client);

        expect(
          () => repository.acceptInvite('token-123', 'invite-token'),
          throwsA(isA<SocialFetchFailure>()),
        );
      });

      test('malformed 200 body throws SocialFetchFailure, not a decode error', () async {
        final client = MockClient((request) async => http.Response('not json', 200));
        final repository = HttpSocialRepository(baseUrl: 'https://example.test', client: client);

        expect(
          () => repository.listFriends('token-123'),
          throwsA(isA<SocialFetchFailure>()),
        );
      });
    });
  });
}
