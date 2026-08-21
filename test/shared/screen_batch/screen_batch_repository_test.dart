import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/shared/screen_batch/screen_batch_exceptions.dart';
import 'package:life_os/shared/screen_batch/screen_batch_repository.dart';
import 'package:life_os/shared/screen_batch/section_outcome.dart';

import 'batch_fixtures.dart';

void main() {
  group('HttpScreenBatchRepository parameters', () {
    test('health-overview sends day, trend_days and care_days verbatim', () async {
      Uri? captured;
      String? auth;
      final client = MockClient((request) async {
        captured = request.url;
        auth = request.headers['Authorization'];
        return http.Response(jsonEncode(healthOverviewBody()), 200);
      });
      final repository = HttpScreenBatchRepository(
        baseUrl: 'https://api.test',
        client: client,
      );

      await repository.getHealthOverview(
        'token-1',
        day: '2026-08-20',
        trendDays: 90,
        careDays: 7,
      );

      expect(captured!.path, '/api/health-overview');
      expect(captured!.queryParameters['day'], '2026-08-20');
      expect(captured!.queryParameters['trend_days'], '90');
      expect(captured!.queryParameters['care_days'], '7');
      expect(auth, 'Bearer token-1');
    });

    test('home-summary sends day and trend_days verbatim', () async {
      Uri? captured;
      final client = MockClient((request) async {
        captured = request.url;
        return http.Response(jsonEncode(homeSummaryBody()), 200);
      });
      final repository = HttpScreenBatchRepository(
        baseUrl: 'https://api.test',
        client: client,
      );

      await repository.getHomeSummary(
        'token-1',
        day: '2026-08-20',
        trendDays: 366,
      );

      expect(captured!.path, '/api/home-summary');
      expect(captured!.queryParameters['day'], '2026-08-20');
      expect(captured!.queryParameters['trend_days'], '366');
      expect(captured!.queryParameters.containsKey('care_days'), isFalse);
    });

    // Out-of-range windows are a `400` on the backend, i.e. a client bug the
    // user would see as an inexplicably broken screen (design D5). Prevented
    // here rather than reported.
    test('windows outside 1..366 are clamped before they are sent', () async {
      final sent = <Uri>[];
      final client = MockClient((request) async {
        sent.add(request.url);
        return http.Response(jsonEncode(healthOverviewBody()), 200);
      });
      final repository = HttpScreenBatchRepository(
        baseUrl: 'https://api.test',
        client: client,
      );

      await repository.getHealthOverview(
        'token-1',
        day: '2026-08-20',
        trendDays: 4000,
        careDays: 0,
      );

      expect(sent.single.queryParameters['trend_days'], '366');
      expect(sent.single.queryParameters['care_days'], '1');
    });
  });

  group('HttpScreenBatchRepository outcomes', () {
    HttpScreenBatchRepository repositoryReturning(http.Response response) =>
        HttpScreenBatchRepository(
          baseUrl: 'https://api.test',
          client: MockClient((_) async => response),
        );

    Future<void> expectHealthThrows(
      http.Response response,
      Matcher matcher,
    ) async {
      await expectLater(
        repositoryReturning(response).getHealthOverview(
          't',
          day: '2026-08-20',
          trendDays: 30,
          careDays: 30,
        ),
        throwsA(matcher),
      );
    }

    test('a missing section key decodes as unavailable, not a throw', () async {
      final body = healthOverviewBody()..remove('bowel');
      final batch = await repositoryReturning(
        http.Response(jsonEncode(body), 200),
      ).getHealthOverview('t', day: '2026-08-20', trendDays: 30, careDays: 30);

      expect(batch.bowel, isA<SectionUnavailable>());
      expect(batch.water, isA<SectionOk>());
    });

    test('an all-ok:false 200 body decodes as fourteen unavailables', () async {
      final batch = await repositoryReturning(
        http.Response(jsonEncode(healthOverviewAllFailedBody()), 200),
      ).getHealthOverview('t', day: '2026-08-20', trendDays: 30, careDays: 30);

      expect(batch.weightGoal, isA<SectionUnavailable>());
      expect(batch.vitalsTrend, isA<SectionUnavailable>());
      expect(batch.healthCalendar, isA<SectionUnavailable>());
      expect(batch.meals, isA<SectionUnavailable>());
      expect(batch.dailyTarget, isA<SectionUnavailable>());
      expect(batch.favoriteFoodItems, isA<SectionUnavailable>());
      expect(batch.water, isA<SectionUnavailable>());
      expect(batch.bowel, isA<SectionUnavailable>());
      expect(batch.vitals, isA<SectionUnavailable>());
      expect(batch.exerciseActivities, isA<SectionUnavailable>());
      expect(batch.exercise, isA<SectionUnavailable>());
      expect(batch.menstrual, isA<SectionUnavailable>());
      expect(batch.careToday, isA<SectionUnavailable>());
      expect(batch.careRange, isA<SectionUnavailable>());
    });

    test('a section whose data cannot be decoded is unavailable alone', () async {
      final body = healthOverviewBody()
        ..['water'] = okSection({'day': '2026-08-20', 'total_ml': 'not a number'});
      final batch = await repositoryReturning(
        http.Response(jsonEncode(body), 200),
      ).getHealthOverview('t', day: '2026-08-20', trendDays: 30, careDays: 30);

      expect(batch.water, isA<SectionUnavailable>());
      expect(batch.bowel, isA<SectionOk>());
    });

    test('401 throws ScreenBatchReauthRequired', () async {
      await expectHealthThrows(
        http.Response('{"error":"unauthorized"}', 401),
        isA<ScreenBatchReauthRequired>(),
      );
    });

    test('500 throws ScreenBatchFetchFailure, never a reauth', () async {
      await expectHealthThrows(
        http.Response('boom', 500),
        isA<ScreenBatchFetchFailure>(),
      );
    });

    test('400 throws ScreenBatchFetchFailure, never a reauth', () async {
      await expectHealthThrows(
        http.Response('{"error":"bad_request"}', 400),
        isA<ScreenBatchFetchFailure>(),
      );
    });

    test('a transport throw becomes ScreenBatchFetchFailure', () async {
      final repository = HttpScreenBatchRepository(
        baseUrl: 'https://api.test',
        client: MockClient((_) async => throw const SocketFailure()),
      );

      await expectLater(
        repository.getHomeSummary('t', day: '2026-08-20', trendDays: 366),
        throwsA(isA<ScreenBatchFetchFailure>()),
      );
    });

    test('an undecodable 200 body becomes ScreenBatchFetchFailure', () async {
      await expectHealthThrows(
        http.Response('<html>not json</html>', 200),
        isA<ScreenBatchFetchFailure>(),
      );
    });
  });
}

class SocketFailure implements Exception {
  const SocketFailure();
}
