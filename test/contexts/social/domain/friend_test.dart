import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/social/domain/friend.dart';
import 'package:life_os/contexts/social/domain/social_exceptions.dart';

void main() {
  group('Friend.fromJson', () {
    test('parses a valid payload', () {
      final friend = Friend.fromJson({
        'user_id': 'u1',
        'display_name': 'Alex',
      });

      expect(friend.userId, 'u1');
      expect(friend.displayName, 'Alex');
    });

    test('throws SocialFetchFailure for a missing field', () {
      expect(
        () => Friend.fromJson({'user_id': 'u1'}),
        throwsA(isA<SocialFetchFailure>()),
      );
    });

    test('throws SocialFetchFailure for a wrong-typed field', () {
      expect(
        () => Friend.fromJson({'user_id': 1, 'display_name': 'Alex'}),
        throwsA(isA<SocialFetchFailure>()),
      );
    });
  });
}
