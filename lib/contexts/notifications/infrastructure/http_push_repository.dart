import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/push_repository.dart';
import '../domain/push_subscription.dart';

/// [PushRepository] driven adapter backed by the `/api/push/*` HTTP
/// endpoints (mirrors `HttpImportRepository`).
class HttpPushRepository implements PushRepository {
  final String baseUrl;
  final http.Client client;

  HttpPushRepository({required this.baseUrl, required this.client});

  Map<String, String> _headers(String idToken) => {
    'Authorization': 'Bearer $idToken',
    'Content-Type': 'application/json',
  };

  void _checkStatus(http.Response response) {
    if (response.statusCode == 401) throw const PushReauthRequired();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const PushRequestFailed();
    }
  }

  @override
  Future<String> fetchVapidPublicKey(String idToken) async {
    final http.Response response;
    try {
      response = await client.get(
        Uri.parse('$baseUrl/api/push/vapid-public-key'),
        headers: _headers(idToken),
      );
    } catch (_) {
      throw const PushRequestFailed();
    }
    _checkStatus(response);
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json['public_key'] as String;
    } catch (_) {
      throw const PushRequestFailed();
    }
  }

  @override
  Future<void> saveSubscription(
    String idToken,
    PushSubscription subscription,
  ) async {
    final http.Response response;
    try {
      response = await client.post(
        Uri.parse('$baseUrl/api/push/subscribe'),
        headers: _headers(idToken),
        body: jsonEncode({
          'endpoint': subscription.endpoint,
          'p256dh': subscription.p256dh,
          'auth': subscription.auth,
        }),
      );
    } catch (_) {
      throw const PushRequestFailed();
    }
    _checkStatus(response);
  }

  @override
  Future<TestPushResult> sendTest(String idToken) async {
    final http.Response response;
    try {
      response = await client.post(
        Uri.parse('$baseUrl/api/push/test'),
        headers: _headers(idToken),
      );
    } catch (_) {
      throw const PushRequestFailed();
    }
    _checkStatus(response);
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return TestPushResult(
        sent: json['sent'] as int,
        failed: json['failed'] as int,
      );
    } catch (_) {
      throw const PushRequestFailed();
    }
  }
}
