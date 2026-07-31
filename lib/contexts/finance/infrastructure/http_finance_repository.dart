import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/finance_budget.dart';
import '../domain/finance_category.dart';
import '../domain/finance_exceptions.dart';
import '../domain/finance_repository.dart';
import '../domain/finance_transaction.dart';
import '../domain/finance_type.dart';
import '../domain/monthly_summary.dart';

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
  /// not found, everything else -> generic fetch failure.
  Never _throwForStatus(int statusCode) {
    if (statusCode == 400) throw const FinanceValidationFailure();
    if (statusCode == 404) throw const FinanceNotFound();
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
}
