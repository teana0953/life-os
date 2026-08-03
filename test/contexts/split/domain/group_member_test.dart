import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/split/domain/group_member.dart';
import 'package:life_os/contexts/split/domain/split_exceptions.dart';

void main() {
  group('GroupMember.fromJson', () {
    test('parses a valid payload', () {
      final member = GroupMember.fromJson({
        'group_id': 'g1',
        'user_id': 'u1',
        'display_name': 'Alex',
        'joined_at': '2026-08-01T00:00:00.000Z',
      });

      expect(member.groupId, 'g1');
      expect(member.userId, 'u1');
      expect(member.displayName, 'Alex');
      expect(member.joinedAt, '2026-08-01T00:00:00.000Z');
    });

    test('tolerates a missing display_name (server has no name to give)', () {
      final member = GroupMember.fromJson({
        'group_id': 'g1',
        'user_id': 'u1',
        'display_name': null,
        'joined_at': '2026-08-01T00:00:00.000Z',
      });

      expect(member.displayName, isNull);
    });

    test('throws SplitFetchFailure for a missing required field', () {
      expect(
        () => GroupMember.fromJson({'group_id': 'g1', 'display_name': 'Alex'}),
        throwsA(isA<SplitFetchFailure>()),
      );
    });

    test('throws SplitFetchFailure for a wrong-typed required field', () {
      expect(
        () => GroupMember.fromJson({
          'group_id': 'g1',
          'user_id': 1,
          'display_name': 'Alex',
          'joined_at': '2026-08-01T00:00:00.000Z',
        }),
        throwsA(isA<SplitFetchFailure>()),
      );
    });
  });
}
