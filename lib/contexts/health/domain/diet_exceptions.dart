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

/// Thrown by a diet repository mutation (edit/delete) when the backend
/// returns `404` — the target id doesn't exist, or exists but isn't owned
/// by the caller. Distinct from [DietFetchFailure] so the screen can
/// surface "this entry no longer exists" instead of a generic error.
class DietNotFound implements Exception {
  const DietNotFound();
}

/// Thrown by a diet repository mutation when the backend returns `403` —
/// the caller is not an administrator. Distinct from [DietFetchFailure] so
/// the screen can say "you don't have permission" instead of a generic
/// retryable failure.
class DietForbidden implements Exception {
  const DietForbidden();
}
