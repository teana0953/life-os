import 'package:flutter/foundation.dart';

import '../../social/application/friend_use_cases.dart';
import '../../social/domain/friend.dart';
import '../../social/domain/social_exceptions.dart';
import '../../user/application/get_profile.dart';
import '../../user/domain/profile_exceptions.dart';
import '../application/balance_use_cases.dart';
import '../application/expense_use_cases.dart';
import '../application/group_use_cases.dart';
import '../domain/balance.dart';
import '../domain/split_exceptions.dart';
import '../domain/split_group.dart';
import '../domain/split_input.dart';
import '../domain/split_expense.dart';
import 'split_expense_writer.dart';

enum SplitStatus { loading, loaded, error, needsReauth }

/// Reasons the initial load can fail, as understood by [SplitTab].
enum SplitError {
  /// The caller's own profile (needed for the share-stake gate, the
  /// candidate list's "you" entry, and the edit-entry check) could not be
  /// fetched — design D5c: this is a *distinct* failure from the split data
  /// itself, so the tab can say so specifically rather than pretending the
  /// split load failed.
  profileFailed,
  fetchFailed,
  unknown,
}

/// Drives the split tab: the caller's own two-person balances, groups, and
/// recent expenses, plus the friend candidates every write needs, and the
/// caller's own user id (design D5c — resolved here, not carried as `null`
/// past the gates that need it). Owned by `FinanceScaffold`'s `State`
/// (`initState`/`dispose`), **not** an app-lifetime singleton like
/// `NetWorthController` — see design.md and CLAUDE.md for why that pattern
/// is the one to avoid here (a `main.dart` singleton needs an explicit
/// `_resetControllersOnSignOut` entry, which is exactly the leak this
/// change must not add another instance of).
class SplitController extends ChangeNotifier implements SplitExpenseWriter {
  final GetBalances _getBalances;
  final ListGroups _listGroups;
  final ListExpenses _listExpenses;
  final CreateExpense _createExpense;
  final UpdateExpense _updateExpense;
  final DeleteExpense _deleteExpense;
  final CreateGroup _createGroup;
  final ListFriends _listFriends;
  final GetProfile _getProfile;

  SplitController(
    this._getBalances,
    this._listGroups,
    this._listExpenses,
    this._createExpense,
    this._updateExpense,
    this._deleteExpense,
    this._createGroup,
    this._listFriends,
    this._getProfile,
  );

  SplitStatus status = SplitStatus.loading;
  SplitError? error;

  /// The caller's own user id (design D5c). Resolved by [load]; `null`
  /// until then or if resolving it failed (in which case [status] is
  /// [SplitStatus.error] with [error] `profileFailed` — never carried
  /// forward as `null` into the gates that need it).
  String? selfUserId;

  List<Balance> balances = [];
  List<SplitGroup> groups = [];
  List<SplitExpense> expenses = [];

  /// Candidate list for a group-less expense's payer/participants: the
  /// caller's friends (design D5b — reused from the social context's own
  /// `ListFriends`, not a second friends path on `SplitRepository`).
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

  /// The finance shell can be left from any state, including while a request
  /// is still in flight — at which point this controller is already disposed
  /// by the time the response lands, and a plain `notifyListeners` would
  /// throw "used after being disposed". Same guard as `FriendsController`.
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  /// Loads balances, groups, expenses, friend candidates, and the caller's
  /// own profile. The profile is fetched first and gates everything else:
  /// if it fails, the tab goes straight to an error/reauth state rather
  /// than loading split data under a `null` self id (design D5c).
  Future<void> load(String idToken) async {
    status = SplitStatus.loading;
    error = null;

    try {
      final profile = await _getProfile(idToken);
      selfUserId = profile.id;
    } on ReauthenticationRequired {
      status = SplitStatus.needsReauth;
      _notify();
      return;
    } catch (_) {
      status = SplitStatus.error;
      error = SplitError.profileFailed;
      _notify();
      return;
    }

    try {
      final results = await Future.wait([
        _getBalances(idToken),
        _listGroups(idToken),
        _listExpenses(idToken),
        _listFriends(idToken),
      ]);
      balances = results[0] as List<Balance>;
      groups = results[1] as List<SplitGroup>;
      expenses = results[2] as List<SplitExpense>;
      friends = results[3] as List<Friend>;
      status = SplitStatus.loaded;
    } on SplitReauthenticationRequired {
      status = SplitStatus.needsReauth;
    } on SocialReauthenticationRequired {
      status = SplitStatus.needsReauth;
    } catch (_) {
      status = SplitStatus.error;
      error = SplitError.fetchFailed;
    }
    _notify();
  }

  Future<void> createGroup(String idToken, String name) => _mutate(idToken, () async {
    await _createGroup(idToken, name);
    await load(idToken);
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
  }) => _mutate(idToken, () async {
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
    await load(idToken);
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
  }) => _mutate(idToken, () async {
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
    await load(idToken);
  });

  @override
  Future<void> deleteExpense(String idToken, String expenseId) => _mutate(idToken, () async {
    await _deleteExpense(idToken, expenseId);
    await load(idToken);
  });

  /// Runs a write [action], mapping a reauth failure onto [status] (like
  /// `FinanceController._mutate`) and anything else onto [mutationError] —
  /// deliberately *not* onto [status]/[error], so the previously loaded
  /// balances/groups/expenses stay on screen and a caller (the expense
  /// sheet, the create-group dialog) can show a transient, specific failure
  /// while leaving every typed field exactly as it was.
  Future<void> _mutate(String idToken, Future<void> Function() action) async {
    try {
      await action();
      return;
    } on SplitReauthenticationRequired {
      status = SplitStatus.needsReauth;
    } catch (e) {
      mutationError = e;
      mutationErrorSeq++;
    }
    _notify();
  }
}
