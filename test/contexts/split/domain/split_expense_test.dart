import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/split/domain/split_exceptions.dart';
import 'package:life_os/contexts/split/domain/split_expense.dart';

Map<String, dynamic> _validJson({String? payerDisplayName = 'Alex'}) => {
  'id': 'e1',
  'group_id': 'g1',
  'payer_user_id': 'u1',
  'payer_display_name': payerDisplayName,
  'created_by_user_id': 'u1',
  'amount': 900,
  'currency': 'TWD',
  'description': 'Dinner',
  'day': '2026-08-02',
  'split_mode': 'equal',
  'shares': [
    {'user_id': 'u1', 'display_name': 'Alex', 'amount': 450},
    {'user_id': 'u2', 'display_name': 'Bo', 'amount': 450},
  ],
  'created_at': '2026-08-02T00:00:00.000Z',
  'updated_at': '2026-08-02T00:00:00.000Z',
};

void main() {
  group('SplitExpense.fromJson', () {
    test('parses a valid payload, keeping day as a raw calendar-date string', () {
      final expense = SplitExpense.fromJson(_validJson());

      expect(expense.id, 'e1');
      expect(expense.groupId, 'g1');
      expect(expense.payerDisplayName, 'Alex');
      expect(expense.day, '2026-08-02');
      expect(expense.shares, hasLength(2));
    });

    test('parses a group-less expense (group_id null)', () {
      final json = _validJson()..['group_id'] = null;
      final expense = SplitExpense.fromJson(json);

      expect(expense.groupId, isNull);
    });

    test('tolerates a missing payer_display_name (payer holds no share)', () {
      final json = _validJson(payerDisplayName: null);
      final expense = SplitExpense.fromJson(json);

      expect(expense.payerDisplayName, isNull);
    });

    test('throws SplitFetchFailure for a missing required field', () {
      final json = _validJson()..remove('amount');
      expect(() => SplitExpense.fromJson(json), throwsA(isA<SplitFetchFailure>()));
    });

    test('throws SplitFetchFailure for a wrong-typed required field', () {
      final json = _validJson()..['amount'] = 'oops';
      expect(() => SplitExpense.fromJson(json), throwsA(isA<SplitFetchFailure>()));
    });
  });
}
