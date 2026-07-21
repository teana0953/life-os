/// Thrown by a bowel repository when the backend rejects the ID token
/// (HTTP 401) — the caller must sign in again.
class BowelReauthenticationRequired implements Exception {
  const BowelReauthenticationRequired();
}

/// Thrown by a bowel repository for any other failure (non-2xx response,
/// network error, ...).
class BowelFetchFailure implements Exception {
  final String message;

  const BowelFetchFailure(this.message);

  @override
  String toString() => message;
}
