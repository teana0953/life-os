import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/vitals_day.dart';
import '../domain/vitals_exceptions.dart';
import '../domain/vitals_repository.dart';
import '../domain/vitals_series.dart';

/// [VitalsRepository] driven adapter backed by the `/api/vitals` HTTP endpoints.
class HttpVitalsRepository implements VitalsRepository {
  final String baseUrl;
  final http.Client client;

  HttpVitalsRepository({required this.baseUrl, required this.client});

  static const _genericFailureMessage =
      'Unable to load your vitals data. Please try again.';

  Map<String, String> _headers(String idToken) => {
    'Authorization': 'Bearer $idToken',
    'Content-Type': 'application/json',
  };

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request();
    } catch (_) {
      throw const VitalsFetchFailure(_genericFailureMessage);
    }
    if (response.statusCode == 401) {
      throw const VitalsReauthenticationRequired();
    }
    return response;
  }

  @override
  Future<VitalsDay> getDay(String idToken, String day) async {
    final response = await _send(
      () => client.get(
        Uri.parse('$baseUrl/api/vitals?day=$day'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) {
      throw VitalsFetchFailure(
        'Failed to load the day\'s vitals record (status ${response.statusCode}).',
      );
    }
    return _parse(response.body);
  }

  @override
  Future<VitalsDay> save(String idToken, VitalsDay day) async {
    final response = await _send(
      () => client.put(
        Uri.parse('$baseUrl/api/vitals'),
        headers: _headers(idToken),
        body: jsonEncode(day.toJson()),
      ),
    );
    if (response.statusCode != 200) {
      throw VitalsFetchFailure(
        'Failed to save the vitals record (status ${response.statusCode}).',
      );
    }
    return _parse(response.body);
  }

  @override
  Future<VitalsRange> getRange(
    String idToken,
    DateTime from,
    DateTime to,
  ) async {
    final response = await _send(
      () => client.get(
        Uri.parse(
          '$baseUrl/api/vitals/range?from=${_fmtDay(from)}&to=${_fmtDay(to)}',
        ),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) {
      throw VitalsFetchFailure(
        'Failed to load the vitals trends (status ${response.statusCode}).',
      );
    }
    try {
      return VitalsRange.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (_) {
      throw const VitalsFetchFailure(_genericFailureMessage);
    }
  }

  static String _fmtDay(DateTime day) {
    final month = day.month.toString().padLeft(2, '0');
    final dayOfMonth = day.day.toString().padLeft(2, '0');
    return '${day.year}-$month-$dayOfMonth';
  }

  VitalsDay _parse(String body) {
    try {
      return VitalsDay.fromJson(jsonDecode(body) as Map<String, dynamic>);
    } catch (_) {
      throw const VitalsFetchFailure(_genericFailureMessage);
    }
  }
}
