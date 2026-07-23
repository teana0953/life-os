import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/contexts/vitals/domain/vitals_day.dart';
import 'package:life_os/contexts/vitals/domain/vitals_exceptions.dart';
import 'package:life_os/contexts/vitals/infrastructure/http_vitals_repository.dart';

void main() {
  group('HttpVitalsRepository', () {
    test('getDay GETs {baseUrl}/api/vitals?day= with a bearer token', () async {
      Uri? capturedUri;
      String? capturedAuthHeader;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedAuthHeader = request.headers['Authorization'];
        return http.Response(
          jsonEncode({
            'day': '2026-07-18',
            'weight_kg': 65.5,
            'body_fat_pct': 20,
            'bp_readings': [
              {'systolic': 120, 'diastolic': 80, 'pulse': 70, 'time': '08:30'},
              {
                'systolic': 118,
                'diastolic': 78,
                'pulse': null,
                'time': '09:15',
              },
            ],
            'glucose_readings': [
              {'label': '餐前', 'value': 95, 'time': '07:45'},
            ],
            'spo2_readings': [
              {'spo2': 98, 'pulse': null, 'time': '10:00'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final repository = HttpVitalsRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final day = await repository.getDay('token-123', '2026-07-18');

      expect(
        capturedUri,
        Uri.parse('https://example.test/api/vitals?day=2026-07-18'),
      );
      expect(capturedAuthHeader, 'Bearer token-123');
      expect(day.weightKg, 65.5);
      expect(day.bpReadings.length, 2);
      // The null pulse round-trips.
      expect(day.bpReadings[1].pulse, isNull);
      // The time round-trips on each reading type.
      expect(day.bpReadings[0].time, '08:30');
      expect(day.glucoseReadings.single.label, '餐前');
      expect(day.glucoseReadings.single.time, '07:45');
      expect(day.spo2Readings.single.pulse, isNull);
      expect(day.spo2Readings.single.time, '10:00');
    });

    test('save PUTs the full snake_case body and returns the saved record',
        () async {
      Uri? capturedUri;
      String? capturedMethod;
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          request.body,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final repository = HttpVitalsRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final saved = await repository.save(
        'token-123',
        const VitalsDay(
          day: '2026-07-18',
          weightKg: 65.5,
          bodyFatPct: null,
          bpReadings: [
            BpReading(systolic: 120, diastolic: 80, pulse: null, time: '08:30'),
          ],
          glucoseReadings: [
            GlucoseReading(label: '餐後', value: 110, mealContext: null, time: '12:30'),
          ],
          spo2Readings: [Spo2Reading(spo2: 97, pulse: 66, time: '22:05')],
        ),
      );

      expect(capturedUri, Uri.parse('https://example.test/api/vitals'));
      expect(capturedMethod, 'PUT');
      expect(capturedBody!['weight_kg'], 65.5);
      expect(capturedBody!['body_fat_pct'], isNull);
      expect((capturedBody!['bp_readings'] as List).single, {
        'systolic': 120,
        'diastolic': 80,
        'pulse': null,
        'time': '08:30',
      });
      expect((capturedBody!['glucose_readings'] as List).single, {
        'label': '餐後',
        'value': 110,
        'meal_context': null,
        'time': '12:30',
      });
      // The saved record parses back, including the three arrays.
      expect(saved.weightKg, 65.5);
      expect(saved.bpReadings.single.pulse, isNull);
      expect(saved.spo2Readings.single.pulse, 66);
    });

    test('getRange GETs /api/vitals/range?from=&to= and maps the series',
        () async {
      Uri? capturedUri;
      String? capturedAuthHeader;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedAuthHeader = request.headers['Authorization'];
        return http.Response(
          jsonEncode({
            'from': '2026-07-01',
            'to': '2026-07-03',
            'series': {
              'weight': [
                {'day': '2026-07-01', 'value': 65.5},
                {'day': '2026-07-03', 'value': 65.0},
              ],
              'body_fat': [
                {'day': '2026-07-01', 'value': 20},
              ],
              'systolic': [
                {'day': '2026-07-02', 'value': 120},
              ],
              'diastolic': [
                {'day': '2026-07-02', 'value': 80},
              ],
              'pulse': [
                {'day': '2026-07-02', 'value': 70},
              ],
              'glucose': [
                {'day': '2026-07-01', 'value': 95},
              ],
              'spo2': [
                {'day': '2026-07-01', 'value': 98},
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final repository = HttpVitalsRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      final range = await repository.getRange(
        'token-123',
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 3),
      );

      expect(
        capturedUri,
        Uri.parse(
          'https://example.test/api/vitals/range?from=2026-07-01&to=2026-07-03',
        ),
      );
      expect(capturedAuthHeader, 'Bearer token-123');
      expect(range.from, DateTime(2026, 7, 1));
      expect(range.to, DateTime(2026, 7, 3));
      expect(range.series.weight.length, 2);
      expect(range.series.weight.first.value, 65.5);
      expect(range.series.bodyFat.single.value, 20);
      expect(range.series.spo2.single.value, 98);
    });

    test('getRange formats single-digit month/day as zero-padded YYYY-MM-DD',
        () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          jsonEncode({'from': '2026-03-05', 'to': '2026-03-09', 'series': {}}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final repository = HttpVitalsRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      await repository.getRange(
        'token-123',
        DateTime(2026, 3, 5),
        DateTime(2026, 3, 9),
      );

      expect(
        capturedUri,
        Uri.parse(
          'https://example.test/api/vitals/range?from=2026-03-05&to=2026-03-09',
        ),
      );
    });

    test('getRange throws VitalsReauthenticationRequired on 401', () async {
      final client = MockClient(
        (request) async => http.Response('Unauthorized', 401),
      );
      final repository = HttpVitalsRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () =>
            repository.getRange('expired', DateTime(2026, 7, 1), DateTime(2026, 7, 3)),
        throwsA(isA<VitalsReauthenticationRequired>()),
      );
    });

    test('getRange throws VitalsFetchFailure on other non-2xx responses',
        () async {
      final client = MockClient(
        (request) async => http.Response('Internal Server Error', 500),
      );
      final repository = HttpVitalsRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () =>
            repository.getRange('token', DateTime(2026, 7, 1), DateTime(2026, 7, 3)),
        throwsA(isA<VitalsFetchFailure>()),
      );
    });

    test('throws VitalsReauthenticationRequired on 401', () async {
      final client = MockClient(
        (request) async => http.Response('Unauthorized', 401),
      );
      final repository = HttpVitalsRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.getDay('expired-token', '2026-07-18'),
        throwsA(isA<VitalsReauthenticationRequired>()),
      );
    });

    test('throws VitalsFetchFailure on other non-2xx responses', () async {
      final client = MockClient(
        (request) async => http.Response('Internal Server Error', 500),
      );
      final repository = HttpVitalsRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.getDay('token-123', '2026-07-18'),
        throwsA(isA<VitalsFetchFailure>()),
      );
    });

    test('throws VitalsFetchFailure (not a crash) on a network error', () async {
      final client = MockClient((request) async => throw Exception('offline'));
      final repository = HttpVitalsRepository(
        baseUrl: 'https://example.test',
        client: client,
      );

      expect(
        () => repository.getDay('token-123', '2026-07-18'),
        throwsA(isA<VitalsFetchFailure>()),
      );
    });
  });
}
