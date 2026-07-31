import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/contexts/finance/domain/finance_exceptions.dart';
import 'package:life_os/contexts/finance/domain/networth_account.dart';
import 'package:life_os/contexts/finance/infrastructure/http_finance_repository.dart';

HttpFinanceRepository _repo(http.Client client) =>
    HttpFinanceRepository(baseUrl: 'https://example.test', client: client);

void main() {
  group('HttpFinanceRepository networth', () {
    test('listNetWorthAccounts GETs the accounts endpoint', () async {
      Uri? capturedUri;
      String? capturedAuth;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedAuth = request.headers['Authorization'];
        return http.Response(
          jsonEncode({
            'accounts': [
              {
                'id': 'a1',
                'kind': 'asset',
                'name': '台幣活存',
                'sort_order': 0,
                'archived': false,
              },
              {
                'id': 'l1',
                'kind': 'liability',
                'name': '房貸',
                'sort_order': 1,
                'archived': true,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final accounts = await _repo(client).listNetWorthAccounts('token-123');

      expect(
        capturedUri,
        Uri.parse('https://example.test/api/finance/networth/accounts'),
      );
      expect(capturedAuth, 'Bearer token-123');
      expect(accounts, hasLength(2));
      expect(accounts.first.kind, NetWorthKind.asset);
      expect(accounts.first.name, '台幣活存');
      expect(accounts.last.kind, NetWorthKind.liability);
      expect(accounts.last.archived, isTrue);
    });

    test('createNetWorthAccount POSTs kind/name/sort_order', () async {
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'id': 'a9',
            'kind': 'liability',
            'name': '車貸',
            'sort_order': 3,
            'archived': false,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final account = await _repo(client).createNetWorthAccount(
        'token-123',
        kind: NetWorthKind.liability,
        name: '車貸',
        sortOrder: 3,
      );

      expect(capturedBody, {'kind': 'liability', 'name': '車貸', 'sort_order': 3});
      expect(account.id, 'a9');
      expect(account.kind, NetWorthKind.liability);
    });

    test('createNetWorthAccount omits sort_order when not given', () async {
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'id': 'a9',
            'kind': 'asset',
            'name': '黃金',
            'sort_order': 0,
            'archived': false,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      await _repo(
        client,
      ).createNetWorthAccount('token-123', kind: NetWorthKind.asset, name: '黃金');

      expect(capturedBody, {'kind': 'asset', 'name': '黃金'});
    });

    test('updateNetWorthAccount PUTs only the provided fields', () async {
      Uri? capturedUri;
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'id': 'a1',
            'kind': 'asset',
            'name': '台幣活存',
            'sort_order': 0,
            'archived': true,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final account = await _repo(
        client,
      ).updateNetWorthAccount('token-123', 'a1', archived: true);

      expect(
        capturedUri,
        Uri.parse('https://example.test/api/finance/networth/accounts/a1'),
      );
      expect(capturedBody, {'archived': true});
      expect(account.archived, isTrue);
    });

    test('upsertNetWorthSnapshot PUTs account_id/month/value', () async {
      Uri? capturedUri;
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'id': 's1',
            'account_id': 'a1',
            'month': '2026-07',
            'value': 0,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final snapshot = await _repo(client).upsertNetWorthSnapshot(
        'token-123',
        accountId: 'a1',
        month: '2026-07',
        value: 0,
      );

      expect(
        capturedUri,
        Uri.parse('https://example.test/api/finance/networth/snapshots'),
      );
      expect(capturedBody, {
        'account_id': 'a1',
        'month': '2026-07',
        'value': 0,
      });
      expect(snapshot.value, 0);
    });

    test('getMonthlyNetWorth parses totals, net worth, and growth', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            'month': '2026-07',
            'accounts': [
              {
                'account_id': 'a1',
                'kind': 'asset',
                'name': '台幣活存',
                'value': 520000,
              },
              {
                'account_id': 'l1',
                'kind': 'liability',
                'name': '信用卡',
                'value': 41484,
              },
            ],
            'total_asset': 520000,
            'total_liability': 41484,
            'net_worth': 478516,
            'prev_net_worth': 460181,
            'growth_rate': 0.0398,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final monthly = await _repo(client).getMonthlyNetWorth('token-123', '2026-07');

      expect(
        capturedUri,
        Uri.parse('https://example.test/api/finance/networth?month=2026-07'),
      );
      expect(monthly.netWorth, 478516);
      expect(monthly.totalAsset, 520000);
      expect(monthly.totalLiability, 41484);
      expect(monthly.prevNetWorth, 460181);
      expect(monthly.growthRate, closeTo(0.0398, 0.0001));
      expect(monthly.accounts, hasLength(2));
      expect(monthly.accounts.last.kind, NetWorthKind.liability);
    });

    test('getMonthlyNetWorth accepts a null prev/growth (first month)', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'month': '2026-07',
            'accounts': <dynamic>[],
            'total_asset': 0,
            'total_liability': 0,
            'net_worth': 0,
            'prev_net_worth': null,
            'growth_rate': null,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      final monthly = await _repo(client).getMonthlyNetWorth('token-123', '2026-07');

      expect(monthly.prevNetWorth, isNull);
      expect(monthly.growthRate, isNull);
      expect(monthly.accounts, isEmpty);
    });

    test('getNetWorthTrend GETs from/to and parses ascending points', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            'points': [
              {'month': '2026-06', 'net_worth': 460181},
              {'month': '2026-07', 'net_worth': 478516},
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final points = await _repo(
        client,
      ).getNetWorthTrend('token-123', from: '2026-06', to: '2026-07');

      expect(
        capturedUri,
        Uri.parse(
          'https://example.test/api/finance/networth/trend?from=2026-06&to=2026-07',
        ),
      );
      expect(points.map((p) => p.month), ['2026-06', '2026-07']);
      expect(points.last.netWorth, 478516);
    });

    test('maps 401 to FinanceReauthenticationRequired', () async {
      final client = MockClient((request) async => http.Response('', 401));

      expect(
        () => _repo(client).listNetWorthAccounts('stale'),
        throwsA(isA<FinanceReauthenticationRequired>()),
      );
    });

    test('maps 400 to FinanceValidationFailure', () async {
      final client = MockClient((request) async => http.Response('', 400));

      expect(
        () => _repo(client).upsertNetWorthSnapshot(
          'token-123',
          accountId: 'a1',
          month: '2026-07',
          value: -1,
        ),
        throwsA(isA<FinanceValidationFailure>()),
      );
    });

    test('maps 404 to FinanceNotFound', () async {
      final client = MockClient((request) async => http.Response('', 404));

      expect(
        () => _repo(client).updateNetWorthAccount('token-123', 'gone', name: 'x'),
        throwsA(isA<FinanceNotFound>()),
      );
    });

    test('maps other non-2xx to FinanceFetchFailure', () async {
      final client = MockClient((request) async => http.Response('boom', 500));

      expect(
        () => _repo(client).getNetWorthTrend('t', from: '2026-01', to: '2026-02'),
        throwsA(isA<FinanceFetchFailure>()),
      );
    });
  });
}
