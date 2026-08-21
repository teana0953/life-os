import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/care_item.dart';
import '../domain/care_history.dart';
import '../domain/care_today.dart';
import 'http_care_today_repository.dart';

/// Decodes one `{date, items:[...]}` day of `/api/care/range` — the same
/// per-slot shape as `/api/care/today`. Public and top-level so the
/// screen-batch decoder shares this one definition with the granular
/// repository below.
CareHistoryDay careHistoryDayFromJson(Map<String, dynamic> json) =>
    CareHistoryDay(
      date: json['date'] as String,
      slots: (json['items'] as List)
          .map((e) => careTodaySlotFromJson(e as Map<String, dynamic>))
          .toList(),
    );

/// Decodes the `{from, to, days:[...]}` envelope of `/api/care/range`.
List<CareHistoryDay> careHistoryDaysFromJson(Map<String, dynamic> envelope) =>
    (envelope['days'] as List)
        .map((e) => careHistoryDayFromJson(e as Map<String, dynamic>))
        .toList();

/// [CareHistoryRepository] driven adapter backed by `/api/care/range` (GET)
/// and `/api/care/log` (PUT). `getRange` parses the
/// `{from,to,days:[{date,items:[...]}]}` envelope — the same per-slot shape
/// as `/api/care/today` (it reuses [careTodaySlotFromJson]);
/// `editSlot` PUTs a snake_case body to overwrite a slot's outcome.
class HttpCareHistoryRepository implements CareHistoryRepository {
  final String baseUrl;
  final http.Client client;

  HttpCareHistoryRepository({required this.baseUrl, required this.client});

  Map<String, String> _headers(String idToken) => {
    'Authorization': 'Bearer $idToken',
    'Content-Type': 'application/json',
  };

  void _checkStatus(http.Response response) {
    if (response.statusCode == 401) throw const CareReauthRequired();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const CareRequestFailed();
    }
  }

  @override
  Future<List<CareHistoryDay>> getRange(
    String idToken,
    String from,
    String to,
  ) async {
    final http.Response response;
    try {
      response = await client.get(
        Uri.parse('$baseUrl/api/care/range?from=$from&to=$to'),
        headers: _headers(idToken),
      );
    } catch (_) {
      throw const CareRequestFailed();
    }
    _checkStatus(response);
    try {
      return careHistoryDaysFromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (_) {
      throw const CareRequestFailed();
    }
  }

  @override
  Future<void> editSlot(
    String idToken, {
    required String careScheduleId,
    required String localDate,
    required String timeOfDay,
    required CareLogStatus status,
    DateTime? doneTime,
  }) async {
    final http.Response response;
    try {
      response = await client.put(
        Uri.parse('$baseUrl/api/care/log'),
        headers: _headers(idToken),
        body: jsonEncode({
          'care_schedule_id': careScheduleId,
          'local_date': localDate,
          'time_of_day': timeOfDay,
          'status': status.wireValue,
          // A skipped record was never completed — never write a completion
          // time for it, even if the caller passed one.
          if (doneTime != null && status != CareLogStatus.skipped)
            'done_time': doneTime.toUtc().toIso8601String(),
        }),
      );
    } catch (_) {
      throw const CareRequestFailed();
    }
    _checkStatus(response);
  }
}
