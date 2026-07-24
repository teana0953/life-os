import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/medication_reminder.dart';

/// [MedicationReminderRepository] driven adapter backed by the
/// `/api/reminders/medication` + `/api/user/timezone` HTTP endpoints
/// (mirrors `HttpPushRepository`).
class HttpMedicationReminderRepository implements MedicationReminderRepository {
  final String baseUrl;
  final http.Client client;

  HttpMedicationReminderRepository({required this.baseUrl, required this.client});

  Map<String, String> _headers(String idToken) => {
    'Authorization': 'Bearer $idToken',
    'Content-Type': 'application/json',
  };

  void _checkStatus(http.Response response) {
    if (response.statusCode == 401) throw const ReminderReauthRequired();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const ReminderRequestFailed();
    }
  }

  Map<String, dynamic> _partialBody(MedicationReminderUpdate update) {
    final body = <String, dynamic>{};
    if (update.label != null) body['label'] = update.label;
    if (update.times != null) body['times'] = update.times;
    if (update.daysOfWeek != null) body['days_of_week'] = update.daysOfWeek;
    if (update.weekInterval != null) {
      body['week_interval'] = update.weekInterval;
    }
    // Date-only — never `toIso8601String()` (design D4b; a naive local/UTC
    // time component would 400 the backend).
    if (update.anchorDate != null) {
      body['anchor_date'] = _dateOnly(update.anchorDate!);
    }
    if (update.enabled != null) body['enabled'] = update.enabled;
    return body;
  }

  MedicationReminder _parse(Map<String, dynamic> json) => MedicationReminder(
    id: json['id'] as String,
    label: json['label'] as String,
    times: (json['times'] as List).cast<String>(),
    daysOfWeek: (json['days_of_week'] as List).map((e) => e as int).toList(),
    weekInterval: json['week_interval'] as int,
    anchorDate: _parseDateOnly(json['anchor_date'] as String),
    enabled: json['enabled'] as bool,
  );

  @override
  Future<List<MedicationReminder>> list(String idToken) async {
    final http.Response response;
    try {
      response = await client.get(
        Uri.parse('$baseUrl/api/reminders/medication'),
        headers: _headers(idToken),
      );
    } catch (_) {
      throw const ReminderRequestFailed();
    }
    _checkStatus(response);
    try {
      final envelope = jsonDecode(response.body) as Map<String, dynamic>;
      final json = envelope['reminders'] as List;
      return json.map((e) => _parse(e as Map<String, dynamic>)).toList();
    } catch (_) {
      throw const ReminderRequestFailed();
    }
  }

  @override
  Future<void> create(String idToken, MedicationReminderDraft draft) async {
    final http.Response response;
    try {
      response = await client.post(
        Uri.parse('$baseUrl/api/reminders/medication'),
        headers: _headers(idToken),
        body: jsonEncode({
          'label': draft.label,
          'times': draft.times,
          'days_of_week': draft.daysOfWeek,
          'week_interval': draft.weekInterval,
          // Date-only — never `toIso8601String()` (design D4b).
          'anchor_date': _dateOnly(draft.anchorDate),
          'enabled': draft.enabled,
        }),
      );
    } catch (_) {
      throw const ReminderRequestFailed();
    }
    _checkStatus(response);
  }

  @override
  Future<void> update(
    String idToken,
    String id,
    MedicationReminderUpdate changes,
  ) async {
    final http.Response response;
    try {
      response = await client.patch(
        Uri.parse('$baseUrl/api/reminders/medication/$id'),
        headers: _headers(idToken),
        body: jsonEncode(_partialBody(changes)),
      );
    } catch (_) {
      throw const ReminderRequestFailed();
    }
    _checkStatus(response);
  }

  @override
  Future<void> delete(String idToken, String id) async {
    final http.Response response;
    try {
      response = await client.delete(
        Uri.parse('$baseUrl/api/reminders/medication/$id'),
        headers: _headers(idToken),
      );
    } catch (_) {
      throw const ReminderRequestFailed();
    }
    _checkStatus(response);
  }

  @override
  Future<void> setTimezone(String idToken, String timezone) async {
    final http.Response response;
    try {
      response = await client.put(
        Uri.parse('$baseUrl/api/user/timezone'),
        headers: _headers(idToken),
        body: jsonEncode({'timezone': timezone}),
      );
    } catch (_) {
      throw const ReminderRequestFailed();
    }
    _checkStatus(response);
  }
}

/// The `YYYY-MM-DD` calendar-date string for [date]'s date components —
/// local to this file (not `shared/date/day_format.dart`, which pulls in
/// Flutter; infrastructure here stays a plain Dart + `http` adapter).
String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime _parseDateOnly(String s) {
  final parts = s.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}
