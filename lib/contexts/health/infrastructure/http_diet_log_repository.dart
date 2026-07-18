import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/day_diet_log.dart';
import '../domain/diet_exceptions.dart';
import '../domain/diet_log_repository.dart';
import '../domain/food_entry.dart';
import '../domain/portions.dart';

/// [DietLogRepository] driven adapter backed by the `/api/diet-entries`
/// HTTP endpoints.
class HttpDietLogRepository implements DietLogRepository {
  final String baseUrl;
  final http.Client client;

  HttpDietLogRepository({required this.baseUrl, required this.client});

  static const _genericFailureMessage =
      'Unable to load your diet log. Please try again.';

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
  Future<FoodEntry> logFromDictionary(
    String idToken, {
    required String day,
    required String meal,
    required String foodItemId,
    double? quantity,
    double? grams,
    DateTime? eatenAt,
  }) async {
    final body = <String, dynamic>{
      'day': day,
      'meal': meal,
      'food_item_id': foodItemId,
      if (quantity != null) 'quantity': quantity,
      if (grams != null) 'grams': grams,
      if (eatenAt != null) 'eaten_at': eatenAt.toUtc().toIso8601String(),
    };
    final response = await _send(
      () => client.post(
        Uri.parse('$baseUrl/api/diet-entries'),
        headers: _headers(idToken),
        body: jsonEncode(body),
      ),
    );
    if (response.statusCode != 201) {
      throw DietFetchFailure(
        'Failed to log the food entry (status ${response.statusCode}).',
      );
    }
    try {
      return FoodEntry.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      throw const DietFetchFailure(_genericFailureMessage);
    }
  }

  @override
  Future<FoodEntry> logManualEntry(
    String idToken, {
    required String day,
    required String meal,
    String? name,
    required Portions portions,
    required DateTime eatenAt,
  }) async {
    final body = <String, dynamic>{
      'day': day,
      'meal': meal,
      if (name != null) 'name': name,
      'portions': {
        'staple': portions.staple,
        'meat': portions.meat,
        'fruit': portions.fruit,
        'veg': portions.veg,
      },
      'eaten_at': eatenAt.toUtc().toIso8601String(),
    };
    final response = await _send(
      () => client.post(
        Uri.parse('$baseUrl/api/diet-entries'),
        headers: _headers(idToken),
        body: jsonEncode(body),
      ),
    );
    if (response.statusCode != 201) {
      throw DietFetchFailure(
        'Failed to log the food entry (status ${response.statusCode}).',
      );
    }
    try {
      return FoodEntry.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      throw const DietFetchFailure(_genericFailureMessage);
    }
  }

  @override
  Future<DayDietLog> getDayLog(String idToken, String day) async {
    final response = await _send(
      () => client.get(
        Uri.parse('$baseUrl/api/diet-entries?day=$day'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) {
      throw DietFetchFailure(
        'Failed to load the day\'s diet log (status ${response.statusCode}).',
      );
    }
    try {
      return DayDietLog.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      throw const DietFetchFailure(_genericFailureMessage);
    }
  }

  @override
  Future<void> deleteEntry(String idToken, String entryId) async {
    final response = await _send(
      () => client.delete(
        Uri.parse('$baseUrl/api/diet-entries/$entryId'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 204) {
      throw DietFetchFailure(
        'Failed to delete the entry (status ${response.statusCode}).',
      );
    }
  }
}
