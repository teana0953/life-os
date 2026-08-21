import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/exercise_day.dart';
import '../domain/exercise_exceptions.dart';
import '../domain/exercise_repository.dart';

/// Decodes the `{activities:[...]}` envelope of `/api/exercise/activities`.
/// Public and top-level so the screen-batch decoder shares this one
/// definition with the granular repository below.
List<ExerciseActivity> exerciseActivitiesFromJson(Map<String, dynamic> json) => [
  for (final a in (json['activities'] as List))
    ExerciseActivity.fromJson(a as Map<String, dynamic>),
];

class HttpExerciseRepository implements ExerciseRepository {
  final String baseUrl;
  final http.Client client;

  HttpExerciseRepository({required this.baseUrl, required this.client});

  Map<String, String> _headers(String idToken) => {
    'Authorization': 'Bearer $idToken',
    'Content-Type': 'application/json',
  };

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request();
    } catch (_) {
      throw const ExerciseFetchFailure();
    }
    if (response.statusCode == 401) {
      throw const ExerciseReauthenticationRequired();
    }
    return response;
  }

  @override
  Future<List<ExerciseActivity>> listActivities(String idToken) async {
    final response = await _send(
      () => client.get(
        Uri.parse('$baseUrl/api/exercise/activities'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) throw const ExerciseFetchFailure();
    try {
      return exerciseActivitiesFromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (_) {
      throw const ExerciseFetchFailure();
    }
  }

  @override
  Future<ExerciseDay> getDay(String idToken, String day) async {
    final response = await _send(
      () => client.get(
        Uri.parse('$baseUrl/api/exercise?day=$day'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) throw const ExerciseFetchFailure();
    try {
      return ExerciseDay.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (_) {
      throw const ExerciseFetchFailure();
    }
  }

  @override
  Future<ExerciseEntry> addEntry(
    String idToken, {
    required String day,
    required String activityId,
    required int durationMinutes,
    required String note,
  }) async {
    final response = await _send(
      () => client.post(
        Uri.parse('$baseUrl/api/exercise'),
        headers: _headers(idToken),
        body: jsonEncode({
          'day': day,
          'activity_id': activityId,
          'duration_minutes': durationMinutes,
          'note': note,
        }),
      ),
    );
    if (response.statusCode != 200) throw const ExerciseFetchFailure();
    try {
      return ExerciseEntry.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (_) {
      throw const ExerciseFetchFailure();
    }
  }

  @override
  Future<bool> deleteEntry(String idToken, String entryId) async {
    final response = await _send(
      () => client.delete(
        Uri.parse('$baseUrl/api/exercise/$entryId'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) throw const ExerciseFetchFailure();
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return (json['deleted'] as bool?) ?? false;
    } catch (_) {
      throw const ExerciseFetchFailure();
    }
  }
}
