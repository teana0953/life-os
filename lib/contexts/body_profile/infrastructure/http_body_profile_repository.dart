import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/body_profile_exceptions.dart';
import '../domain/body_profile_repository.dart';
import '../domain/weight_goal.dart';

/// [BodyProfileRepository] driven adapter backed by the `/api/weight-goal` and
/// `/api/body-profile` HTTP endpoints.
class HttpBodyProfileRepository implements BodyProfileRepository {
  final String baseUrl;
  final http.Client client;

  HttpBodyProfileRepository({required this.baseUrl, required this.client});

  Map<String, String> _headers(String idToken) => {
    'Authorization': 'Bearer $idToken',
    'Content-Type': 'application/json',
  };

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request();
    } catch (_) {
      throw const BodyProfileFetchFailure();
    }
    if (response.statusCode == 401) {
      throw const BodyProfileReauthenticationRequired();
    }
    return response;
  }

  @override
  Future<WeightGoal> getWeightGoal(String idToken) async {
    final response = await _send(
      () => client.get(
        Uri.parse('$baseUrl/api/weight-goal'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) throw const BodyProfileFetchFailure();
    try {
      return WeightGoal.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (_) {
      throw const BodyProfileFetchFailure();
    }
  }

  @override
  Future<BodyProfile> getBodyProfile(String idToken) async {
    final response = await _send(
      () => client.get(
        Uri.parse('$baseUrl/api/body-profile'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) throw const BodyProfileFetchFailure();
    try {
      return BodyProfile.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (_) {
      throw const BodyProfileFetchFailure();
    }
  }

  @override
  Future<BodyProfile> setBodyProfile(
    String idToken, {
    double? heightCm,
    double? targetWeightKg,
  }) async {
    // Partial update: only the provided (non-null) fields are sent, so an
    // untouched field is left unchanged on the backend.
    final body = <String, dynamic>{
      if (heightCm != null) 'height_cm': heightCm,
      if (targetWeightKg != null) 'target_weight_kg': targetWeightKg,
    };
    final response = await _send(
      () => client.put(
        Uri.parse('$baseUrl/api/body-profile'),
        headers: _headers(idToken),
        body: jsonEncode(body),
      ),
    );
    if (response.statusCode != 200) throw const BodyProfileFetchFailure();
    try {
      return BodyProfile.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (_) {
      throw const BodyProfileFetchFailure();
    }
  }
}
