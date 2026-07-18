import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/daily_target.dart';
import '../domain/daily_target_repository.dart';
import '../domain/diet_exceptions.dart';

/// [DailyTargetRepository] driven adapter backed by the `/api/daily-target`
/// HTTP endpoints.
class HttpDailyTargetRepository implements DailyTargetRepository {
  final String baseUrl;
  final http.Client client;

  HttpDailyTargetRepository({required this.baseUrl, required this.client});

  static const _genericFailureMessage =
      'Unable to load your daily target. Please try again.';

  Map<String, String> _headers(String idToken) => {
    'Authorization': 'Bearer $idToken',
    'Content-Type': 'application/json',
  };

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request();
    } catch (_) {
      throw const DietFetchFailure(_genericFailureMessage);
    }
    if (response.statusCode == 401) {
      throw const DietReauthenticationRequired();
    }
    return response;
  }

  @override
  Future<DailyTargetWithRemaining> getTarget(String idToken, String day) async {
    final response = await _send(
      () => client.get(
        Uri.parse('$baseUrl/api/daily-target?day=$day'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) {
      throw DietFetchFailure(
        'Failed to load the daily target (status ${response.statusCode}).',
      );
    }
    try {
      return DailyTargetWithRemaining.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (_) {
      throw const DietFetchFailure(_genericFailureMessage);
    }
  }

  @override
  Future<DailyTarget> setTarget(
    String idToken, {
    required String day,
    required double baseStaple,
    required double baseMeat,
    required double baseFruit,
    required double baseVeg,
    double? bonusStaple,
    double? bonusMeat,
    double? bonusFruit,
    double? bonusVeg,
  }) async {
    final body = <String, dynamic>{
      'day': day,
      'base_staple': baseStaple,
      'base_meat': baseMeat,
      'base_fruit': baseFruit,
      'base_veg': baseVeg,
      if (bonusStaple != null) 'bonus_staple': bonusStaple,
      if (bonusMeat != null) 'bonus_meat': bonusMeat,
      if (bonusFruit != null) 'bonus_fruit': bonusFruit,
      if (bonusVeg != null) 'bonus_veg': bonusVeg,
    };
    final response = await _send(
      () => client.put(
        Uri.parse('$baseUrl/api/daily-target'),
        headers: _headers(idToken),
        body: jsonEncode(body),
      ),
    );
    if (response.statusCode != 200) {
      throw DietFetchFailure(
        'Failed to set the daily target (status ${response.statusCode}).',
      );
    }
    try {
      return DailyTarget.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      throw const DietFetchFailure(_genericFailureMessage);
    }
  }
}
