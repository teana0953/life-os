import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/split/domain/settlement.dart';
import 'package:life_os/contexts/split/domain/split_exceptions.dart';

Map<String, dynamic> _settlementJson() => {
  'id': 's1',
  'group_id': null,
  'from_user_id': 'u1',
  'from_display_name': 'Alex',
  'to_user_id': 'u2',
  'to_display_name': 'Bo',
  'amount': 450,
  'currency': 'TWD',
  'day': '2026-08-02',
  'note': 'lunch',
  'created_by_user_id': 'u1',
  'created_at': '2026-08-02T00:00:00.000Z',
  'updated_at': '2026-08-02T00:00:00.000Z',
};

void main() {
  group('Settlement.fromJson', () {
    test('parses a valid payload, names given by the server', () {
      final settlement = Settlement.fromJson(_settlementJson());

      expect(settlement.id, 's1');
      expect(settlement.groupId, isNull);
      expect(settlement.fromUserId, 'u1');
      expect(settlement.fromDisplayName, 'Alex');
      expect(settlement.toUserId, 'u2');
      expect(settlement.toDisplayName, 'Bo');
      expect(settlement.amount, 450);
      expect(settlement.currency, 'TWD');
      expect(settlement.day, '2026-08-02');
      expect(settlement.note, 'lunch');
      expect(settlement.createdByUserId, 'u1');
    });

    test('tolerates a missing note and display names', () {
      final json = _settlementJson()
        ..['note'] = null
        ..['from_display_name'] = null
        ..['to_display_name'] = null;
      final settlement = Settlement.fromJson(json);

      expect(settlement.note, isNull);
      expect(settlement.fromDisplayName, isNull);
      expect(settlement.toDisplayName, isNull);
    });

    test('tolerates a non-null group_id', () {
      final json = _settlementJson()..['group_id'] = 'g1';
      final settlement = Settlement.fromJson(json);

      expect(settlement.groupId, 'g1');
    });

    test('throws SplitFetchFailure for a missing required field', () {
      final json = _settlementJson()..remove('from_user_id');

      expect(() => Settlement.fromJson(json), throwsA(isA<SplitFetchFailure>()));
    });

    test('throws SplitFetchFailure for a wrong-typed required field', () {
      final json = _settlementJson()..['amount'] = 'oops';

      expect(() => Settlement.fromJson(json), throwsA(isA<SplitFetchFailure>()));
    });
  });
}
