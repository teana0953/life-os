import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/care_item.dart';

/// [CareItemRepository] driven adapter backed by the `/api/care/items` HTTP
/// endpoints. `list` parses the `{ items: [...] }` envelope; `create`/
/// `update` parse a bare returned item (design D1 — the Slice-2b blocking bug
/// was parsing a bare array where the backend actually returns an envelope;
/// avoided here by matching the confirmed shapes exactly).
class HttpCareRepository implements CareItemRepository {
  final String baseUrl;
  final http.Client client;

  HttpCareRepository({required this.baseUrl, required this.client});

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

  Map<String, dynamic> _scheduleBody(CareSchedule schedule) {
    final body = <String, dynamic>{
      if (schedule.id != null) 'id': schedule.id,
      'time_of_day': schedule.timeOfDay,
      'repeat_days': schedule.repeatDays,
      'week_interval': schedule.weekInterval,
      // Date-only — never `toIso8601String()` (design D3; a naive
      // local/UTC time component would 400 the backend). REQUIRED on every
      // schedule regardless of category (design D3's Slice-2b trap).
      'start_date': _dateOnly(schedule.startDate),
      // REQUIRED on every schedule regardless of category (design D2's
      // Slice-2b trap) — always sent, defaulting to 1 when its editor is
      // hidden for non-medication.
      'dose_quantity': schedule.doseQuantity,
      'nag_interval_minutes': schedule.nagIntervalMinutes,
      'enabled': schedule.enabled,
    };
    if (schedule.endDate != null) {
      body['end_date'] = _dateOnly(schedule.endDate!);
    }
    return body;
  }

  Map<String, dynamic> _itemBody({
    required CareCategory category,
    required String title,
    required String? note,
    required String? dose,
    required double? stock,
    required double? stockAlert,
    required List<CareSchedule> schedules,
  }) {
    final body = <String, dynamic>{
      // The wire enum string, never a localized label (design D2's
      // Slice-2b trap).
      'category': category.wireValue,
      'title': title,
      'note': note,
      'schedules': schedules.map(_scheduleBody).toList(),
    };
    // Item-level dose/stock/stock_alert are medication-only — omitted for
    // every other category (design D2).
    if (category == CareCategory.medication) {
      body['dose'] = dose;
      body['stock'] = stock;
      body['stock_alert'] = stockAlert;
    }
    return body;
  }

  CareSchedule _parseSchedule(Map<String, dynamic> json) => CareSchedule(
    id: json['id'] as String?,
    timeOfDay: json['time_of_day'] as String,
    repeatDays: (json['repeat_days'] as List).map((e) => e as int).toList(),
    weekInterval: json['week_interval'] as int,
    startDate: _parseDateOnly(json['start_date'] as String),
    endDate: json['end_date'] != null
        ? _parseDateOnly(json['end_date'] as String)
        : null,
    doseQuantity: (json['dose_quantity'] as num).toDouble(),
    nagIntervalMinutes: json['nag_interval_minutes'] as int,
    enabled: json['enabled'] as bool,
  );

  CareItem _parseItem(Map<String, dynamic> json) => CareItem(
    id: json['id'] as String,
    category: careCategoryFromWire(json['category'] as String),
    title: json['title'] as String,
    note: json['note'] as String?,
    dose: json['dose'] as String?,
    stock: (json['stock'] as num?)?.toDouble(),
    stockAlert: (json['stock_alert'] as num?)?.toDouble(),
    schedules: (json['schedules'] as List)
        .map((e) => _parseSchedule(e as Map<String, dynamic>))
        .toList(),
  );

  @override
  Future<List<CareItem>> list(String idToken) async {
    final http.Response response;
    try {
      response = await client.get(
        Uri.parse('$baseUrl/api/care/items'),
        headers: _headers(idToken),
      );
    } catch (_) {
      throw const CareRequestFailed();
    }
    _checkStatus(response);
    try {
      final envelope = jsonDecode(response.body) as Map<String, dynamic>;
      final json = envelope['items'] as List;
      return json.map((e) => _parseItem(e as Map<String, dynamic>)).toList();
    } catch (_) {
      throw const CareRequestFailed();
    }
  }

  @override
  Future<CareItem> create(String idToken, CareItemDraft draft) async {
    final http.Response response;
    try {
      response = await client.post(
        Uri.parse('$baseUrl/api/care/items'),
        headers: _headers(idToken),
        body: jsonEncode(
          _itemBody(
            category: draft.category,
            title: draft.title,
            note: draft.note,
            dose: draft.dose,
            stock: draft.stock,
            stockAlert: draft.stockAlert,
            schedules: draft.schedules,
          ),
        ),
      );
    } catch (_) {
      throw const CareRequestFailed();
    }
    _checkStatus(response);
    try {
      return _parseItem(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      throw const CareRequestFailed();
    }
  }

  @override
  Future<CareItem> update(
    String idToken,
    String id,
    CareItemUpdate changes,
  ) async {
    final http.Response response;
    try {
      response = await client.patch(
        Uri.parse('$baseUrl/api/care/items/$id'),
        headers: _headers(idToken),
        body: jsonEncode(
          _itemBody(
            category: changes.category,
            title: changes.title,
            note: changes.note,
            dose: changes.dose,
            stock: changes.stock,
            stockAlert: changes.stockAlert,
            schedules: changes.schedules,
          ),
        ),
      );
    } catch (_) {
      throw const CareRequestFailed();
    }
    // A PATCH 404 (`{error:"not_found"}`) falls through to CareRequestFailed
    // via the generic non-2xx check below.
    _checkStatus(response);
    try {
      return _parseItem(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      throw const CareRequestFailed();
    }
  }

  @override
  Future<void> delete(String idToken, String id) async {
    final http.Response response;
    try {
      response = await client.delete(
        Uri.parse('$baseUrl/api/care/items/$id'),
        headers: _headers(idToken),
      );
    } catch (_) {
      throw const CareRequestFailed();
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
