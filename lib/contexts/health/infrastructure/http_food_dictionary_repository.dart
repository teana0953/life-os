import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/diet_exceptions.dart';
import '../domain/food_dictionary_repository.dart';
import '../domain/food_item.dart';
import '../domain/shared_food_item_input.dart';
import '../domain/shared_food_item_patch.dart';

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
        Uri.parse(
          '$baseUrl/api/food-items',
        ).replace(queryParameters: {'q': query}),
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

  Map<String, String> _jsonHeaders(String idToken) => {
    ..._headers(idToken),
    'Content-Type': 'application/json',
  };

  @override
  Future<FoodItem> createSharedItem(
    String idToken,
    SharedFoodItemInput input,
  ) async {
    final response = await _send(
      () => client.post(
        Uri.parse('$baseUrl/api/admin/food-items'),
        headers: _jsonHeaders(idToken),
        body: jsonEncode(input.toJson()),
      ),
    );
    if (response.statusCode == 403) throw const DietForbidden();
    if (response.statusCode != 201) {
      throw DietFetchFailure(
        'Failed to create the item (status ${response.statusCode}).',
      );
    }
    return FoodItem.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  @override
  Future<FoodItem> updateSharedItem(
    String idToken,
    String id,
    SharedFoodItemPatch patch,
  ) async {
    final response = await _send(
      () => client.patch(
        Uri.parse('$baseUrl/api/admin/food-items/$id'),
        headers: _jsonHeaders(idToken),
        body: jsonEncode(patch.toJson()),
      ),
    );
    if (response.statusCode == 403) throw const DietForbidden();
    if (response.statusCode == 404) throw const DietNotFound();
    if (response.statusCode != 200) {
      throw DietFetchFailure(
        'Failed to update the item (status ${response.statusCode}).',
      );
    }
    return FoodItem.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
