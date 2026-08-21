/// A batch screen-read answered `401`: the whole screen has to route to its
/// re-authentication exit (design D5). Only a `401` produces this — every
/// other request-level fault is a [ScreenBatchFetchFailure].
class ScreenBatchReauthRequired implements Exception {
  const ScreenBatchReauthRequired();
}

/// A batch screen-read failed as a whole: transport error, timeout, `400`,
/// any other non-`200`, or a body that could not be decoded.
///
/// `400` is deliberately not its own mode: it can only mean this client sent
/// a malformed `day` or an out-of-range window, i.e. a client bug, and
/// "unavailable" is the honest thing to tell a user about one. It is
/// prevented at source instead — see [ScreenBatchRepository].
class ScreenBatchFetchFailure implements Exception {
  final String message;

  const ScreenBatchFetchFailure([
    this.message = 'Unable to load this screen. Please try again.',
  ]);

  @override
  String toString() => 'ScreenBatchFetchFailure: $message';
}
