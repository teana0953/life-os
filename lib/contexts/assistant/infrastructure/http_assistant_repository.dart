import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/assistant_failure.dart';
import '../domain/assistant_message.dart';
import '../domain/assistant_repository.dart';
import '../domain/transaction_draft.dart';

/// [AssistantRepository] driven adapter backed by `POST /api/assistant`.
///
/// The Gemini key travels in the `X-Gemini-Api-Key` **header** — never the
/// URL (query strings reach access logs, `Referer` headers and browser
/// history) and never the body. It is used for the one request and stored
/// nowhere; no exception thrown from here carries it.
class HttpAssistantRepository implements AssistantRepository {
  final String baseUrl;
  final http.Client client;

  HttpAssistantRepository({required this.baseUrl, required this.client});

  @override
  Future<AssistantReply> send(
    String idToken, {
    required String geminiKey,
    required bool healthEnabled,
    required List<AssistantMessage> messages,
  }) async {
    final http.Response response;
    try {
      response = await client.post(
        Uri.parse('$baseUrl/api/assistant'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
          'X-Gemini-Api-Key': geminiKey,
          // Exactly `on`, lower case, no surrounding whitespace — the
          // backend compares the value literally and denies the health tools
          // on anything else. And when the user has not granted it the
          // header is absent entirely rather than `off`: sending a value
          // would make the denial depend on that string comparison, one typo
          // (`'On'`, `'on '`) away from granting what nobody granted.
          if (healthEnabled) 'X-Assistant-Health': 'on',
        },
        body: jsonEncode({
          'messages': [
            for (final message in messages)
              {'role': message.role, 'content': message.content},
          ],
        }),
      );
    } catch (_) {
      throw const AssistantSendFailure(AssistantFailure.network);
    }
    if (response.statusCode == 401) throw const AssistantReauthRequired();
    if (response.statusCode != 200) {
      throw AssistantSendFailure(_classify(response));
    }
    try {
      // `bodyBytes` + explicit utf8: the reply is Chinese-heavy prose, and
      // `response.body` falls back to latin1 when the content-type carries
      // no charset.
      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final rawProposals = json['proposals'] as List<dynamic>? ?? const [];
      return AssistantReply(
        text: json['text'] as String,
        proposals: [
          for (final raw in rawProposals.whereType<Map<String, dynamic>>())
            AssistantProposal(
              kind: raw['kind'] as String? ?? '',
              fields: raw['fields'] as Map<String, dynamic>? ?? const {},
            ),
        ],
      );
    } catch (_) {
      throw const AssistantSendFailure(AssistantFailure.serviceUnavailable);
    }
  }

  /// Classifies a non-200 response by the **body's `error` field**, not the
  /// status code: 400 alone cannot distinguish "the backend never saw a key"
  /// (`bad_request`) from "Gemini refused this key" (`gemini_key_rejected`),
  /// and the two demand different exits.
  AssistantFailure _classify(http.Response response) {
    String? code;
    try {
      code = (jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>)['error'] as String?;
    } catch (_) {
      // An unreadable error body (an HTML gateway page, a truncated
      // response) classifies as the generic unavailable below.
    }
    switch (code) {
      case 'bad_request':
        return AssistantFailure.missingKey;
      case 'gemini_key_rejected':
        return AssistantFailure.keyRejected;
      case 'gemini_quota_exhausted':
        return AssistantFailure.quotaExhausted;
      case 'gemini_model_unavailable':
        return AssistantFailure.modelUnavailable;
      default:
        return AssistantFailure.serviceUnavailable;
    }
  }
}
