/// Thrown by a finance repository when the backend rejects the ID token
/// (HTTP 401) — the caller must sign in again.
class FinanceReauthenticationRequired implements Exception {
  const FinanceReauthenticationRequired();
}

/// Thrown by a finance repository mutation when the backend returns `400`
/// (bad amount/currency/category/date) — distinct from [FinanceFetchFailure]
/// so the caller can surface a validation-specific message.
class FinanceValidationFailure implements Exception {
  const FinanceValidationFailure();
}

/// Thrown by a finance repository mutation when the backend returns `404` —
/// the target transaction doesn't exist, or exists but isn't owned by the
/// caller.
class FinanceNotFound implements Exception {
  const FinanceNotFound();
}

/// Thrown by a finance repository mutation when the backend returns `409` —
/// the split behind a mirrored transaction changed between the caller reading
/// it and writing it back, so the write was refused **wholesale** (backend:
/// none of it is applied, not even the category change).
///
/// Its own type, not a [FinanceValidationFailure]: re-sending the same body
/// would be refused the same way, so the caller has to re-read before it can
/// mean anything — which is the opposite of what a validation message tells
/// the user to do.
class FinanceConflict implements Exception {
  const FinanceConflict();
}

/// Thrown by a finance repository for any other failure (non-2xx response,
/// network error, ...).
class FinanceFetchFailure implements Exception {
  final String message;

  const FinanceFetchFailure(
    this.message,
  );

  @override
  String toString() => message;
}
