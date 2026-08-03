import 'group_member.dart';
import 'split_exceptions.dart';

/// A split group. `members` shows up in three different shapes across the
/// endpoints that return a group (design.md, backend PR #65/#66):
/// - `GET /api/split/groups`: each group in the list embeds `members`.
/// - `POST /api/split/groups`: the created group has **no** `members` key.
/// - `GET /api/split/groups/:id`: returns `{ group, members }` as sibling
///   keys — members are not inside the group object there.
///
/// [members] is therefore optional. Making it required would let creation
/// succeed on the server while parsing fails on the client, so the user
/// retries and ends up with a duplicate group.
class SplitGroup {
  final String id;
  final String name;
  final String createdByUserId;
  final String? archivedAt;
  final List<GroupMember>? members;

  const SplitGroup({
    required this.id,
    required this.name,
    required this.createdByUserId,
    required this.archivedAt,
    this.members,
  });

  /// Throws [SplitFetchFailure] for a missing/wrong-typed required field
  /// rather than letting a cast error escape.
  factory SplitGroup.fromJson(Map<String, dynamic> json) {
    try {
      return SplitGroup(
        id: json['id'] as String,
        name: json['name'] as String,
        createdByUserId: json['created_by_user_id'] as String,
        archivedAt: json['archived_at'] as String?,
        members: (json['members'] as List<dynamic>?)
            ?.map((e) => GroupMember.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {
      throw const SplitFetchFailure();
    }
  }
}
