import 'social_exceptions.dart';

/// A friend, as returned by `GET /api/friends` — name only, deliberately no
/// email (design.md).
class Friend {
  final String userId;
  final String displayName;

  const Friend({required this.userId, required this.displayName});

  /// Throws [SocialFetchFailure] for a missing/wrong-typed field rather than
  /// letting a cast error escape.
  factory Friend.fromJson(Map<String, dynamic> json) {
    try {
      return Friend(
        userId: json['user_id'] as String,
        displayName: json['display_name'] as String,
      );
    } catch (_) {
      throw const SocialFetchFailure();
    }
  }
}
