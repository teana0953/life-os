/// Thrown by a body-profile repository when the backend rejects the ID token
/// (HTTP 401) — the caller must sign in again.
class BodyProfileReauthenticationRequired implements Exception {
  const BodyProfileReauthenticationRequired();
}

/// Thrown by a body-profile repository for any other failure (non-200 response,
/// network error, malformed body, ...). Typed only — the user-facing copy lives
/// in the presentation layer, never here.
class BodyProfileFetchFailure implements Exception {
  const BodyProfileFetchFailure();
}
