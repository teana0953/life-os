import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/contexts/health/domain/diet_exceptions.dart';
import 'package:life_os/contexts/health/infrastructure/http_food_dictionary_repository.dart';

Map<String, dynamic> _riceItemJson() => {
  'id': 'rice-1',
  'owner_user_id': null,
  'name': '飯/1碗',
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
  'base_amount': null,
  'measure_unit': null,
};

void main() {
  group('HttpFoodDictionaryRepository', () {
    test('search GETs {baseUrl}/api/food-items?q= with a bearer token', () async {
      Uri? capturedUri;
      String? capturedAuthHeader;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedAuthHeader = request.headers['Authorization'];
        return http.Response(jsonEncode([_riceItemJson()]), 200, headers: {'content-type': 'application/json'});
      });
      final repository = HttpFoodDictionaryRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final items = await repository.search('token-123', '飯');

      expect(capturedUri, Uri.parse('https://example.test/api/food-items?q=飯'));
      expect(capturedAuthHeader, 'Bearer token-123');
      expect(items.single.name, '飯/1碗');
    });

    test(
      'search percent-encodes the query so spaces and reserved characters '
      '(&, #) are not misinterpreted as URL syntax',
      () async {
        Uri? capturedUri;
        final client = MockClient((request) async {
          capturedUri = request.url;
          return http.Response(
            jsonEncode(<Map<String, dynamic>>[]),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        final repository = HttpFoodDictionaryRepository(
          baseUrl: 'https://example.test',
          client: client,
        );

        const query = '雞胸肉 & 沙拉#1';
        await repository.search('token-123', query);

        expect(capturedUri!.queryParameters, {'q': query});
      },
    );

    test('listFavorites GETs {baseUrl}/api/food-items/favorites', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(jsonEncode([_riceItemJson()]), 200, headers: {'content-type': 'application/json'});
      });
      final repository = HttpFoodDictionaryRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final items = await repository.listFavorites('token-123');

      expect(capturedUri, Uri.parse('https://example.test/api/food-items/favorites'));
      expect(items.single.id, 'rice-1');
    });

    test('favorite POSTs {baseUrl}/api/food-items/:id/favorite', () async {
      Uri? capturedUri;
      String? capturedMethod;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        return http.Response('', 204);
      });
      final repository = HttpFoodDictionaryRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      await repository.favorite('token-123', 'rice-1');

      expect(capturedUri, Uri.parse('https://example.test/api/food-items/rice-1/favorite'));
      expect(capturedMethod, 'POST');
    });

    test('unfavorite DELETEs {baseUrl}/api/food-items/:id/favorite', () async {
      Uri? capturedUri;
      String? capturedMethod;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        return http.Response('', 204);
      });
      final repository = HttpFoodDictionaryRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      await repository.unfavorite('token-123', 'rice-1');

      expect(capturedUri, Uri.parse('https://example.test/api/food-items/rice-1/favorite'));
      expect(capturedMethod, 'DELETE');
    });

    test('throws DietReauthenticationRequired on 401', () async {
      final client = MockClient((request) async => http.Response('Unauthorized', 401));
      final repository = HttpFoodDictionaryRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.search('expired-token', ''),
        throwsA(isA<DietReauthenticationRequired>()),
      );
    });

    test('throws DietFetchFailure on other non-2xx responses without leaking detail', () async {
      final client = MockClient((request) async => http.Response('Internal Server Error', 500));
      final repository = HttpFoodDictionaryRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      try {
        await repository.search('token-123', '');
        fail('expected DietFetchFailure');
      } catch (e) {
        expect(e, isA<DietFetchFailure>());
      }
    });

    test('wraps network exceptions in DietFetchFailure without leaking detail', () async {
      final client = MockClient((request) async {
        throw http.ClientException('Connection refused at 10.0.0.5:443');
      });
      final repository = HttpFoodDictionaryRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      try {
        await repository.search('token-123', '');
        fail('expected DietFetchFailure');
      } catch (e) {
        expect(e, isA<DietFetchFailure>());
        expect((e as DietFetchFailure).message, isNot(contains('10.0.0.5')));
      }
    });
  });
}
