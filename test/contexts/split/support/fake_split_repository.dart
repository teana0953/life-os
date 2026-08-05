import 'package:life_os/contexts/split/domain/balance.dart';
import 'package:life_os/contexts/split/domain/group_member.dart';
import 'package:life_os/contexts/split/domain/settlement.dart';
import 'package:life_os/contexts/split/domain/split_expense.dart';
import 'package:life_os/contexts/split/domain/split_group.dart';
import 'package:life_os/contexts/split/domain/split_input.dart';
import 'package:life_os/contexts/split/domain/split_repository.dart';

/// Shared fake [SplitRepository] for application-layer tests (mirrors
/// social's `_FakeSocialRepository`). Records the last call's arguments and
/// can be told to throw on the next call.
class FakeSplitRepository implements SplitRepository {
  String? gotIdToken;

  /// Every id token the group fetch / add-member calls were made with, in
  /// order — the *value that was sent*, which is what the token-freshness
  /// test asserts on (that a provider was called proves nothing).
  final List<String> groupTokens = [];
  final List<String> addGroupMemberTokens = [];
  String? gotName;
  String? gotGroupId;
  String? gotUserId;
  String? gotExpenseId;
  String? gotWithUserId;
  String? gotPayerUserId;
  int? gotAmount;
  String? gotCurrency;
  String? gotDescription;
  String? gotDay;
  SplitInput? gotSplit;
  Object? failNext;

  List<SplitGroup> groupsToReturn = const [];
  SplitGroup? groupToReturn;

  /// What [getGroup] returns per group id, for tests where *which* group was
  /// asked for is the point (the `/finance/groups/:id` route reusing one
  /// screen's `State` for a second id). Falls back to [groupToReturn].
  Map<String, SplitGroup> groupsByIdToReturn = const {};
  List<GroupMember> membersToReturn = const [];
  GroupMember? memberToReturn;
  List<Balance> balancesToReturn = const [];
  List<SplitExpense> expensesToReturn = const [];
  SplitExpense? expenseToReturn;

  String? gotFromUserId;
  String? gotToUserId;
  String? gotNote;
  String? gotSettlementId;

  /// The `group_id` the most recent `createSettlement` call actually
  /// received — separate from [gotGroupId], which a follow-up reload (e.g.
  /// `GroupDetailController.createSettlement`'s own `load` call, which hits
  /// `getGroup`/`getGroupBalances`) overwrites with the *screen's* group id
  /// right after, masking whether the settlement write itself sent `null`
  /// (design D0/D8 — settling only ever sends `group_id: null`).
  String? gotCreateSettlementGroupId;
  List<Settlement> settlementsToReturn = const [];
  Settlement? settlementToReturn;

  /// How many times [deleteSettlement] has been called.
  int deleteSettlementCalls = 0;

  /// How many times [getBalances] has been called — a cheap "was the whole
  /// split load re-run" signal for tests pinning a reload (e.g. task 8.1b's
  /// return-from-group-detail reload), since every `SplitController.load`
  /// call fetches balances as one of its four parallel requests.
  int getBalancesCalls = 0;

  /// How many times [archiveGroup] has been called. `gotGroupId` cannot
  /// stand in for it: the initial load already sets that field to the same
  /// group id, so a "cancelling sends nothing" assertion on it holds whether
  /// or not the archive ran.
  int archiveCalls = 0;

  void _maybeThrow() {
    final failure = failNext;
    if (failure != null) throw failure;
  }

  @override
  Future<List<SplitGroup>> listGroups(String idToken) async {
    gotIdToken = idToken;
    _maybeThrow();
    return groupsToReturn;
  }

  @override
  Future<SplitGroup> createGroup(String idToken, String name) async {
    gotIdToken = idToken;
    gotName = name;
    _maybeThrow();
    return groupToReturn!;
  }

  @override
  Future<({SplitGroup group, List<GroupMember> members})> getGroup(
    String idToken,
    String groupId,
  ) async {
    gotIdToken = idToken;
    groupTokens.add(idToken);
    gotGroupId = groupId;
    _maybeThrow();
    return (group: groupsByIdToReturn[groupId] ?? groupToReturn!, members: membersToReturn);
  }

  @override
  Future<GroupMember> addGroupMember(String idToken, String groupId, String userId) async {
    gotIdToken = idToken;
    addGroupMemberTokens.add(idToken);
    gotGroupId = groupId;
    gotUserId = userId;
    _maybeThrow();
    return memberToReturn!;
  }

  @override
  Future<void> archiveGroup(String idToken, String groupId) async {
    gotIdToken = idToken;
    gotGroupId = groupId;
    archiveCalls++;
    _maybeThrow();
  }

  @override
  Future<List<Balance>> getGroupBalances(String idToken, String groupId) async {
    gotIdToken = idToken;
    gotGroupId = groupId;
    _maybeThrow();
    return balancesToReturn;
  }

  @override
  Future<List<SplitExpense>> listExpenses(
    String idToken, {
    String? groupId,
    String? withUserId,
  }) async {
    gotIdToken = idToken;
    gotGroupId = groupId;
    gotWithUserId = withUserId;
    _maybeThrow();
    return expensesToReturn;
  }

  @override
  Future<SplitExpense> createExpense(
    String idToken, {
    String? groupId,
    required String payerUserId,
    required int amount,
    required String currency,
    required String description,
    required String day,
    required SplitInput split,
  }) async {
    gotIdToken = idToken;
    gotGroupId = groupId;
    gotPayerUserId = payerUserId;
    gotAmount = amount;
    gotCurrency = currency;
    gotDescription = description;
    gotDay = day;
    gotSplit = split;
    _maybeThrow();
    return expenseToReturn!;
  }

  @override
  Future<SplitExpense> getExpense(String idToken, String expenseId) async {
    gotIdToken = idToken;
    gotExpenseId = expenseId;
    _maybeThrow();
    return expenseToReturn!;
  }

  @override
  Future<SplitExpense> updateExpense(
    String idToken,
    String expenseId, {
    String? groupId,
    required String payerUserId,
    required int amount,
    required String currency,
    required String description,
    required String day,
    required SplitInput split,
  }) async {
    gotIdToken = idToken;
    gotExpenseId = expenseId;
    gotGroupId = groupId;
    gotPayerUserId = payerUserId;
    gotAmount = amount;
    gotCurrency = currency;
    gotDescription = description;
    gotDay = day;
    gotSplit = split;
    _maybeThrow();
    return expenseToReturn!;
  }

  @override
  Future<void> deleteExpense(String idToken, String expenseId) async {
    gotIdToken = idToken;
    gotExpenseId = expenseId;
    _maybeThrow();
  }

  /// What [getBalances] (the caller's own two-person balances) returns, when
  /// set — distinct from [balancesToReturn] (which backs [getGroupBalances],
  /// the per-member-vs-group figures). `GroupDetailController` now calls
  /// both (design D8), and a test that needs them to disagree — e.g. proving
  /// the group screen's two sections really read from two different
  /// endpoints — couldn't otherwise tell them apart. Falls back to
  /// [balancesToReturn] when unset, so every pre-existing caller that only
  /// ever set one field keeps working unchanged.
  List<Balance>? personalBalancesToReturn;

  @override
  Future<List<Balance>> getBalances(String idToken) async {
    gotIdToken = idToken;
    getBalancesCalls++;
    _maybeThrow();
    return personalBalancesToReturn ?? balancesToReturn;
  }

  @override
  Future<Settlement> createSettlement(
    String idToken, {
    String? groupId,
    required String fromUserId,
    required String toUserId,
    required int amount,
    required String currency,
    required String day,
    String? note,
  }) async {
    gotIdToken = idToken;
    gotGroupId = groupId;
    gotCreateSettlementGroupId = groupId;
    gotFromUserId = fromUserId;
    gotToUserId = toUserId;
    gotAmount = amount;
    gotCurrency = currency;
    gotDay = day;
    gotNote = note;
    _maybeThrow();
    return settlementToReturn!;
  }

  @override
  Future<List<Settlement>> listSettlements(
    String idToken, {
    String? groupId,
    String? withUserId,
  }) async {
    gotIdToken = idToken;
    gotGroupId = groupId;
    gotWithUserId = withUserId;
    _maybeThrow();
    return settlementsToReturn;
  }

  @override
  Future<void> deleteSettlement(String idToken, String settlementId) async {
    gotIdToken = idToken;
    gotSettlementId = settlementId;
    deleteSettlementCalls++;
    _maybeThrow();
  }
}
