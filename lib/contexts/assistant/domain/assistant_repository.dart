import 'assistant_message.dart';

/// Port for the assistant conversation endpoint.
///
/// [geminiKey] is the user's own model API key, passed **per call** — an
/// implementation puts it in the request header for this one request and
/// holds it nowhere. It must never appear in a URL, a body, a log line, or a
/// thrown error.
abstract class AssistantRepository {
  Future<AssistantReply> send(
    String idToken, {
    required String geminiKey,
    required List<AssistantMessage> messages,
  });
}
