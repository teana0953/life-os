import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/split/domain/split_exceptions.dart';
import 'package:life_os/contexts/split/domain/split_share.dart';

void main() {
  group('SplitShare.fromJson', () {
    test('parses a valid payload', () {
      final share = SplitShare.fromJson({'user_id': 'u1', 'display_name': 'Alex', 'amount': 500});

      expect(share.userId, 'u1');
      expect(share.displayName, 'Alex');
      expect(share.amount, 500);
    });

    test('tolerates a missing display_name (co-participant not resolvable client-side)', () {
      final share = SplitShare.fromJson({'user_id': 'u1', 'display_name': null, 'amount': 500});

      expect(share.displayName, isNull);
    });

    test('throws SplitFetchFailure for a missing required field', () {
      expect(
        () => SplitShare.fromJson({'user_id': 'u1', 'display_name': 'Alex'}),
        throwsA(isA<SplitFetchFailure>()),
      );
    });

    test('throws SplitFetchFailure for a wrong-typed required field', () {
      expect(
        () => SplitShare.fromJson({'user_id': 'u1', 'display_name': 'Alex', 'amount': 'oops'}),
        throwsA(isA<SplitFetchFailure>()),
      );
    });
  });
}
