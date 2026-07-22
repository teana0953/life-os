import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/contexts/exercise/domain/exercise_exceptions.dart';
import 'package:life_os/contexts/exercise/infrastructure/http_exercise_repository.dart';

http.Response _json(Object body, int status) => http.Response(
  body is String ? body : jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  group('HttpExerciseRepository', () {
    test('listActivities GETs /api/exercise/activities and unwraps the '
        'envelope with a bearer token', () async {
      Uri? capturedUri;
      String? capturedAuth;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedAuth = request.headers['Authorization'];
        return _json({
          'activities': [
            {
              'id': 'jogging',
              'name': '慢跑',
              'category': 'aerobic',
              'intensity': '8km/hr',
            },
            {
              'id': 'yoga',
              'name': '瑜伽',
              'category': 'anaerobic',
              'intensity': '',
            },
          ],
        }, 200);
      });
      final repo = HttpExerciseRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final activities = await repo.listActivities('token-123');

      expect(capturedUri, Uri.parse('https://example.test/api/exercise/activities'));
      expect(capturedAuth, 'Bearer token-123');
      expect(activities, hasLength(2));
      expect(activities.first.id, 'jogging');
      expect(activities.first.category, 'aerobic');
    });

    test('getDay GETs /api/exercise?day= and maps the entries + total', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return _json({
          'day': '2026-07-18',
          'entries': [
            {
              'id': 'e1',
              'activity_id': 'jogging',
              'activity_name': '慢跑',
              'category': 'aerobic',
              'duration_minutes': 30,
              'note': 'run',
              'created_at': '2026-07-18T09:00:00.000Z',
            },
          ],
          'total_minutes': 30,
        }, 200);
      });
      final repo = HttpExerciseRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final day = await repo.getDay('tok', '2026-07-18');

      expect(capturedUri, Uri.parse('https://example.test/api/exercise?day=2026-07-18'));
      expect(day.entries.single.activityName, '慢跑');
      expect(day.totalMinutes, 30);
    });

    test('addEntry POSTs the snake_case body and returns the created entry',
        () async {
      String? capturedMethod;
      Uri? capturedUri;
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _json({
          'id': 'e1',
          'activity_id': 'jogging',
          'activity_name': '慢跑',
          'category': 'aerobic',
          'duration_minutes': 30,
          'note': 'run',
          'created_at': '2026-07-18T09:00:00.000Z',
        }, 200);
      });
      final repo = HttpExerciseRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final entry = await repo.addEntry(
        'tok',
        day: '2026-07-18',
        activityId: 'jogging',
        durationMinutes: 30,
        note: 'run',
      );

      expect(capturedMethod, 'POST');
      expect(capturedUri, Uri.parse('https://example.test/api/exercise'));
      expect(capturedBody, {
        'day': '2026-07-18',
        'activity_id': 'jogging',
        'duration_minutes': 30,
        'note': 'run',
      });
      expect(entry.id, 'e1');
      expect(entry.durationMinutes, 30);
    });

    test('deleteEntry DELETEs /api/exercise/:id and returns the deleted flag',
        () async {
      String? capturedMethod;
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        return _json({'deleted': true}, 200);
      });
      final repo = HttpExerciseRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final deleted = await repo.deleteEntry('tok', 'e1');

      expect(capturedMethod, 'DELETE');
      expect(capturedUri, Uri.parse('https://example.test/api/exercise/e1'));
      expect(deleted, isTrue);
    });

    test('a non-200 response throws ExerciseFetchFailure', () async {
      final client = MockClient((request) async => _json({'error': 'boom'}, 500));
      final repo = HttpExerciseRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repo.getDay('tok', '2026-07-18'),
        throwsA(isA<ExerciseFetchFailure>()),
      );
    });

    test('a 401 throws ExerciseReauthenticationRequired', () async {
      final client = MockClient((request) async => _json({'error': 'unauth'}, 401));
      final repo = HttpExerciseRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repo.getDay('tok', '2026-07-18'),
        throwsA(isA<ExerciseReauthenticationRequired>()),
      );
    });
  });
}
