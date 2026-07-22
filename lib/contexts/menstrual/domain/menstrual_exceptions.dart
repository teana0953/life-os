/// Thrown by a menstrual repository when the backend rejects the ID token
/// (HTTP 401) — the caller must sign in again.
class MenstrualReauthenticationRequired implements Exception {
  const MenstrualReauthenticationRequired();
}

/// Thrown by a menstrual repository for any other failure (non-200 response,
/// network error, malformed body, ...). Typed only — the user-facing copy
/// lives in the presentation layer, never here.
class MenstrualFetchFailure implements Exception {
  const MenstrualFetchFailure();
}
