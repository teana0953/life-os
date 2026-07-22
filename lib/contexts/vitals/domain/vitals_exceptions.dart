/// Thrown by a vitals repository when the backend rejects the ID token
/// (HTTP 401) — the caller must sign in again.
class VitalsReauthenticationRequired implements Exception {
  const VitalsReauthenticationRequired();
}

/// Thrown by a vitals repository for any other failure (non-2xx response,
/// network error, ...).
class VitalsFetchFailure implements Exception {
  final String message;

  const VitalsFetchFailure(this.message);

  @override
  String toString() => message;
}
