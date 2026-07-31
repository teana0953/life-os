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
      expect(transactions.single.amount, 120);
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
