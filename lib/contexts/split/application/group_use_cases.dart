import '../domain/balance.dart';
import '../domain/group_member.dart';
import '../domain/split_group.dart';
import '../domain/split_repository.dart';

/// Use case: list the caller's groups (with members embedded).
class ListGroups {
  final SplitRepository _repository;

  ListGroups(this._repository);

  Future<List<SplitGroup>> call(String idToken) => _repository.listGroups(idToken);
}

/// Use case: create a group; the caller becomes its first member.
class CreateGroup {
  final SplitRepository _repository;

  CreateGroup(this._repository);

  Future<SplitGroup> call(String idToken, String name) => _repository.createGroup(idToken, name);
}

class GetGroup {
  final SplitRepository _repository;

  GetGroup(this._repository);

  Future<({SplitGroup group, List<GroupMember> members})> call(String idToken, String groupId) =>
      _repository.getGroup(idToken, groupId);
}

/// Use case: add a friend to a group.
class AddGroupMember {
  final SplitRepository _repository;

  AddGroupMember(this._repository);

  Future<GroupMember> call(String idToken, String groupId, String userId) =>
      _repository.addGroupMember(idToken, groupId, userId);
}

/// Use case: archive a group (only its creator may).
class ArchiveGroup {
  final SplitRepository _repository;

  ArchiveGroup(this._repository);

  Future<void> call(String idToken, String groupId) => _repository.archiveGroup(idToken, groupId);
}

/// Use case: each member's net against the whole group.
class GetGroupBalances {
  final SplitRepository _repository;

  GetGroupBalances(this._repository);

  Future<List<Balance>> call(String idToken, String groupId) =>
      _repository.getGroupBalances(idToken, groupId);
}
