import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/care_item.dart';
import '../domain/care_history.dart';
import '../domain/care_today.dart';

/// [CareHistoryRepository] driven adapter backed by `/api/care/range` (GET)
/// and `/api/care/log` (PUT). `getRange` parses the
/// `{from,to,days:[{date,items:[...]}]}` envelope — the same per-slot shape
/// as `/api/care/today` (mirrors `HttpCareTodayRepository`'s `_parseSlot`);
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

  CareTodaySlot _parseSlot(Map<String, dynamic> json) => CareTodaySlot(
    careItemId: json['care_item_id'] as String,
    careScheduleId: json['care_schedule_id'] as String,
    category: careCategoryFromWire(json['category'] as String),
    title: json['title'] as String,
    note: json['note'] as String?,
    dose: json['dose'] as String?,
    timeOfDay: json['time_of_day'] as String,
    localDate: json['local_date'] as String,
    status: careTodayStatusFromWire(json['status'] as String),
    doneTime: json['done_time'] as String?,
    doseQuantity: (json['dose_quantity'] as num).toDouble(),
  );

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
      final envelope = jsonDecode(response.body) as Map<String, dynamic>;
      final days = envelope['days'] as List;
      return days
          .map(
            (e) => _parseDay(e as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      throw const CareRequestFailed();
    }
  }

  CareHistoryDay _parseDay(Map<String, dynamic> json) {
    final items = json['items'] as List;
    return CareHistoryDay(
      date: json['date'] as String,
      slots: items.map((e) => _parseSlot(e as Map<String, dynamic>)).toList(),
    );
  }

  @override
  Future<void> editSlot(
    String idToken, {
    required String careScheduleId,
    required String localDate,
    required String timeOfDay,
    required CareLogStatus status,
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
        }),
      );
    } catch (_) {
      throw const CareRequestFailed();
    }
    _checkStatus(response);
  }
}
