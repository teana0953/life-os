import 'friend.dart';
import 'social_exceptions.dart';

/// The result of `POST /api/friends/invites/preview` — who is behind a
/// link, before it is accepted (design D2).
class InvitePreview {
  final String inviterDisplayName;
  final bool alreadyFriends;

  const InvitePreview({
    required this.inviterDisplayName,
    required this.alreadyFriends,
  });

  /// Throws [SocialFetchFailure] for a missing/wrong-typed field rather than
  /// letting a cast error escape.
  factory InvitePreview.fromJson(Map<String, dynamic> json) {
    try {
      return InvitePreview(
        inviterDisplayName: json['inviter_display_name'] as String,
        alreadyFriends: json['already_friends'] as bool,
      );
    } catch (_) {
      throw const SocialFetchFailure();
    }
  }
}

/// The result of `POST /api/friends/invites/accept`. [friend] is always
/// present, even when [alreadyFriends] is true (the backend returns the
/// existing relationship without re-claiming the invite).
class AcceptInviteResult {
  final Friend friend;
  final bool alreadyFriends;

  const AcceptInviteResult({required this.friend, required this.alreadyFriends});

  /// Throws [SocialFetchFailure] for a missing/wrong-typed field rather than
  /// letting a cast error escape.
  factory AcceptInviteResult.fromJson(Map<String, dynamic> json) {
    try {
      return AcceptInviteResult(
        friend: Friend.fromJson(json['friend'] as Map<String, dynamic>),
        alreadyFriends: json['already_friends'] as bool,
      );
    } catch (_) {
      throw const SocialFetchFailure();
    }
  }
}
