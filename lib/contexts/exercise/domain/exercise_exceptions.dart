/// Thrown by an exercise repository when the backend rejects the ID token
/// (HTTP 401) — the caller must sign in again.
class ExerciseReauthenticationRequired implements Exception {
  const ExerciseReauthenticationRequired();
}

/// Thrown by an exercise repository for any other failure (non-200 response,
/// network error, malformed body, ...). Typed only — the user-facing copy
/// lives in the presentation layer, never here.
class ExerciseFetchFailure implements Exception {
  const ExerciseFetchFailure();
}
