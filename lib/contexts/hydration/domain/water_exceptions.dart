/// Thrown by a water repository when the backend rejects the ID token
/// (HTTP 401) — the caller must sign in again.
class WaterReauthenticationRequired implements Exception {
  const WaterReauthenticationRequired();
}

/// Thrown by a water repository for any other failure (non-2xx response,
/// network error, ...).
class WaterFetchFailure implements Exception {
  final String message;

  const WaterFetchFailure(this.message);

  @override
  String toString() => message;
}
