// Typed errors for the split context. None of these carry user-facing
// copy — localization happens in presentation (mirrors
// `social_exceptions.dart`). The three errors that carry [message] hold the
// backend's own validation text, not a rendered string.

/// Thrown when the backend rejects the ID token (HTTP 401) — the caller
/// must sign in again.
class SplitReauthenticationRequired implements Exception {
  const SplitReauthenticationRequired();
}

/// Thrown for any other failure fetching/mutating split data (non-2xx
/// response not otherwise mapped, network error, unparsable body, a
/// malformed/missing required field while decoding a domain entity, ...).
class SplitFetchFailure implements Exception {
  const SplitFetchFailure();
}

/// Thrown when a group or expense lookup answers `404 not_found` —
/// visibility, never `403` (the backend never distinguishes "doesn't
/// exist" from "not yours to see").
class SplitNotFound implements Exception {
  const SplitNotFound();
}

/// Thrown for `400 not_friends`.
class NotFriends implements Exception {
  const NotFriends();
}

/// Thrown for `400 not_a_group_member`.
class NotAGroupMember implements Exception {
  const NotAGroupMember();
}

/// Thrown for `400 group_archived`.
class GroupArchived implements Exception {
  const GroupArchived();
}

/// Thrown for `400 shares_do_not_sum_to_amount`. Carries the backend's
/// [message] describing the discrepancy.
class SharesDoNotSumToAmount implements Exception {
  final String message;
  const SharesDoNotSumToAmount(this.message);
}

/// Thrown for `400 split_too_small`.
class SplitTooSmall implements Exception {
  const SplitTooSmall();
}

/// Thrown for `400 duplicate_participant`.
class DuplicateParticipant implements Exception {
  const DuplicateParticipant();
}

/// Thrown for `400 already_a_group_member`.
class AlreadyAGroupMember implements Exception {
  const AlreadyAGroupMember();
}

/// Thrown for `400 not_a_participant`.
class NotAParticipant implements Exception {
  const NotAParticipant();
}

/// Thrown for `400 invalid_split_input`. Carries the backend's [message].
class InvalidSplitInput implements Exception {
  final String message;
  const InvalidSplitInput(this.message);
}

/// Thrown for `400 bad_request` — the route's own input validation (e.g. a
/// malformed field), distinct from the domain-rule 400s above. Carries the
/// backend's [message] so a fixable input error doesn't collapse into a
/// generic failure.
class SplitBadRequest implements Exception {
  final String message;
  const SplitBadRequest(this.message);
}
