import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/split/application/group_use_cases.dart';
import 'package:life_os/contexts/split/domain/group_member.dart';
import 'package:life_os/contexts/split/domain/split_exceptions.dart';
import 'package:life_os/contexts/split/domain/split_group.dart';

import '../support/fake_split_repository.dart';

void main() {
  const group = SplitGroup(id: 'g1', name: 'Trip', createdByUserId: 'u1', archivedAt: null);
  const member = GroupMember(groupId: 'g1', userId: 'u2', displayName: 'Bo', joinedAt: '2026-08-01T00:00:00.000Z');

  test('ListGroups delegates to the repository', () async {
    final repository = FakeSplitRepository()..groupsToReturn = const [group];

    final groups = await ListGroups(repository)('token-1');

    expect(repository.gotIdToken, 'token-1');
    expect(groups.single.id, 'g1');
  });

  test('ListGroups lets the repository error propagate', () async {
    final repository = FakeSplitRepository()..failNext = const SplitFetchFailure();

    expect(() => ListGroups(repository)('token-1'), throwsA(isA<SplitFetchFailure>()));
  });

  test('CreateGroup delegates name to the repository', () async {
    final repository = FakeSplitRepository()..groupToReturn = group;

    final created = await CreateGroup(repository)('token-1', 'Trip');

    expect(repository.gotIdToken, 'token-1');
    expect(repository.gotName, 'Trip');
    expect(created.id, 'g1');
  });

  test('CreateGroup lets the repository error propagate', () async {
    final repository = FakeSplitRepository()..failNext = const SplitBadRequest('name is required');

    expect(() => CreateGroup(repository)('token-1', ''), throwsA(isA<SplitBadRequest>()));
  });

  test('GetGroup delegates groupId and returns the group+members record', () async {
    final repository = FakeSplitRepository()
      ..groupToReturn = group
      ..membersToReturn = const [member];

    final result = await GetGroup(repository)('token-1', 'g1');

    expect(repository.gotGroupId, 'g1');
    expect(result.group.id, 'g1');
    expect(result.members.single.displayName, 'Bo');
  });

  test('GetGroup lets the repository error propagate', () async {
    final repository = FakeSplitRepository()..failNext = const SplitNotFound();

    expect(() => GetGroup(repository)('token-1', 'g1'), throwsA(isA<SplitNotFound>()));
  });

  test('AddGroupMember delegates groupId and userId', () async {
    final repository = FakeSplitRepository()..memberToReturn = member;

    final added = await AddGroupMember(repository)('token-1', 'g1', 'u2');

    expect(repository.gotGroupId, 'g1');
    expect(repository.gotUserId, 'u2');
    expect(added.userId, 'u2');
  });

  test('AddGroupMember lets the repository error propagate', () async {
    final repository = FakeSplitRepository()..failNext = const NotFriends();

    expect(() => AddGroupMember(repository)('token-1', 'g1', 'u2'), throwsA(isA<NotFriends>()));
  });

  test('ArchiveGroup delegates groupId', () async {
    final repository = FakeSplitRepository();

    await ArchiveGroup(repository)('token-1', 'g1');

    expect(repository.gotGroupId, 'g1');
  });

  test('ArchiveGroup lets the repository error propagate', () async {
    final repository = FakeSplitRepository()..failNext = const SplitNotFound();

    expect(() => ArchiveGroup(repository)('token-1', 'g1'), throwsA(isA<SplitNotFound>()));
  });

  test('GetGroupBalances delegates groupId', () async {
    final repository = FakeSplitRepository()..balancesToReturn = const [];

    final balances = await GetGroupBalances(repository)('token-1', 'g1');

    expect(repository.gotGroupId, 'g1');
    expect(balances, isEmpty);
  });

  test('GetGroupBalances lets the repository error propagate', () async {
    final repository = FakeSplitRepository()..failNext = const SplitNotFound();

    expect(() => GetGroupBalances(repository)('token-1', 'g1'), throwsA(isA<SplitNotFound>()));
  });
}
