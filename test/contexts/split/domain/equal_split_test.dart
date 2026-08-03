import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/split/domain/equal_split.dart';

void main() {
  group('equalSplitAmounts', () {
    // Pinned to the backend's own `equalSplit` cases (design.md D3/task
    // 6.4b) — any other remainder rule previews different numbers than what
    // the server actually stores.
    test('100 across 3 participants: 34/33/33, remainder to the lexically first', () {
      final result = equalSplitAmounts(100, ['b-user', 'a-user', 'c-user']);
      expect(result, {'b-user': 33, 'a-user': 34, 'c-user': 33});
    });

    test('1 across 3 participants: 1/0/0', () {
      final result = equalSplitAmounts(1, ['zzz', 'aaa', 'mmm']);
      expect(result, {'zzz': 0, 'aaa': 1, 'mmm': 0});
    });

    test('7 across 10 participants: first 7 (lexically) get 1, rest 0', () {
      final ids = List.generate(10, (i) => 'user-$i');
      final result = equalSplitAmounts(7, ids);
      final withExtra = result.entries.where((e) => e.value == 1).map((e) => e.key).toSet();
      expect(withExtra.length, 7);
      expect(result.values.reduce((a, b) => a + b), 7);
    });

    test('sorts case-insensitively', () {
      final result = equalSplitAmounts(1, ['Bob', 'alice']);
      // lowercase: 'alice' < 'bob', so alice gets the remainder despite the
      // capitalisation of the raw ids.
      expect(result, {'Bob': 0, 'alice': 1});
    });

    test('divides evenly with no remainder', () {
      final result = equalSplitAmounts(90, ['a', 'b', 'c']);
      expect(result, {'a': 30, 'b': 30, 'c': 30});
    });

    test('empty participant list returns an empty map', () {
      expect(equalSplitAmounts(100, []), <String, int>{});
    });
  });
}
