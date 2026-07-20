import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/day_meals_log.dart';
import '../domain/diet_exceptions.dart';
import '../domain/meal_entry.dart';
import '../domain/meal_repository.dart';

/// [MealRepository] driven adapter backed by the `/api/meals` HTTP
/// endpoints. This PR's surface only: `getDayMeals`, `createMeal`,
/// `loggedDays` (PATCH/DELETE are PR③).
class HttpMealRepository implements MealRepository {
  final String baseUrl;
  final http.Client client;

  HttpMealRepository({required this.baseUrl, required this.client});

  static const _genericFailureMessage =
      'Unable to load your meals. Please try again.';

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

  Map<String, dynamic> _itemJson(CreateMealItem item) {
    return {
      'food_item_id': item.foodItemId,
      if (item.quantity != null) 'quantity': item.quantity,
      if (item.grams != null) 'grams': item.grams,
    };
  }

  @override
  Future<DayMealsLog> getDayMeals(String idToken, String day) async {
    final response = await _send(
      () => client.get(
        Uri.parse('$baseUrl/api/meals?day=$day'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) {
      throw DietFetchFailure(
        'Failed to load the day\'s meals (status ${response.statusCode}).',
      );
    }
    try {
      return DayMealsLog.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      throw const DietFetchFailure(_genericFailureMessage);
    }
  }

  @override
  Future<MealEntry> createMeal(
    String idToken, {
    required String day,
    required String meal,
    DateTime? time,
    required List<CreateMealItem> items,
  }) async {
    final body = <String, dynamic>{
      'day': day,
      'meal': meal,
      if (time != null) 'time': time.toUtc().toIso8601String(),
      'items': items.map(_itemJson).toList(),
    };
    final response = await _send(
      () => client.post(
        Uri.parse('$baseUrl/api/meals'),
        headers: _headers(idToken),
        body: jsonEncode(body),
      ),
    );
    if (response.statusCode != 201) {
      throw DietFetchFailure(
        'Failed to create the meal (status ${response.statusCode}).',
      );
    }
    try {
      return MealEntry.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      throw const DietFetchFailure(_genericFailureMessage);
    }
  }

  @override
  Future<List<String>> loggedDays(String idToken, String month) async {
    final response = await _send(
      () => client.get(
        Uri.parse('$baseUrl/api/meals/logged-days?month=$month'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) {
      throw DietFetchFailure(
        'Failed to load logged days (status ${response.statusCode}).',
      );
    }
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return (json['days'] as List).cast<String>();
    } catch (_) {
      throw const DietFetchFailure(_genericFailureMessage);
    }
  }
}
