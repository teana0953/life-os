import 'dart:convert';

import 'package:http/http.dart' as http;

import 'health_overview_batch.dart';
import 'home_summary_batch.dart';
import 'screen_batch_exceptions.dart';

/// Reads a whole screen in one request.
///
/// A port rather than a bare class so widget tests can drive the two screens
/// from decoded fixtures without standing up an HTTP fake; the shipped
/// implementation is [HttpScreenBatchRepository].
abstract class ScreenBatchRepository {
  Future<HealthOverviewBatch> getHealthOverview(
    String idToken, {
    required String day,
    required int trendDays,
    required int careDays,
  });

  Future<HomeSummaryBatch> getHomeSummary(
    String idToken, {
    required String day,
    required int trendDays,
  });
}

/// The backend's window parameters are constrained to `1..366`; anything
/// outside is a `400`, which would be a client bug rather than a user-visible
/// mode (design D5), so it is prevented at source here.
int clampWindowDays(int days) => days < 1 ? 1 : (days > 366 ? 366 : days);

/// [ScreenBatchRepository] driven adapter backed by `GET /api/health-overview`
/// and `GET /api/home-summary`.
///
/// Built with the ordinary 15s [TimeoutClient] every other repository uses,
/// not the 120s long-running one (design D10): the backend fuses each section
/// at 8s, so a pathological response is bounded server-side well inside this
/// client's deadline.
class HttpScreenBatchRepository implements ScreenBatchRepository {
  final String baseUrl;
  final http.Client client;

  HttpScreenBatchRepository({required this.baseUrl, required this.client});

  Map<String, String> _headers(String idToken) => {
    'Authorization': 'Bearer $idToken',
    'Content-Type': 'application/json',
  };

  Future<Map<String, dynamic>> _get(String url, String idToken) async {
    final http.Response response;
    try {
      response = await client.get(Uri.parse(url), headers: _headers(idToken));
    } catch (_) {
      throw const ScreenBatchFetchFailure();
    }
    if (response.statusCode == 401) throw const ScreenBatchReauthRequired();
    if (response.statusCode != 200) {
      throw ScreenBatchFetchFailure(
        'Failed to load the screen (status ${response.statusCode}).',
      );
    }
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const ScreenBatchFetchFailure();
    }
  }

  @override
  Future<HealthOverviewBatch> getHealthOverview(
    String idToken, {
    required String day,
    required int trendDays,
    required int careDays,
  }) async {
    final json = await _get(
      '$baseUrl/api/health-overview'
      '?day=$day'
      '&trend_days=${clampWindowDays(trendDays)}'
      '&care_days=${clampWindowDays(careDays)}',
      idToken,
    );
    return HealthOverviewBatch.fromJson(json);
  }

  @override
  Future<HomeSummaryBatch> getHomeSummary(
    String idToken, {
    required String day,
    required int trendDays,
  }) async {
    final json = await _get(
      '$baseUrl/api/home-summary'
      '?day=$day'
      '&trend_days=${clampWindowDays(trendDays)}',
      idToken,
    );
    return HomeSummaryBatch.fromJson(json);
  }
}
