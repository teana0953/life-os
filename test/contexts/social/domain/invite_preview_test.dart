import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/social/domain/invite_preview.dart';
import 'package:life_os/contexts/social/domain/social_exceptions.dart';

void main() {
  group('InvitePreview.fromJson', () {
    test('parses a valid payload', () {
      final preview = InvitePreview.fromJson({
        'inviter_display_name': 'Alex',
        'already_friends': false,
      });

      expect(preview.inviterDisplayName, 'Alex');
      expect(preview.alreadyFriends, isFalse);
    });

    test('throws SocialFetchFailure for a missing field', () {
      expect(
        () => InvitePreview.fromJson({'inviter_display_name': 'Alex'}),
        throwsA(isA<SocialFetchFailure>()),
      );
    });

    test('throws SocialFetchFailure for a wrong-typed field', () {
      expect(
        () => InvitePreview.fromJson({
          'inviter_display_name': 'Alex',
          'already_friends': 'nope',
        }),
        throwsA(isA<SocialFetchFailure>()),
      );
    });
  });

  group('AcceptInviteResult.fromJson', () {
    test('parses a valid payload', () {
      final result = AcceptInviteResult.fromJson({
        'friend': {'user_id': 'u1', 'display_name': 'Alex'},
        'already_friends': false,
      });

      expect(result.friend.userId, 'u1');
      expect(result.friend.displayName, 'Alex');
      expect(result.alreadyFriends, isFalse);
    });

    test('throws SocialFetchFailure for a missing field', () {
      expect(
        () => AcceptInviteResult.fromJson({
          'friend': {'user_id': 'u1', 'display_name': 'Alex'},
        }),
        throwsA(isA<SocialFetchFailure>()),
      );
    });

    test('throws SocialFetchFailure when the nested friend is malformed', () {
      expect(
        () => AcceptInviteResult.fromJson({
          'friend': {'user_id': 'u1'},
          'already_friends': false,
        }),
        throwsA(isA<SocialFetchFailure>()),
      );
    });
  });
}
