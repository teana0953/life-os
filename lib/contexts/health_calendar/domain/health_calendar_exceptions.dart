/// Thrown when the health-calendar request fails for a non-auth reason.
class HealthCalendarFetchFailure implements Exception {
  const HealthCalendarFetchFailure();
}

/// Thrown on a 401 — the caller should surface a "sign in again" exit.
class HealthCalendarReauthenticationRequired implements Exception {
  const HealthCalendarReauthenticationRequired();
}
