/// Thrown by a diet repository when the backend rejects the ID token
/// (HTTP 401) — the caller must sign in again.
class DietReauthenticationRequired implements Exception {
  const DietReauthenticationRequired();
}

/// Thrown by a diet repository for any other failure (non-2xx response,
/// network error, ...).
class DietFetchFailure implements Exception {
  final String message;

  const DietFetchFailure(this.message);

  @override
  String toString() => message;
}
