import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/health_calendar.dart';
import '../domain/health_calendar_exceptions.dart';
import '../domain/health_calendar_repository.dart';

/// [HealthCalendarRepository] driven adapter backed by `GET /api/health-calendar`.
class HttpHealthCalendarRepository implements HealthCalendarRepository {
  final String baseUrl;
  final http.Client client;

  HttpHealthCalendarRepository({required this.baseUrl, required this.client});

  @override
  Future<HealthCalendar> getCalendar(
    String idToken, {
    required int year,
    required int month,
    required String today,
  }) async {
    final monthParam = '$year-${month.toString().padLeft(2, '0')}';
    final http.Response response;
    try {
      response = await client.get(
        Uri.parse(
          '$baseUrl/api/health-calendar?month=$monthParam&today=$today',
        ),
        headers: {'Authorization': 'Bearer $idToken'},
      );
    } catch (_) {
      throw const HealthCalendarFetchFailure();
    }
    if (response.statusCode == 401) {
      throw const HealthCalendarReauthenticationRequired();
    }
    if (response.statusCode != 200) throw const HealthCalendarFetchFailure();
    try {
      return HealthCalendar.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (_) {
      throw const HealthCalendarFetchFailure();
    }
  }
}
