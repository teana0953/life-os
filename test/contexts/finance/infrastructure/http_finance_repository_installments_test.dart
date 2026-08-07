import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/contexts/finance/domain/installment_plan.dart';
import 'package:life_os/contexts/finance/infrastructure/http_finance_repository.dart';

HttpFinanceRepository _repo(http.Client client) =>
    HttpFinanceRepository(baseUrl: 'https://example.test', client: client);

/// The backend's `installmentPlanToJson`, verbatim
/// (life-os-backend `src/adapters/http/routes/finance.ts`). Values are chosen
/// so no two fields could be confused for each other if a key were misread.
Map<String, dynamic> _planJson() => {
  'id': 'plan-9',
  'mode': 'per_installment',
  'periods': 240,
  'start_day': '2026-05-15',
  'amount': 32148,
  'currency': 'TWD',
  'category_id': 'cat-home',
  'note': 'mortgage',
};

http.Response _ok(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  group('HttpFinanceRepository instalment plans', () {
    // Every `InstallmentPlan` in every widget test is built through the
    // constructor, so `fromJson` never runs there — a misread key would leave
    // the whole suite green. This file is the only place it executes.
    test('getInstallmentPlan parses every field of the plan', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return _ok(_planJson());
      });

      final plan = await _repo(client).getInstallmentPlan('token-123', 'plan-9');

      expect(
        capturedUri,
        Uri.parse('https://example.test/api/finance/installment-plans/plan-9'),
      );
      expect(plan.id, 'plan-9');
      expect(plan.mode, InstallmentMode.perInstallment);
      expect(plan.periods, 240);
      expect(plan.startDay, '2026-05-15');
      expect(plan.amount, 32148);
      expect(plan.currency, 'TWD');
      expect(plan.categoryId, 'cat-home');
      expect(plan.note, 'mortgage');
    });

    test('the total mode round-trips under its own wire name', () async {
      // `per_installment`/`total` are the server's spellings; the Dart enum is
      // camelCase. Asserting only one mode lets the other map to anything.
      final client = MockClient(
        (_) async => _ok({..._planJson(), 'mode': 'total'}),
      );

      final plan = await _repo(client).getInstallmentPlan('token-123', 'plan-9');

      expect(plan.mode, InstallmentMode.total);
    });

    test('createInstallmentPlan POSTs the body the server reads', () async {
      Uri? capturedUri;
      String? capturedMethod;
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _ok(_planJson());
      });

      await _repo(client).createInstallmentPlan(
        'token-123',
        mode: InstallmentMode.perInstallment,
        amount: 32148,
        periods: 240,
        currency: 'TWD',
        categoryId: 'cat-home',
        startDay: '2026-05-15',
        note: 'mortgage',
      );

      expect(
        capturedUri,
        Uri.parse('https://example.test/api/finance/installment-plans'),
      );
      expect(capturedMethod, 'POST');
      expect(capturedBody, {
        'mode': 'per_installment',
        'amount': 32148,
        'periods': 240,
        'currency': 'TWD',
        'category_id': 'cat-home',
        'start_day': '2026-05-15',
        'note': 'mortgage',
      });
    });

    test('settleInstallmentPlan omits amount entirely when none is given', () async {
      // Not `'amount': null` — the server reads `typeof body.amount ===
      // "number"`, so a null would be ignored anyway, but sending the key at
      // all is how a future "always ask" bug would look on the wire.
      Uri? capturedUri;
      final bodies = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        capturedUri = request.url;
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return _ok({'settled': true});
      });

      await _repo(client).settleInstallmentPlan('token-123', 'plan-9');
      await _repo(client).settleInstallmentPlan('token-123', 'plan-9', amount: 500000);

      expect(
        capturedUri,
        Uri.parse('https://example.test/api/finance/installment-plans/plan-9/settle'),
      );
      expect(bodies.first, isEmpty);
      expect(bodies.last, {'amount': 500000});
    });

    test('updateInstallmentPlan PUTs amount and periods', () async {
      Uri? capturedUri;
      String? capturedMethod;
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _ok(_planJson());
      });

      await _repo(client).updateInstallmentPlan(
        'token-123',
        'plan-9',
        amount: 33000,
        periods: 200,
      );

      expect(
        capturedUri,
        Uri.parse('https://example.test/api/finance/installment-plans/plan-9'),
      );
      expect(capturedMethod, 'PUT');
      expect(capturedBody, {'amount': 33000, 'periods': 200});
    });
  });
}
