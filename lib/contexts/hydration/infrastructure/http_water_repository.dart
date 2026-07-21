import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/water_day.dart';
import '../domain/water_exceptions.dart';
import '../domain/water_repository.dart';

/// [WaterRepository] driven adapter backed by the `/api/water` HTTP
/// endpoints.
class HttpWaterRepository implements WaterRepository {
  final String baseUrl;
  final http.Client client;

  HttpWaterRepository({required this.baseUrl, required this.client});

  static const _genericFailureMessage =
      'Unable to load your water data. Please try again.';

  Map<String, String> _headers(String idToken) => {
    'Authorization': 'Bearer $idToken',
    'Content-Type': 'application/json',
  };

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request();
    } catch (_) {
      throw const WaterFetchFailure(_genericFailureMessage);
    }
    if (response.statusCode == 401) {
      throw const WaterReauthenticationRequired();
    }
    return response;
  }

  @override
  Future<WaterDay> getDay(String idToken, String day) async {
    final response = await _send(
      () => client.get(
        Uri.parse('$baseUrl/api/water?day=$day'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) {
      throw WaterFetchFailure(
        'Failed to load the day\'s water (status ${response.statusCode}).',
      );
    }
    try {
      return WaterDay.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (_) {
      throw const WaterFetchFailure(_genericFailureMessage);
    }
  }

  @override
  Future<int> addWater(
    String idToken, {
    required String day,
    required int addMl,
  }) async {
    final response = await _send(
      () => client.post(
        Uri.parse('$baseUrl/api/water'),
        headers: _headers(idToken),
        body: jsonEncode({'day': day, 'add_ml': addMl}),
      ),
    );
    if (response.statusCode != 200) {
      throw WaterFetchFailure(
        'Failed to log water (status ${response.statusCode}).',
      );
    }
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return (json['total_ml'] as num).toInt();
    } catch (_) {
      throw const WaterFetchFailure(_genericFailureMessage);
    }
  }

  @override
  Future<int> setTarget(
    String idToken, {
    required String day,
    required int targetMl,
  }) async {
    final response = await _send(
      () => client.put(
        Uri.parse('$baseUrl/api/water/target'),
        headers: _headers(idToken),
        body: jsonEncode({'day': day, 'target_ml': targetMl}),
      ),
    );
    if (response.statusCode != 200) {
      throw WaterFetchFailure(
        'Failed to set the water target (status ${response.statusCode}).',
      );
    }
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return (json['target_ml'] as num).toInt();
    } catch (_) {
      throw const WaterFetchFailure(_genericFailureMessage);
    }
  }
}
