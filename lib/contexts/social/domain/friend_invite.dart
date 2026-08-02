import 'social_exceptions.dart';

/// One of the caller's own still-usable invites, as returned by
/// `GET /api/friends/invites`. [expiresAt]/[createdAt] are kept as the raw
/// UTC ISO-8601 strings the backend sends — parsing into local time is a
/// presentation concern (`day_format.dart`'s `parseInstant`, design D11),
/// not this layer's.
class FriendInvite {
  final String id;
  final String expiresAt;
  final String createdAt;

  const FriendInvite({
    required this.id,
    required this.expiresAt,
    required this.createdAt,
  });

  /// Throws [SocialFetchFailure] for a missing/wrong-typed field rather than
  /// letting a cast error escape.
  factory FriendInvite.fromJson(Map<String, dynamic> json) {
    try {
      return FriendInvite(
        id: json['id'] as String,
        expiresAt: json['expires_at'] as String,
        createdAt: json['created_at'] as String,
      );
    } catch (_) {
      throw const SocialFetchFailure();
    }
  }
}
