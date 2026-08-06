import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/contexts/finance/domain/finance_exceptions.dart';
import 'package:life_os/contexts/finance/domain/finance_type.dart';
import 'package:life_os/contexts/finance/infrastructure/http_finance_repository.dart';

void main() {
  group('HttpFinanceRepository', () {
    test('getCategories GETs {baseUrl}/api/finance/categories with a bearer token', () async {
      Uri? capturedUri;
      String? capturedAuthHeader;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedAuthHeader = request.headers['Authorization'];
        return http.Response(
          jsonEncode({
            'categories': [
              {
                'id': 'c1',
                'name': '餐飲',
                'type': 'expense',
                'icon': 'other',
                'sort_order': 0,
                'archived': false,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final repository = HttpFinanceRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final categories = await repository.getCategories('token-123');

      expect(
        capturedUri,
        Uri.parse('https://example.test/api/finance/categories'),
      );
      expect(capturedAuthHeader, 'Bearer token-123');
      expect(categories, hasLength(1));
      expect(categories.single.name, '餐飲');
      expect(categories.single.type, FinanceType.expense);
    });

    test('getTransactions GETs with from/to query params', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            'transactions': [
              {
                'id': 't1',
                'type': 'expense',
                'amount': 120,
                'currency': 'TWD',
                'category_id': 'c1',
                'date': '2026-07-15',
                'note': null,
                'split_expense_id': 'se-1',
              },
              {
                'id': 't2',
                'type': 'expense',
                'amount': 80,
                'currency': 'TWD',
                'category_id': 'c1',
                'date': '2026-07-16',
                'note': null,
                'split_expense_id': null,
              },
            ],
          }),
          200,
        );
      });
      final repository = HttpFinanceRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final transactions = await repository.getTransactions(
        'token-123',
        from: '2026-07-01',
        to: '2026-07-31',
      );

      expect(
        capturedUri,
        Uri.parse(
          'https://example.test/api/finance/transactions?from=2026-07-01&to=2026-07-31',
        ),
      );
      expect(transactions.first.amount, 120);
      // The only place `FinanceTransaction.fromJson` actually runs: every
      // widget-level fixture builds the model directly through its
      // constructor (`FakeFinanceRepository.byMonth`), so "the parser never
      // reads `split_expense_id`" is invisible everywhere else — and it is
      // exactly the mutation that would make every mirrored row look like a
      // row the user recorded themselves. Both values are pinned: reading
      // the wrong key yields null for *both*, which an id-only assertion
      // would catch but a null-only one would not.
      expect(transactions.first.splitExpenseId, 'se-1');
      expect(transactions.last.splitExpenseId, isNull);
    });

    test('getSummary GETs with a month query param', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          jsonEncode({'month': '2026-07', 'totals': [], 'by_category': []}),
          200,
        );
      });
      final repository = HttpFinanceRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final summary = await repository.getSummary('token-123', '2026-07');

      expect(
        capturedUri,
        Uri.parse('https://example.test/api/finance/summary?month=2026-07'),
      );
      expect(summary.month, '2026-07');
    });

    test('addTransaction POSTs the transaction body with Content-Type json', () async {
      Uri? capturedUri;
      String? capturedMethod;
      Map<String, dynamic>? capturedBody;
      String? capturedContentType;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        capturedContentType = request.headers['Content-Type'];
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'id': 't1',
            'type': 'expense',
            'amount': 500,
            'currency': 'TWD',
            'category_id': 'c1',
            'date': '2026-07-15',
            'note': 'lunch',
          }),
          200,
        );
      });
      final repository = HttpFinanceRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final txn = await repository.addTransaction(
        'token-123',
        type: FinanceType.expense,
        amount: 500,
        currency: 'TWD',
        categoryId: 'c1',
        date: '2026-07-15',
        note: 'lunch',
      );

      expect(capturedUri, Uri.parse('https://example.test/api/finance/transactions'));
      expect(capturedMethod, 'POST');
      expect(capturedContentType, contains('application/json'));
      expect(capturedBody, {
        'type': 'expense',
        'amount': 500,
        'currency': 'TWD',
        'category_id': 'c1',
        'date': '2026-07-15',
        'note': 'lunch',
      });
      expect(txn.id, 't1');
    });

    test('updateTransaction PUTs to /transactions/:id', () async {
      Uri? capturedUri;
      String? capturedMethod;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        return http.Response(
          jsonEncode({
            'id': 't1',
            'type': 'income',
            'amount': 600,
            'currency': 'USD',
            'category_id': 'c2',
            'date': '2026-08-01',
            'note': null,
          }),
          200,
        );
      });
      final repository = HttpFinanceRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final txn = await repository.updateTransaction(
        'token-123',
        't1',
        type: FinanceType.income,
        amount: 600,
        currency: 'USD',
        categoryId: 'c2',
        date: '2026-08-01',
      );

      expect(
        capturedUri,
        Uri.parse('https://example.test/api/finance/transactions/t1'),
      );
      expect(capturedMethod, 'PUT');
      expect(txn.currency, 'USD');
    });

    test('deleteTransaction DELETEs to /transactions/:id', () async {
      Uri? capturedUri;
      String? capturedMethod;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        return http.Response(jsonEncode({'deleted': true}), 200);
      });
      final repository = HttpFinanceRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      await repository.deleteTransaction('token-123', 't1');

      expect(
        capturedUri,
        Uri.parse('https://example.test/api/finance/transactions/t1'),
      );
      expect(capturedMethod, 'DELETE');
    });

    test('listBudgets GETs with a month query param', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            'month': '2026-07',
            'budgets': [
              {
                'id': 'b1',
                'category_id': null,
                'amount': 10000,
                'spent': 3500,
                'remaining': 6500,
                'percent': 35,
              },
              {
                'id': 'b2',
                'category_id': 'cat-food',
                'amount': 3000,
                'spent': 2500,
                'remaining': 500,
                'percent': 83,
              },
            ],
          }),
          200,
        );
      });
      final repository = HttpFinanceRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final budgets = await repository.listBudgets('token-123', '2026-07');

      expect(
        capturedUri,
        Uri.parse('https://example.test/api/finance/budgets?month=2026-07'),
      );
      expect(budgets, hasLength(2));
      expect(budgets[0].categoryId, isNull);
      expect(budgets[0].percent, 35);
      expect(budgets[1].categoryId, 'cat-food');
      expect(budgets[1].percent, 83);
    });

    test('upsertBudget PUTs the budget body with Content-Type json', () async {
      Uri? capturedUri;
      String? capturedMethod;
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'id': 'b1', 'category_id': 'cat-food', 'amount': 3000}),
          200,
        );
      });
      final repository = HttpFinanceRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      await repository.upsertBudget('token-123', categoryId: 'cat-food', amount: 3000);

      expect(capturedUri, Uri.parse('https://example.test/api/finance/budgets'));
      expect(capturedMethod, 'PUT');
      expect(capturedBody, {'category_id': 'cat-food', 'amount': 3000});
    });

    test('upsertBudget sends a null category_id for the overall budget', () async {
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'id': 'b1', 'category_id': null, 'amount': 10000}),
          200,
        );
      });
      final repository = HttpFinanceRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      await repository.upsertBudget('token-123', amount: 10000);

      expect(capturedBody, {'category_id': null, 'amount': 10000});
    });

    test('deleteBudget DELETEs to /budgets/:id', () async {
      Uri? capturedUri;
      String? capturedMethod;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        return http.Response(jsonEncode({'deleted': true}), 200);
      });
      final repository = HttpFinanceRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      await repository.deleteBudget('token-123', 'b1');

      expect(capturedUri, Uri.parse('https://example.test/api/finance/budgets/b1'));
      expect(capturedMethod, 'DELETE');
    });

    test('throws FinanceValidationFailure on a 400 budget upsert (income/archived category)', () async {
      final client = MockClient(
        (request) async => http.Response('Bad Request', 400),
      );
      final repository = HttpFinanceRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.upsertBudget('token-123', categoryId: 'cat-food', amount: 3000),
        throwsA(isA<FinanceValidationFailure>()),
      );
    });

    test('throws FinanceNotFound on a 404 budget delete', () async {
      final client = MockClient(
        (request) async => http.Response('Not Found', 404),
      );
      final repository = HttpFinanceRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.deleteBudget('token-123', 'missing'),
        throwsA(isA<FinanceNotFound>()),
      );
    });

    test('throws FinanceReauthenticationRequired on 401', () async {
      final client = MockClient(
        (request) async => http.Response('Unauthorized', 401),
      );
      final repository = HttpFinanceRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.getCategories('expired-token'),
        throwsA(isA<FinanceReauthenticationRequired>()),
      );
    });

    test('throws FinanceValidationFailure on 400', () async {
      final client = MockClient(
        (request) async => http.Response('Bad Request', 400),
      );
      final repository = HttpFinanceRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.addTransaction(
          'token-123',
          type: FinanceType.expense,
          amount: 0,
          currency: 'TWD',
          categoryId: 'c1',
          date: '2026-07-15',
        ),
        throwsA(isA<FinanceValidationFailure>()),
      );
    });

    test('getSplitSpending GETs {baseUrl}/api/finance/split-spending?month=', () async {
      Uri? capturedUri;
      String? capturedAuthHeader;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedAuthHeader = request.headers['Authorization'];
        return http.Response(
          jsonEncode({
            'month': '2026-08',
            'totals': [
              {'currency': 'TWD', 'amount': 500, 'counted_in_transactions': true},
              {'currency': 'THB', 'amount': 700, 'counted_in_transactions': false},
            ],
          }),
          200,
        );
      });
      final repository = HttpFinanceRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final totals = await repository.getSplitSpending('token-123', '2026-08');

      expect(
        capturedUri,
        Uri.parse('https://example.test/api/finance/split-spending?month=2026-08'),
      );
      expect(capturedAuthHeader, 'Bearer token-123');
      expect(totals.first.currency, 'TWD');
      expect(totals.first.amount, 500);
      // Both directions over the wire, for the same reason as the parser's own
      // guard: a hard-coded answer agrees with whichever half it picked.
      expect(totals.first.countedInTransactions, isTrue);
      expect(totals.last.countedInTransactions, isFalse);
    });

    test('getSplitSpending returns an empty list for a month with no split activity', () async {
      final client = MockClient(
        (request) async => http.Response(jsonEncode({'month': '2026-08', 'totals': []}), 200),
      );
      final repository = HttpFinanceRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final totals = await repository.getSplitSpending('token-123', '2026-08');

      expect(totals, isEmpty);
    });

    test('throws FinanceNotFound on 404', () async {
      final client = MockClient(
        (request) async => http.Response('Not Found', 404),
      );
      final repository = HttpFinanceRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.deleteTransaction('token-123', 'missing'),
        throwsA(isA<FinanceNotFound>()),
      );
    });

    test('throws FinanceFetchFailure on other non-2xx responses', () async {
      final client = MockClient(
        (request) async => http.Response('Internal Server Error', 500),
      );
      final repository = HttpFinanceRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.getCategories('token-123'),
        throwsA(isA<FinanceFetchFailure>()),
      );
    });

    test('throws FinanceFetchFailure (not a crash) on a network error', () async {
      final client = MockClient((request) async => throw Exception('offline'));
      final repository = HttpFinanceRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.getCategories('token-123'),
        throwsA(isA<FinanceFetchFailure>()),
      );
    });
  });
}
