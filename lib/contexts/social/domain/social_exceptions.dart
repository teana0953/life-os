// Typed errors for the social context. None of these carry user-facing
// copy — localization happens in presentation (mirrors
// `finance_exceptions.dart`'s split, but see `design.md`: unlike finance,
// nothing here embeds an English message, since the four 400 codes below
// each need their own presentation-layer copy).

/// Thrown when the backend rejects the ID token (HTTP 401) — the caller
/// must sign in again.
class SocialReauthenticationRequired implements Exception {
  const SocialReauthenticationRequired();
}

/// Thrown for any other failure fetching/mutating friends or invites
/// (non-2xx response not otherwise mapped, network error, unparsable
/// body, ...).
class SocialFetchFailure implements Exception {
  const SocialFetchFailure();
}

/// Thrown when `DELETE /api/friends/:friendUserId` or
/// `DELETE /api/friends/invites/:id` answers `404` — the friendship or
/// invite the caller targeted no longer exists. Kept distinct from
/// [InviteNotFound] so "unfriend failed" never renders as "invalid link"
/// (design.md).
class SocialNotFound implements Exception {
  const SocialNotFound();
}

/// Thrown when `preview`/`accept` answers `404` (`not_found`) or `400`
/// (`bad_request`) — to the user, both mean the link is invalid.
class InviteNotFound implements Exception {
  const InviteNotFound();
}

/// Thrown when `preview`/`accept` answers `400` `invite_expired`.
class InviteExpired implements Exception {
  const InviteExpired();
}

/// Thrown when `preview`/`accept` answers `400` `invite_already_used`.
class InviteAlreadyUsed implements Exception {
  const InviteAlreadyUsed();
}

/// Thrown when `preview`/`accept` answers `400` `invite_revoked`.
class InviteRevoked implements Exception {
  const InviteRevoked();
}

/// Thrown when `accept` answers `400` `cannot_friend_self` — only `accept`
/// returns this; `preview` cannot detect it (design D10).
class CannotFriendSelf implements Exception {
  const CannotFriendSelf();
}
