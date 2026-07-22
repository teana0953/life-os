import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/contexts/body_profile/domain/body_profile_exceptions.dart';
import 'package:life_os/contexts/body_profile/infrastructure/http_body_profile_repository.dart';

void main() {
  group('HttpBodyProfileRepository', () {
    test('getWeightGoal GETs /api/weight-goal with a bearer token', () async {
      Uri? capturedUri;
      String? capturedAuth;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedAuth = request.headers['Authorization'];
        return http.Response(
          jsonEncode({
            'height_cm': 165,
            'target_weight_kg': 51,
            'current_weight_kg': 52,
            'remaining_kg': 1,
            'achievement_rate': 75,
            'bmi': 19.1,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final repository = HttpBodyProfileRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final goal = await repository.getWeightGoal('token-123');

      expect(capturedUri, Uri.parse('https://example.test/api/weight-goal'));
      expect(capturedAuth, 'Bearer token-123');
      expect(goal.targetWeightKg, 51);
      expect(goal.currentWeightKg, 52);
      expect(goal.remainingKg, 1);
      expect(goal.achievementRate, 75);
      expect(goal.bmi, 19.1);
    });

    test('getBodyProfile GETs /api/body-profile', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          jsonEncode({'height_cm': 165, 'target_weight_kg': 51}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final repository = HttpBodyProfileRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final profile = await repository.getBodyProfile('token-123');

      expect(capturedUri, Uri.parse('https://example.test/api/body-profile'));
      expect(profile.heightCm, 165);
      expect(profile.targetWeightKg, 51);
    });

    test('setBodyProfile PUTs only the height when only a height is given',
        () async {
      String? capturedMethod;
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedMethod = request.method;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(request.body, 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });
      final repository = HttpBodyProfileRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      await repository.setBodyProfile('token-123', heightCm: 165);

      expect(capturedMethod, 'PUT');
      expect(capturedBody, {'height_cm': 165});
    });

    test('setBodyProfile PUTs only the target when only a target is given',
        () async {
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(request.body, 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });
      final repository = HttpBodyProfileRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      await repository.setBodyProfile('token-123', targetWeightKg: 50);

      expect(capturedBody, {'target_weight_kg': 50});
    });

    test('setBodyProfile PUTs both fields when both are given', () async {
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(request.body, 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });
      final repository = HttpBodyProfileRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final saved = await repository.setBodyProfile(
        'token-123',
        heightCm: 165,
        targetWeightKg: 50,
      );

      expect(capturedBody, {'height_cm': 165, 'target_weight_kg': 50});
      expect(saved.heightCm, 165);
      expect(saved.targetWeightKg, 50);
    });

    test('throws BodyProfileReauthenticationRequired on 401', () async {
      final client = MockClient(
        (request) async => http.Response('Unauthorized', 401),
      );
      final repository = HttpBodyProfileRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.getWeightGoal('expired'),
        throwsA(isA<BodyProfileReauthenticationRequired>()),
      );
    });

    test('throws BodyProfileFetchFailure on other non-2xx responses', () async {
      final client = MockClient(
        (request) async => http.Response('Internal Server Error', 500),
      );
      final repository = HttpBodyProfileRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.getWeightGoal('token-123'),
        throwsA(isA<BodyProfileFetchFailure>()),
      );
    });

    test('throws BodyProfileFetchFailure (not a crash) on a network error',
        () async {
      final client = MockClient((request) async => throw Exception('offline'));
      final repository = HttpBodyProfileRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.getBodyProfile('token-123'),
        throwsA(isA<BodyProfileFetchFailure>()),
      );
    });
  });
}
