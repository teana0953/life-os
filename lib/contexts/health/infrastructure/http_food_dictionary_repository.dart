import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/diet_exceptions.dart';
import '../domain/food_dictionary_repository.dart';
import '../domain/food_item.dart';

/// [FoodDictionaryRepository] driven adapter backed by the
/// `/api/food-items` HTTP endpoints.
class HttpFoodDictionaryRepository implements FoodDictionaryRepository {
  final String baseUrl;
  final http.Client client;

  HttpFoodDictionaryRepository({required this.baseUrl, required this.client});

  static const _genericFailureMessage =
      'Unable to load the food dictionary. Please try again.';

  Map<String, String> _headers(String idToken) => {
    'Authorization': 'Bearer $idToken',
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

  List<FoodItem> _decodeItems(http.Response response) {
    if (response.statusCode != 200) {
      throw DietFetchFailure(
        'Failed to load food items (status ${response.statusCode}).',
      );
    }
    try {
      return (jsonDecode(response.body) as List)
          .map((e) => FoodItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      throw const DietFetchFailure(_genericFailureMessage);
    }
  }

  @override
  Future<List<FoodItem>> search(String idToken, String query) async {
    final response = await _send(
      () => client.get(
        Uri.parse('$baseUrl/api/food-items?q=$query'),
        headers: _headers(idToken),
      ),
    );
    return _decodeItems(response);
  }

  @override
  Future<List<FoodItem>> listFavorites(String idToken) async {
    final response = await _send(
      () => client.get(
        Uri.parse('$baseUrl/api/food-items/favorites'),
        headers: _headers(idToken),
      ),
    );
    return _decodeItems(response);
  }

  @override
  Future<void> favorite(String idToken, String foodItemId) async {
    final response = await _send(
      () => client.post(
        Uri.parse('$baseUrl/api/food-items/$foodItemId/favorite'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 204) {
      throw DietFetchFailure(
        'Failed to favorite the item (status ${response.statusCode}).',
      );
    }
  }

  @override
  Future<void> unfavorite(String idToken, String foodItemId) async {
    final response = await _send(
      () => client.delete(
        Uri.parse('$baseUrl/api/food-items/$foodItemId/favorite'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 204) {
      throw DietFetchFailure(
        'Failed to unfavorite the item (status ${response.statusCode}).',
      );
    }
  }
}
