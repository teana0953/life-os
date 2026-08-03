import 'split_exceptions.dart';

/// A member of a [SplitGroup]. `displayName` comes from the server
/// (backend PR #66) — the client does not build a name table (design D1).
/// It is only ever null in the genuine edge case where the server has no
/// name to give; presentation supplies the neutral placeholder, never a
/// raw id (i18n rule: domain holds no user-facing copy).
class GroupMember {
  final String groupId;
  final String userId;
  final String? displayName;
  final String joinedAt;

  const GroupMember({
    required this.groupId,
    required this.userId,
    required this.displayName,
    required this.joinedAt,
  });

  /// Throws [SplitFetchFailure] for a missing/wrong-typed required field
  /// rather than letting a cast error escape. `display_name` is optional.
  factory GroupMember.fromJson(Map<String, dynamic> json) {
    try {
      return GroupMember(
        groupId: json['group_id'] as String,
        userId: json['user_id'] as String,
        displayName: json['display_name'] as String?,
        joinedAt: json['joined_at'] as String,
      );
    } catch (_) {
      throw const SplitFetchFailure();
    }
  }
}
