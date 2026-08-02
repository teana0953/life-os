import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/social/domain/friend_invite.dart';
import 'package:life_os/contexts/social/domain/social_exceptions.dart';

void main() {
  group('FriendInvite.fromJson', () {
    test('parses a valid payload', () {
      final invite = FriendInvite.fromJson({
        'id': 'i1',
        'expires_at': '2026-08-09T00:00:00.000Z',
        'created_at': '2026-08-02T00:00:00.000Z',
      });

      expect(invite.id, 'i1');
      expect(invite.expiresAt, '2026-08-09T00:00:00.000Z');
      expect(invite.createdAt, '2026-08-02T00:00:00.000Z');
    });

    test('throws SocialFetchFailure for a missing field', () {
      expect(
        () => FriendInvite.fromJson({'id': 'i1', 'expires_at': '2026-08-09T00:00:00.000Z'}),
        throwsA(isA<SocialFetchFailure>()),
      );
    });

    test('throws SocialFetchFailure for a wrong-typed field', () {
      expect(
        () => FriendInvite.fromJson({
          'id': 1,
          'expires_at': '2026-08-09T00:00:00.000Z',
          'created_at': '2026-08-02T00:00:00.000Z',
        }),
        throwsA(isA<SocialFetchFailure>()),
      );
    });
  });
}
