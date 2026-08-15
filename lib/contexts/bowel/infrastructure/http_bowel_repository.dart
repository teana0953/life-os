import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/bowel_day.dart';
import '../domain/bowel_exceptions.dart';
import '../domain/bowel_repository.dart';

class HttpBowelRepository implements BowelRepository {
  final String baseUrl;
  final http.Client client;

  HttpBowelRepository({required this.baseUrl, required this.client});

  static const _genericFailureMessage =
      'Unable to load your bowel data. Please try again.';

  Map<String, String> _headers(String idToken) => {
    'Authorization': 'Bearer $idToken',
    'Content-Type': 'application/json',
  };

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request();
    } catch (_) {
      throw const BowelFetchFailure(_genericFailureMessage);
    }
    if (response.statusCode == 401) {
      throw const BowelReauthenticationRequired();
    }
    return response;
  }

  @override
  Future<BowelDay> getDay(String idToken, String day) async {
    final response = await _send(
      () => client.get(
        Uri.parse('$baseUrl/api/bowel?day=$day'),
        headers: _headers(idToken),
      ),
    );
    if (response.statusCode != 200) {
      throw BowelFetchFailure(
        'Failed to load the day\'s bowel record (status ${response.statusCode}).',
      );
    }
    return _parse(response.body);
  }

  @override
  Future<BowelDay> save(
    String idToken, {
    required String day,
    required int count,
    required bool? isNormal,
    required String note,
  }) async {
    final response = await _send(
      () => client.put(
        Uri.parse('$baseUrl/api/bowel'),
        headers: _headers(idToken),
        body: jsonEncode({
          'day': day,
          'count': count,
          'is_normal': isNormal,
          'note': note,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw BowelFetchFailure(
        'Failed to save the bowel record (status ${response.statusCode}).',
      );
    }
    return _parse(response.body);
  }

  BowelDay _parse(String body) {
    try {
      return BowelDay.fromJson(jsonDecode(body) as Map<String, dynamic>);
    } catch (_) {
      throw const BowelFetchFailure(_genericFailureMessage);
    }
  }
}
