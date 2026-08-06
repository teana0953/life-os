import 'balance.dart';
import 'group_member.dart';
import 'settlement.dart';
import 'split_activity.dart';
import 'split_expense.dart';
import 'split_group.dart';
import 'split_input.dart';

/// Port covering groups, expenses and balances (contract frozen in
/// design.md, backend PR #65/#66). Every method takes [idToken] explicitly
/// — the caller fetches it fresh per request rather than relying on a
/// cached snapshot (mirrors `SocialRepository`).
///
/// Deliberately has **no** friends method: the candidate-friends list is
/// reused from the social context's own `ListFriends` use case (design
/// D5b). Adding one here would give the same data two paths and two error
/// mappings that would drift apart.
abstract class SplitRepository {
  Future<List<SplitGroup>> listGroups(String idToken);

  Future<SplitGroup> createGroup(String idToken, String name);

  /// `GET /api/split/groups/:id` returns `{ group, members }` as sibling
  /// keys, so this returns them as a record rather than a [SplitGroup]
  /// with `members` populated.
  Future<({SplitGroup group, List<GroupMember> members})> getGroup(
    String idToken,
    String groupId,
  );

  Future<GroupMember> addGroupMember(String idToken, String groupId, String userId);

  Future<void> archiveGroup(String idToken, String groupId);

  /// Each member's net against the whole group, including the caller
  /// (design D2 — not the same sign convention as [getBalances]).
  Future<List<Balance>> getGroupBalances(String idToken, String groupId);

  Future<List<SplitExpense>> listExpenses(
    String idToken, {
    String? groupId,
    String? withUserId,
  });

  Future<SplitExpense> createExpense(
    String idToken, {
    String? groupId,
    required String payerUserId,
    required int amount,
    required String currency,
    required String description,
    required String day,
    required SplitInput split,
    String? categoryName,
  });

  Future<SplitExpense> getExpense(String idToken, String expenseId);

  /// `PATCH` is a full replace on the backend — callers must pass every
  /// field, not just the ones that changed (design D3). `group_id` is
  /// immutable server-side; pass `null` to leave it untouched.
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
    String? categoryName,
  });

  Future<void> deleteExpense(String idToken, String expenseId);

  /// The caller's signed two-person net against everyone they share an
  /// expense with. Positive means that person owes the caller (design D2).
  Future<List<Balance>> getBalances(String idToken);

  /// Records a repayment. [groupId] is `null` for every settlement this UI
  /// creates — settling only ever starts from a two-person balance (design
  /// D0), which is the only place a from/to pair is well-defined.
  Future<Settlement> createSettlement(
    String idToken, {
    String? groupId,
    required String fromUserId,
    required String toUserId,
    required int amount,
    required String currency,
    required String day,
    String? note,
  });

  Future<List<Settlement>> listSettlements(
    String idToken, {
    String? groupId,
    String? withUserId,
  });

  /// Only the settlement's creator or its payer (`fromUserId`) may delete
  /// it; anyone else gets a `404` (never `403` — same visibility rule as
  /// every other split resource).
  Future<void> deleteSettlement(String idToken, String settlementId);

  /// One page of the change log, newest first (backend PR #72). [cursor] is
  /// the previous page's `next_cursor`, omitted for the first page.
  ///
  /// The backend defaults [limit] to 50 and silently clamps anything above
  /// 100; a non-integer is a `400`. Callers pass a small page deliberately —
  /// this timeline only grows.
  Future<SplitActivityPage> listActivity(
    String idToken, {
    required int limit,
    String? cursor,
  });
}
