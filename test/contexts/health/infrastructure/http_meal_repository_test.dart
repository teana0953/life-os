import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/contexts/health/domain/diet_exceptions.dart';
import 'package:life_os/contexts/health/domain/meal_repository.dart';
import 'package:life_os/contexts/health/infrastructure/http_meal_repository.dart';

Map<String, dynamic> _itemJson() => {
  'id': 'item-1',
  'food_item_id': 'rice-1',
  'name': '飯/1碗',
  'photo_ref': null,
  'source': 'dict',
  'unclassified': false,
  'carb_g': 60,
  'protein_g': 4,
  'fat_g': 0.5,
  'sugar_g': 0,
  'fiber_g': 1,
  'kcal': 280,
  'staple': 4,
  'meat': 0,
  'fruit': 0,
  'veg': 0,
  'quantity': 1,
  'base_grams': null,
  'consumed': {
    'carb_g': 60,
    'protein_g': 4,
    'fat_g': 0.5,
    'sugar_g': 0,
    'fiber_g': 1,
    'kcal': 280,
    'staple': 4,
    'meat': 0,
    'fruit': 0,
    'veg': 0,
  },
};

Map<String, dynamic> _mealJson({bool withDay = false}) => {
  'id': 'meal-1',
  if (withDay) 'day': '2026-07-18',
  'meal': 'lunch',
  'time': '2026-07-18T12:30:00.000Z',
  'items': [_itemJson()],
};

void main() {
  group('HttpMealRepository', () {
    test('getDayMeals GETs {baseUrl}/api/meals?day= and parses the flat totals + day-less meal items', () async {
      Uri? capturedUri;
      String? capturedAuthHeader;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedAuthHeader = request.headers['Authorization'];
        return http.Response(
          jsonEncode({
            'day': '2026-07-18',
            'meals': [_mealJson()],
            'totals': {
              'carb_g': 60,
              'protein_g': 4,
              'fat_g': 0.5,
              'sugar_g': 0,
              'fiber_g': 1,
              'kcal': 280,
              'staple': 4,
              'meat': 0,
              'fruit': 0,
              'veg': 0,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final repository = HttpMealRepository(baseUrl: 'https://example.test', client: client);

      final log = await repository.getDayMeals('token-123', '2026-07-18');

      expect(capturedUri, Uri.parse('https://example.test/api/meals?day=2026-07-18'));
      expect(capturedAuthHeader, 'Bearer token-123');
      expect(log.day, '2026-07-18');
      expect(log.meals.single.meal, 'lunch');
      expect(log.meals.single.items.single.consumed.staple, 4);
      expect(log.totals.staple, 4);
    });

    test('createMeal POSTs {baseUrl}/api/meals with a quantity item', () async {
      Uri? capturedUri;
      Map<String, dynamic>? capturedBody;
      String? capturedAuthHeader;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedAuthHeader = request.headers['Authorization'];
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(_mealJson(withDay: true)),
          201,
          headers: {'content-type': 'application/json'},
        );
      });
      final repository = HttpMealRepository(baseUrl: 'https://example.test', client: client);

      final meal = await repository.createMeal(
        'token-123',
        day: '2026-07-18',
        meal: 'lunch',
        items: [CreateMealItem.dictionary('rice-1', quantity: 1.5)],
      );

      expect(capturedUri, Uri.parse('https://example.test/api/meals'));
      expect(capturedAuthHeader, 'Bearer token-123');
      expect(capturedBody, {
        'day': '2026-07-18',
        'meal': 'lunch',
        'items': [
          {'food_item_id': 'rice-1', 'quantity': 1.5},
        ],
      });
      expect(meal.id, 'meal-1');
    });

    test('createMeal sends grams (never quantity) for a gram-mode item, and time when given', () async {
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(_mealJson(withDay: true)),
          201,
          headers: {'content-type': 'application/json'},
        );
      });
      final repository = HttpMealRepository(baseUrl: 'https://example.test', client: client);

      await repository.createMeal(
        'token-123',
        day: '2026-07-18',
        meal: 'breakfast',
        time: DateTime.utc(2026, 7, 18, 8),
        items: [CreateMealItem.dictionary('rice-1', grams: 33)],
      );

      expect(capturedBody, {
        'day': '2026-07-18',
        'meal': 'breakfast',
        'time': '2026-07-18T08:00:00.000Z',
        'items': [
          {'food_item_id': 'rice-1', 'grams': 33.0},
        ],
      });
      // grams and quantity are mutually exclusive on the wire.
      final item = (capturedBody!['items'] as List).single as Map<String, dynamic>;
      expect(item.containsKey('quantity'), isFalse);
    });

    test('createMeal throws DietFetchFailure on a non-201 response', () async {
      final client = MockClient((request) async => http.Response('Internal Server Error', 500));
      final repository = HttpMealRepository(baseUrl: 'https://example.test', client: client);

      expect(
        () => repository.createMeal(
          'token-123',
          day: '2026-07-18',
          meal: 'lunch',
          items: [CreateMealItem.dictionary('rice-1', quantity: 1)],
        ),
        throwsA(isA<DietFetchFailure>()),
      );
    });

    test('createMeal throws DietReauthenticationRequired on 401', () async {
      final client = MockClient((request) async => http.Response('Unauthorized', 401));
      final repository = HttpMealRepository(baseUrl: 'https://example.test', client: client);

      expect(
        () => repository.createMeal(
          'token-123',
          day: '2026-07-18',
          meal: 'lunch',
          items: [CreateMealItem.dictionary('rice-1', quantity: 1)],
        ),
        throwsA(isA<DietReauthenticationRequired>()),
      );
    });

    test('loggedDays GETs {baseUrl}/api/meals/logged-days?month= and parses days', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          jsonEncode({'days': ['2026-07-01', '2026-07-15']}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final repository = HttpMealRepository(baseUrl: 'https://example.test', client: client);

      final days = await repository.loggedDays('token-123', '2026-07');

      expect(capturedUri, Uri.parse('https://example.test/api/meals/logged-days?month=2026-07'));
      expect(days, ['2026-07-01', '2026-07-15']);
    });

    test('loggedDays throws DietReauthenticationRequired on 401', () async {
      final client = MockClient((request) async => http.Response('Unauthorized', 401));
      final repository = HttpMealRepository(baseUrl: 'https://example.test', client: client);

      expect(
        () => repository.loggedDays('expired-token', '2026-07'),
        throwsA(isA<DietReauthenticationRequired>()),
      );
    });

    test('getDayMeals throws DietFetchFailure on other non-2xx responses', () async {
      final client = MockClient((request) async => http.Response('Internal Server Error', 500));
      final repository = HttpMealRepository(baseUrl: 'https://example.test', client: client);

      expect(
        () => repository.getDayMeals('token-123', '2026-07-18'),
        throwsA(isA<DietFetchFailure>()),
      );
    });

    test('getDayMeals throws DietReauthenticationRequired on 401', () async {
      final client = MockClient((request) async => http.Response('Unauthorized', 401));
      final repository = HttpMealRepository(baseUrl: 'https://example.test', client: client);

      expect(
        () => repository.getDayMeals('expired-token', '2026-07-18'),
        throwsA(isA<DietReauthenticationRequired>()),
      );
    });
  });
}
