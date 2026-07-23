/// Thrown by an import repository when the backend rejects the lifeos ID
/// token (HTTP 401) — the caller must sign in again.
class ImportReauthenticationRequired implements Exception {
  const ImportReauthenticationRequired();
}

/// Thrown by an import repository when chaodays itself rejects the provided
/// credentials (backend 400 `chaodays_auth_failed`).
class ImportChaodaysAuthFailed implements Exception {
  const ImportChaodaysAuthFailed();
}

/// Thrown by an import repository when the chaodays upstream is unreachable
/// (backend 502 `chaodays_unavailable`).
class ImportChaodaysUnavailable implements Exception {
  const ImportChaodaysUnavailable();
}

/// Thrown by an import repository for any other failure (unexpected non-2xx
/// response, network error, unparseable body, ...).
class ImportFetchFailure implements Exception {
  final String message;

  const ImportFetchFailure(this.message);

  @override
  String toString() => message;
}
