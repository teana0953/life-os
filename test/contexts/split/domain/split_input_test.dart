import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/split/domain/split_input.dart';

void main() {
  group('EqualSplitInput.toJson', () {
    test('serializes mode and participant_user_ids', () {
      final json = const EqualSplitInput(['u1', 'u2']).toJson();

      expect(json, {
        'mode': 'equal',
        'participant_user_ids': ['u1', 'u2'],
      });
    });
  });

  group('ExactSplitInput.toJson', () {
    test('serializes mode and shares', () {
      final json = const ExactSplitInput([
        ExactShareInput(userId: 'u1', amount: 300),
        ExactShareInput(userId: 'u2', amount: 700),
      ]).toJson();

      expect(json, {
        'mode': 'exact',
        'shares': [
          {'user_id': 'u1', 'amount': 300},
          {'user_id': 'u2', 'amount': 700},
        ],
      });
    });
  });
}
