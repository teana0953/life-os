import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/split/domain/split_exceptions.dart';
import 'package:life_os/contexts/split/domain/split_group.dart';

void main() {
  group('SplitGroup.fromJson', () {
    test('parses a group with embedded members (GET /api/split/groups shape)', () {
      final group = SplitGroup.fromJson({
        'id': 'g1',
        'name': 'Trip',
        'created_by_user_id': 'u1',
        'archived_at': null,
        'members': [
          {'group_id': 'g1', 'user_id': 'u1', 'display_name': 'Alex', 'joined_at': '2026-08-01T00:00:00.000Z'},
        ],
      });

      expect(group.id, 'g1');
      expect(group.members!.single.displayName, 'Alex');
    });

    test('parses a group with no members key (POST /api/split/groups shape)', () {
      final group = SplitGroup.fromJson({
        'id': 'g1',
        'name': 'Trip',
        'created_by_user_id': 'u1',
        'archived_at': null,
      });

      expect(group.members, isNull);
    });

    test('parses an archived group', () {
      final group = SplitGroup.fromJson({
        'id': 'g1',
        'name': 'Trip',
        'created_by_user_id': 'u1',
        'archived_at': '2026-08-02T00:00:00.000Z',
      });

      expect(group.archivedAt, '2026-08-02T00:00:00.000Z');
    });

    test('throws SplitFetchFailure for a missing required field', () {
      expect(
        () => SplitGroup.fromJson({'name': 'Trip', 'created_by_user_id': 'u1', 'archived_at': null}),
        throwsA(isA<SplitFetchFailure>()),
      );
    });

    test('throws SplitFetchFailure for a wrong-typed required field', () {
      expect(
        () => SplitGroup.fromJson({
          'id': 1,
          'name': 'Trip',
          'created_by_user_id': 'u1',
          'archived_at': null,
        }),
        throwsA(isA<SplitFetchFailure>()),
      );
    });
  });
}
