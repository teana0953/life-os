import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/split/application/balance_use_cases.dart';
import 'package:life_os/contexts/split/domain/balance.dart';
import 'package:life_os/contexts/split/domain/split_exceptions.dart';

import '../support/fake_split_repository.dart';

void main() {
  test('GetBalances delegates to the repository', () async {
    final repository = FakeSplitRepository()
      ..balancesToReturn = const [
        Balance(userId: 'u2', displayName: 'Bo', balances: [CurrencyBalance(currency: 'TWD', amount: 500)]),
      ];

    final balances = await GetBalances(repository)('token-1');

    expect(repository.gotIdToken, 'token-1');
    expect(balances.single.displayName, 'Bo');
  });

  test('GetBalances lets the repository error propagate', () async {
    final repository = FakeSplitRepository()..failNext = const SplitReauthenticationRequired();

    expect(() => GetBalances(repository)('token-1'), throwsA(isA<SplitReauthenticationRequired>()));
  });
}
