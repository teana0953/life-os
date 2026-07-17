/// Thrown by a [ProfileRepository] when the backend rejects the ID token
/// (HTTP 401) — the caller must sign in again.
class ReauthenticationRequired implements Exception {
  const ReauthenticationRequired();
}

/// Thrown by a [ProfileRepository] for any other failure to fetch the
/// profile (non-200 response, network error, ...).
class ProfileFetchFailure implements Exception {
  final String message;

  const ProfileFetchFailure(this.message);

  @override
  String toString() => message;
}
