import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/menstrual_exceptions.dart';
import '../domain/menstrual_period.dart';
import '../domain/menstrual_repository.dart';

String _ymd(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// [MenstrualRepository] driven adapter backed by the `/api/menstrual` HTTP
/// endpoints.
class HttpMenstrualRepository implements MenstrualRepository {
  final String baseUrl;
  final http.Client client;

  HttpMenstrualRepository({required this.baseUrl, required this.client});

  Map<String, String> _headers(String idToken) => {
    'Authorization': 'Bearer $idToken',
    'Content-Type': 'application/json',
  };

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request();
    } catch (_) {
      throw const MenstrualFetchFailure();
    }
    if (response.statusCode == 401) {
      throw const MenstrualReauthenticationRequired();
    }
    return response;
  }

  @override
  Future<MenstrualOverview> getOverview(String idToken) async {
    final response = await _send(
      () => client.get(
        Uri.parse('$baseUrl/api/menstrual'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) throw const MenstrualFetchFailure();
    try {
      return MenstrualOverview.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (_) {
      throw const MenstrualFetchFailure();
    }
  }

  @override
  Future<MenstrualPeriod> addPeriod(
    String idToken, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    final response = await _send(
      () => client.post(
        Uri.parse('$baseUrl/api/menstrual'),
        headers: _headers(idToken),
        body: jsonEncode({
          'start_date': _ymd(startDate),
          if (endDate != null) 'end_date': _ymd(endDate),
        }),
      ),
    );
    if (response.statusCode != 200) throw const MenstrualFetchFailure();
    try {
      return MenstrualPeriod.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (_) {
      throw const MenstrualFetchFailure();
    }
  }

  @override
  Future<MenstrualPeriod> updatePeriod(
    String idToken,
    String id, {
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
  }) async {
    // Partial update: send only the fields that changed. `end_date: null`
    // explicitly clears the end date (reopening a completed period); an
    // untouched field is omitted entirely so the backend leaves it alone.
    final body = <String, dynamic>{
      if (startDate != null) 'start_date': _ymd(startDate),
      if (clearEndDate)
        'end_date': null
      else if (endDate != null)
        'end_date': _ymd(endDate),
    };
    final response = await _send(
      () => client.patch(
        Uri.parse('$baseUrl/api/menstrual/$id'),
        headers: _headers(idToken),
        body: jsonEncode(body),
      ),
    );
    if (response.statusCode != 200) throw const MenstrualFetchFailure();
    try {
      return MenstrualPeriod.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (_) {
      throw const MenstrualFetchFailure();
    }
  }

  @override
  Future<bool> deletePeriod(String idToken, String id) async {
    final response = await _send(
      () => client.delete(
        Uri.parse('$baseUrl/api/menstrual/$id'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) throw const MenstrualFetchFailure();
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return (json['deleted'] as bool?) ?? false;
    } catch (_) {
      throw const MenstrualFetchFailure();
    }
  }
}
