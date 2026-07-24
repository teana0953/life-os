import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/care_item.dart';
import '../domain/care_today.dart';

/// [CareTodayRepository] driven adapter backed by `/api/care/today` (GET)
/// and `/api/care/log` (POST). `getToday` parses the `{date, items:[...]}`
/// envelope (design D1 — the Slice-2b trap class: not a bare array);
/// `logSlot` POSTs a snake_case body and ignores the bare returned log
/// (design D2's quiet reload re-fetches Today for the reflected state).
class HttpCareTodayRepository implements CareTodayRepository {
  final String baseUrl;
  final http.Client client;

  HttpCareTodayRepository({required this.baseUrl, required this.client});

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
  Future<CareToday> getToday(String idToken) async {
    final http.Response response;
    try {
      response = await client.get(
        Uri.parse('$baseUrl/api/care/today'),
        headers: _headers(idToken),
      );
    } catch (_) {
      throw const CareRequestFailed();
    }
    _checkStatus(response);
    try {
      final envelope = jsonDecode(response.body) as Map<String, dynamic>;
      final items = envelope['items'] as List;
      return CareToday(
        date: envelope['date'] as String,
        slots: items.map((e) => _parseSlot(e as Map<String, dynamic>)).toList(),
      );
    } catch (_) {
      throw const CareRequestFailed();
    }
  }

  @override
  Future<void> logSlot(
    String idToken, {
    required String careScheduleId,
    required String localDate,
    required String timeOfDay,
    required CareLogStatus status,
  }) async {
    final http.Response response;
    try {
      response = await client.post(
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
