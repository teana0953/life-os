/// The typed ways a `POST /api/assistant` round-trip can fail — one value per
/// *user-meaningful* outcome, classified from the response body's `error`
/// field (never from the status code alone: 400 carries two different
/// stories, a missing key and a rejected key, and they demand different
/// exits).
///
/// Presentation maps each value to localized copy and to its own recovery
/// action ("go to settings" vs "retry") — infrastructure and this enum carry
/// no message strings (i18n rule: error copy lives in presentation).
enum AssistantFailure {
  /// 400 `bad_request` — the backend never saw a key. The composer is gated
  /// on `hasKey`, so reaching this means the key vanished under us (cleared
  /// from another tab); the screen falls back to the setup state.
  missingKey,

  /// 400 `gemini_key_rejected` — the key reached Gemini and Gemini refused
  /// it. The fix lives on the settings page.
  keyRejected,

  /// 429 `gemini_quota_exhausted` — the key is fine; its free quota is spent.
  quotaExhausted,

  /// 403 `gemini_model_unavailable` — the key cannot use the served model.
  modelUnavailable,

  /// 502 `gemini_unavailable` — the upstream service failed; retry later.
  serviceUnavailable,

  /// The request never got an HTTP answer (offline, DNS, timeout). Shown
  /// with the same copy as [serviceUnavailable] but kept distinct here so
  /// the classification tests can tell "the body said 502" from "no body".
  network,
}

/// Thrown by an assistant repository when the send failed in one of the
/// [AssistantFailure] ways.
class AssistantSendFailure implements Exception {
  final AssistantFailure failure;

  const AssistantSendFailure(this.failure);
}

/// Thrown by an assistant repository when the backend rejects the ID token
/// (HTTP 401) — the caller must sign in again. Mirrors the other contexts'
/// `*ReauthenticationRequired` shape.
class AssistantReauthRequired implements Exception {
  const AssistantReauthRequired();
}
