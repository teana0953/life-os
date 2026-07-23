import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/chaodays_import_summary.dart';
import '../domain/import_exceptions.dart';
import '../domain/import_repository.dart';

/// [ImportRepository] driven adapter backed by the
/// `/api/import/chaodays/{weight,diet,water,bowel}` HTTP endpoints.
class HttpImportRepository implements ImportRepository {
  final String baseUrl;
  final http.Client client;

  HttpImportRepository({required this.baseUrl, required this.client});

  static const _genericFailureMessage =
      'Unable to import your chaodays data. Please try again.';

  Map<String, String> _headers(String idToken) => {
    'Authorization': 'Bearer $idToken',
    'Content-Type': 'application/json',
  };

  Future<ChaodaysImportSummary> _import(
    String idToken,
    String path, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
    required ChaodaysImportSummary Function(Map<String, dynamic>) parse,
  }) async {
    final http.Response response;
    try {
      response = await client.post(
        Uri.parse('$baseUrl$path'),
        headers: _headers(idToken),
        body: jsonEncode({
          'chaodays_uid': chaodaysUid,
          'chaodays_password': chaodaysPassword,
          'start_date': startDate,
          'end_date': endDate,
        }),
      );
    } catch (_) {
      throw const ImportFetchFailure(_genericFailureMessage);
    }

    if (response.statusCode == 401) {
      throw const ImportReauthenticationRequired();
    }
    if (response.statusCode == 400) {
      if (_errorCode(response.body) == 'chaodays_auth_failed') {
        throw const ImportChaodaysAuthFailed();
      }
      throw const ImportFetchFailure(_genericFailureMessage);
    }
    if (response.statusCode == 502) {
      throw const ImportChaodaysUnavailable();
    }
    if (response.statusCode != 200) {
      throw const ImportFetchFailure(_genericFailureMessage);
    }

    try {
      return parse(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      throw const ImportFetchFailure(_genericFailureMessage);
    }
  }

  String? _errorCode(String body) {
    try {
      return (jsonDecode(body) as Map<String, dynamic>)['error'] as String?;
    } catch (_) {
      return null;
    }
  }

  ChaodaysImportSummary _parseCounts(Map<String, dynamic> json) =>
      ChaodaysImportSummary(
        imported: json['imported'] as int,
        skipped: json['skipped'] as int,
      );

  ChaodaysImportSummary _parseDietCounts(Map<String, dynamic> json) =>
      ChaodaysImportSummary(
        imported: json['mealsImported'] as int,
        skipped: json['mealsSkipped'] as int,
        glucoseImported: json['glucoseImported'] as int,
      );

  @override
  Future<ChaodaysImportSummary> importWeight(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) => _import(
    idToken,
    '/api/import/chaodays/weight',
    chaodaysUid: chaodaysUid,
    chaodaysPassword: chaodaysPassword,
    startDate: startDate,
    endDate: endDate,
    parse: _parseCounts,
  );

  @override
  Future<ChaodaysImportSummary> importDiet(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) => _import(
    idToken,
    '/api/import/chaodays/diet',
    chaodaysUid: chaodaysUid,
    chaodaysPassword: chaodaysPassword,
    startDate: startDate,
    endDate: endDate,
    parse: _parseDietCounts,
  );

  @override
  Future<ChaodaysImportSummary> importWater(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) => _import(
    idToken,
    '/api/import/chaodays/water',
    chaodaysUid: chaodaysUid,
    chaodaysPassword: chaodaysPassword,
    startDate: startDate,
    endDate: endDate,
    parse: _parseCounts,
  );

  @override
  Future<ChaodaysImportSummary> importBowel(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) => _import(
    idToken,
    '/api/import/chaodays/bowel',
    chaodaysUid: chaodaysUid,
    chaodaysPassword: chaodaysPassword,
    startDate: startDate,
    endDate: endDate,
    parse: _parseCounts,
  );
}
