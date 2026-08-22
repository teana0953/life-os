import 'assistant_message.dart';

/// Port for the assistant conversation endpoint.
///
/// [geminiKey] is the user's own model API key, passed **per call** — an
/// implementation puts it in the request header for this one request and
/// holds it nowhere. It must never appear in a URL, a body, a log line, or a
/// thrown error.
///
/// [healthEnabled] is the user's consent for the assistant to read their
/// health and diet records, resolved by the caller at the moment of sending.
/// An implementation that cannot claim it MUST **omit** the claim, never
/// falsify it: the backend fails closed and compares the header value
/// exactly, so a claim it does not recognize denies access — but a claim the
/// user did not give must not be on the request at all.
///
/// Required, not defaulted, on purpose: `false` would let a future call site
/// forget it and silently drop a consent the user granted; `true` would leak.
abstract class AssistantRepository {
  Future<AssistantReply> send(
    String idToken, {
    required String geminiKey,
    required bool healthEnabled,
    required List<AssistantMessage> messages,
  });
}
