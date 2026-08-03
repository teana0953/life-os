import 'package:flutter/foundation.dart';

import '../../social/application/friend_use_cases.dart';
import '../../social/domain/friend.dart';
import '../../social/domain/social_exceptions.dart';
import '../../user/application/get_profile.dart';
import '../../user/domain/profile_exceptions.dart';
import '../application/expense_use_cases.dart';
import '../application/group_use_cases.dart';
import '../domain/balance.dart';
import '../domain/group_member.dart';
import '../domain/split_exceptions.dart';
import '../domain/split_expense.dart';
import '../domain/split_group.dart';
import '../domain/split_input.dart';
import 'split_expense_writer.dart';

enum GroupDetailStatus { loading, loaded, error, needsReauth }

enum GroupDetailError {
  /// The caller's own profile could not be fetched — the same distinct
  /// failure `SplitController` reports, and for the same reason: every
  /// ownership gate on this screen is decided by the caller's own user id,
  /// so it is never carried forward as `null` (design D5c).
  profileFailed,
  fetchFailed,
  unknown,
}

/// Drives a single group's screen: its members, its per-currency group
/// balances (design D2 — a different reading from the two-person balance,
/// so this controller never reuses [SplitController]'s balance rows), and
/// its expenses, plus adding a member, archiving, and writing expenses
/// pre-locked to this group. Owned by the screen's own `State`
/// (`initState`/`dispose`) — every controller in this context is, per
/// design.md, to avoid the app-lifetime-singleton leak `NetWorthController`
/// has to work around with an explicit sign-out reset.
class GroupDetailController extends ChangeNotifier implements SplitExpenseWriter {
  final GetGroup _getGroup;
  final GetGroupBalances _getGroupBalances;
  final ListExpenses _listExpenses;
  final AddGroupMember _addGroupMember;
  final ArchiveGroup _archiveGroup;
  final CreateExpense _createExpense;
  final UpdateExpense _updateExpense;
  final DeleteExpense _deleteExpense;
  final ListFriends _listFriends;
  final GetProfile _getProfile;

  GroupDetailController(
    this._getGroup,
    this._getGroupBalances,
    this._listExpenses,
    this._addGroupMember,
    this._archiveGroup,
    this._createExpense,
    this._updateExpense,
    this._deleteExpense,
    this._listFriends,
    this._getProfile,
  );

  GroupDetailStatus status = GroupDetailStatus.loading;
  GroupDetailError? error;

  /// The caller's own user id, resolved from `/api/me` by [load] — **not**
  /// taken from the URL. Every gate on this screen (archive is creator-only,
  /// edit is creator-or-payer-only, and the record sheet's own stake gate)
  /// is decided by it, so a hand-edited link must not be able to set it:
  /// a URL carrying someone else's id would otherwise offer actions the
  /// server can only refuse, and label whose money is whose wrongly.
  String? selfUserId;

  SplitGroup? group;
  List<GroupMember> members = [];

  /// Each member's net against the whole group, including the caller
  /// (design D2 — not the two-person "owed to me" sign convention).
  List<Balance> groupBalances = [];
  List<SplitExpense> expenses = [];

  /// The caller's friends, for the add-member picker — narrowed to
  /// non-members by the screen, not here, so this stays a plain mirror of
  /// what `ListFriends` returned.
  List<Friend> friends = [];

  @override
  Object? mutationError;
  @override
  int mutationErrorSeq = 0;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// The screen can be left from any state, including while a request is
  /// still in flight — at which point this controller is already disposed by
  /// the time the response lands, and a plain `notifyListeners` would throw
  /// "used after being disposed". Same guard as `FriendsController`.
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  Future<void> load(String idToken, String groupId) async {
    status = GroupDetailStatus.loading;
    error = null;

    try {
      final profile = await _getProfile(idToken);
      selfUserId = profile.id;
    } on ReauthenticationRequired {
      status = GroupDetailStatus.needsReauth;
      _notify();
      return;
    } catch (_) {
      status = GroupDetailStatus.error;
      error = GroupDetailError.profileFailed;
      _notify();
      return;
    }

    try {
      final results = await Future.wait([
        _getGroup(idToken, groupId),
        _getGroupBalances(idToken, groupId),
        _listExpenses(idToken, groupId: groupId),
        _listFriends(idToken),
      ]);
      final fetched = results[0] as ({SplitGroup group, List<GroupMember> members});
      group = fetched.group;
      members = fetched.members;
      groupBalances = results[1] as List<Balance>;
      expenses = results[2] as List<SplitExpense>;
      friends = results[3] as List<Friend>;
      status = GroupDetailStatus.loaded;
    } on SplitReauthenticationRequired {
      status = GroupDetailStatus.needsReauth;
    } on SocialReauthenticationRequired {
      status = GroupDetailStatus.needsReauth;
    } catch (_) {
      status = GroupDetailStatus.error;
      error = GroupDetailError.fetchFailed;
    }
    _notify();
  }

  Future<void> addMember(String idToken, String groupId, String userId) =>
      _mutate(idToken, groupId, () async {
        await _addGroupMember(idToken, groupId, userId);
        await load(idToken, groupId);
      });

  Future<void> archive(String idToken, String groupId) => _mutate(idToken, groupId, () async {
    await _archiveGroup(idToken, groupId);
    await load(idToken, groupId);
  });

  @override
  Future<void> createExpense(
    String idToken, {
    String? groupId,
    required String payerUserId,
    required int amount,
    required String currency,
    required String description,
    required String day,
    required SplitInput split,
  }) => _mutate(idToken, groupId!, () async {
    await _createExpense(
      idToken,
      groupId: groupId,
      payerUserId: payerUserId,
      amount: amount,
      currency: currency,
      description: description,
      day: day,
      split: split,
    );
    await load(idToken, groupId);
  });

  @override
  Future<void> updateExpense(
    String idToken,
    String expenseId, {
    String? groupId,
    required String payerUserId,
    required int amount,
    required String currency,
    required String description,
    required String day,
    required SplitInput split,
  }) => _mutate(idToken, groupId ?? group!.id, () async {
    await _updateExpense(
      idToken,
      expenseId,
      groupId: groupId,
      payerUserId: payerUserId,
      amount: amount,
      currency: currency,
      description: description,
      day: day,
      split: split,
    );
    await load(idToken, groupId ?? group!.id);
  });

  @override
  Future<void> deleteExpense(String idToken, String expenseId) =>
      _mutate(idToken, group!.id, () async {
        await _deleteExpense(idToken, expenseId);
        await load(idToken, group!.id);
      });

  Future<void> _mutate(String idToken, String groupId, Future<void> Function() action) async {
    try {
      await action();
      return;
    } on SplitReauthenticationRequired {
      status = GroupDetailStatus.needsReauth;
    } catch (e) {
      mutationError = e;
      mutationErrorSeq++;
    }
    _notify();
  }
}
