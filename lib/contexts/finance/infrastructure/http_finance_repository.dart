import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/finance_budget.dart';
import '../domain/finance_category.dart';
import '../domain/finance_exceptions.dart';
import '../domain/finance_repository.dart';
import '../domain/finance_transaction.dart';
import '../domain/finance_type.dart';
import '../domain/monthly_summary.dart';
import '../domain/networth_account.dart';
import '../domain/networth_snapshot.dart';
import '../domain/split_spending.dart';

/// [FinanceRepository] driven adapter backed by the `/api/finance/*` HTTP
/// endpoints (contract frozen in design.md).
class HttpFinanceRepository implements FinanceRepository {
  final String baseUrl;
  final http.Client client;

  HttpFinanceRepository({required this.baseUrl, required this.client});

  static const _genericFailureMessage =
      'Unable to load your finance data. Please try again.';

  Map<String, String> _headers(String idToken) => {
    'Authorization': 'Bearer $idToken',
    'Content-Type': 'application/json',
  };

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request();
    } catch (_) {
      throw const FinanceFetchFailure(_genericFailureMessage);
    }
    if (response.statusCode == 401) {
      throw const FinanceReauthenticationRequired();
    }
    return response;
  }

  /// Maps a non-2xx response to a typed exception: 400 -> validation, 404 ->
  /// not found, 409 -> the split moved on under the caller, everything else ->
  /// generic fetch failure.
  ///
  /// The 409 mapping is unconditional because the backend returns that status
  /// from exactly one place (`routes/finance.ts`: a transaction write that lost
  /// the race against a split edit).
  Never _throwForStatus(int statusCode) {
    if (statusCode == 400) throw const FinanceValidationFailure();
    if (statusCode == 404) throw const FinanceNotFound();
    if (statusCode == 409) throw const FinanceConflict();
    throw FinanceFetchFailure(
      'Finance request failed (status $statusCode).',
    );
  }

  @override
  Future<List<FinanceCategory>> getCategories(String idToken) async {
    final response = await _send(
      () => client.get(
        Uri.parse('$baseUrl/api/finance/categories'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) _throwForStatus(response.statusCode);
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return (json['categories'] as List)
          .map((e) => FinanceCategory.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      throw const FinanceFetchFailure(_genericFailureMessage);
    }
  }

  @override
  Future<List<FinanceTransaction>> getTransactions(
    String idToken, {
    required String from,
    required String to,
  }) async {
    final response = await _send(
      () => client.get(
        Uri.parse('$baseUrl/api/finance/transactions?from=$from&to=$to'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) _throwForStatus(response.statusCode);
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return (json['transactions'] as List)
          .map((e) => FinanceTransaction.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      throw const FinanceFetchFailure(_genericFailureMessage);
    }
  }

  @override
  Future<MonthlySummary> getSummary(String idToken, String month) async {
    final response = await _send(
      () => client.get(
        Uri.parse('$baseUrl/api/finance/summary?month=$month'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) _throwForStatus(response.statusCode);
    try {
      return MonthlySummary.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (_) {
      throw const FinanceFetchFailure(_genericFailureMessage);
    }
  }

  Map<String, dynamic> _transactionBody({
    required FinanceType type,
    required int amount,
    required String currency,
    required String categoryId,
    required String date,
    String? note,
  }) => {
    'type': financeTypeToJson(type),
    'amount': amount,
    'currency': currency,
    'category_id': categoryId,
    'date': date,
    if (note != null) 'note': note,
  };

  @override
  Future<FinanceTransaction> addTransaction(
    String idToken, {
    required FinanceType type,
    required int amount,
    required String currency,
    required String categoryId,
    required String date,
    String? note,
  }) async {
    final response = await _send(
      () => client.post(
        Uri.parse('$baseUrl/api/finance/transactions'),
        headers: _headers(idToken),
        body: jsonEncode(
          _transactionBody(
            type: type,
            amount: amount,
            currency: currency,
            categoryId: categoryId,
            date: date,
            note: note,
          ),
        ),
      ),
    );
    if (response.statusCode != 200) _throwForStatus(response.statusCode);
    try {
      return FinanceTransaction.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (_) {
      throw const FinanceFetchFailure(_genericFailureMessage);
    }
  }

  @override
  Future<FinanceTransaction> updateTransaction(
    String idToken,
    String id, {
    required FinanceType type,
    required int amount,
    required String currency,
    required String categoryId,
    required String date,
    String? note,
  }) async {
    final response = await _send(
      () => client.put(
        Uri.parse('$baseUrl/api/finance/transactions/$id'),
        headers: _headers(idToken),
        body: jsonEncode(
          _transactionBody(
            type: type,
            amount: amount,
            currency: currency,
            categoryId: categoryId,
            date: date,
            note: note,
          ),
        ),
      ),
    );
    if (response.statusCode != 200) _throwForStatus(response.statusCode);
    try {
      return FinanceTransaction.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (_) {
      throw const FinanceFetchFailure(_genericFailureMessage);
    }
  }

  @override
  Future<void> deleteTransaction(String idToken, String id) async {
    final response = await _send(
      () => client.delete(
        Uri.parse('$baseUrl/api/finance/transactions/$id'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) _throwForStatus(response.statusCode);
  }

  @override
  Future<List<FinanceBudget>> listBudgets(String idToken, String month) async {
    final response = await _send(
      () => client.get(
        Uri.parse('$baseUrl/api/finance/budgets?month=$month'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) _throwForStatus(response.statusCode);
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return (json['budgets'] as List)
          .map((e) => FinanceBudget.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      throw const FinanceFetchFailure(_genericFailureMessage);
    }
  }

  @override
  Future<void> upsertBudget(
    String idToken, {
    String? categoryId,
    required int amount,
  }) async {
    final response = await _send(
      () => client.put(
        Uri.parse('$baseUrl/api/finance/budgets'),
        headers: _headers(idToken),
        body: jsonEncode({'category_id': categoryId, 'amount': amount}),
      ),
    );
    if (response.statusCode != 200) _throwForStatus(response.statusCode);
  }

  @override
  Future<void> deleteBudget(String idToken, String id) async {
    final response = await _send(
      () => client.delete(
        Uri.parse('$baseUrl/api/finance/budgets/$id'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) _throwForStatus(response.statusCode);
  }

  /// Decodes a 200 body with [parse], turning any malformed payload into the
  /// generic fetch failure (mirrors the ledger methods above).
  T _decode<T>(http.Response response, T Function(Map<String, dynamic>) parse) {
    try {
      return parse(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      throw const FinanceFetchFailure(_genericFailureMessage);
    }
  }

  @override
  Future<List<NetWorthAccount>> listNetWorthAccounts(String idToken) async {
    final response = await _send(
      () => client.get(
        Uri.parse('$baseUrl/api/finance/networth/accounts'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) _throwForStatus(response.statusCode);
    return _decode(
      response,
      (json) => (json['accounts'] as List)
          .map((e) => NetWorthAccount.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<NetWorthAccount> createNetWorthAccount(
    String idToken, {
    required NetWorthKind kind,
    required String name,
    int? sortOrder,
  }) async {
    final response = await _send(
      () => client.post(
        Uri.parse('$baseUrl/api/finance/networth/accounts'),
        headers: _headers(idToken),
        body: jsonEncode({
          'kind': netWorthKindToJson(kind),
          'name': name,
          if (sortOrder != null) 'sort_order': sortOrder,
        }),
      ),
    );
    if (response.statusCode != 200) _throwForStatus(response.statusCode);
    return _decode(response, NetWorthAccount.fromJson);
  }

  @override
  Future<NetWorthAccount> updateNetWorthAccount(
    String idToken,
    String id, {
    String? name,
    int? sortOrder,
    bool? archived,
  }) async {
    final response = await _send(
      () => client.put(
        Uri.parse('$baseUrl/api/finance/networth/accounts/$id'),
        headers: _headers(idToken),
        body: jsonEncode({
          if (name != null) 'name': name,
          if (sortOrder != null) 'sort_order': sortOrder,
          if (archived != null) 'archived': archived,
        }),
      ),
    );
    if (response.statusCode != 200) _throwForStatus(response.statusCode);
    return _decode(response, NetWorthAccount.fromJson);
  }

  @override
  Future<void> reorderNetWorthAccounts(
    String idToken,
    NetWorthKind kind,
    List<String> orderedIds,
  ) async {
    final response = await _send(
      () => client.put(
        Uri.parse('$baseUrl/api/finance/networth/accounts/order'),
        headers: _headers(idToken),
        body: jsonEncode({
          'kind': netWorthKindToJson(kind),
          'ids': orderedIds,
        }),
      ),
    );
    if (response.statusCode != 200) _throwForStatus(response.statusCode);
  }

  @override
  Future<NetWorthSnapshot> upsertNetWorthSnapshot(
    String idToken, {
    required String accountId,
    required String month,
    required int value,
  }) async {
    final response = await _send(
      () => client.put(
        Uri.parse('$baseUrl/api/finance/networth/snapshots'),
        headers: _headers(idToken),
        body: jsonEncode({
          'account_id': accountId,
          'month': month,
          'value': value,
        }),
      ),
    );
    if (response.statusCode != 200) _throwForStatus(response.statusCode);
    return _decode(response, NetWorthSnapshot.fromJson);
  }

  @override
  Future<MonthlyNetWorth> getMonthlyNetWorth(String idToken, String month) async {
    final response = await _send(
      () => client.get(
        Uri.parse('$baseUrl/api/finance/networth?month=$month'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) _throwForStatus(response.statusCode);
    return _decode(response, MonthlyNetWorth.fromJson);
  }

  @override
  Future<List<NetWorthTrendPoint>> getNetWorthTrend(
    String idToken, {
    required String from,
    required String to,
  }) async {
    final response = await _send(
      () => client.get(
        Uri.parse('$baseUrl/api/finance/networth/trend?from=$from&to=$to'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) _throwForStatus(response.statusCode);
    return _decode(
      response,
      (json) => (json['points'] as List)
          .map((e) => NetWorthTrendPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<List<SplitSpending>> getSplitSpending(String idToken, String month) async {
    final response = await _send(
      () => client.get(
        Uri.parse('$baseUrl/api/finance/split-spending?month=$month'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) _throwForStatus(response.statusCode);
    return _decode(
      response,
      (json) => (json['totals'] as List)
          .map((e) => SplitSpending.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
