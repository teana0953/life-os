import 'package:flutter/widgets.dart';

import '../../social/application/friend_use_cases.dart';
import '../../user/application/get_profile.dart';
import '../application/balance_use_cases.dart';
import '../application/expense_use_cases.dart';
import '../application/group_use_cases.dart';

/// Everything `FinanceScaffold` needs to wire the 分帳 tab, bundled into one
/// constructor field.
///
/// A composition-root convenience: `FinanceScaffold` takes a single
/// [SplitTabDependencies] rather than nine separate constructor parameters.
/// It is **required**, not optional — an earlier leg of this change made it
/// nullable purely so `lib/app.dart`'s call site kept compiling before this
/// one existed; leaving it optional past that point would let a composition
/// root silently omit it and ship a half-wired (or entirely missing) tab
/// with every test still green, which is exactly the failure mode this
/// field exists to rule out at compile time.
class SplitTabDependencies {
  final GetBalances getBalances;
  final ListGroups listGroups;
  final ListExpenses listExpenses;
  final CreateExpense createExpense;
  final UpdateExpense updateExpense;
  final DeleteExpense deleteExpense;
  final CreateGroup createGroup;
  final ListFriends listFriends;
  final GetProfile getProfile;

  /// Navigates to a group's detail screen (design.md task 8.1 — a nested
  /// `/finance/groups/:id` route, wired by `app.dart`) and completes once
  /// the caller has returned from it. Takes the tapped group's id only: the
  /// caller's own user id is **not** handed over (and so never rides in a
  /// shareable URL), because every gate on that screen depends on it and a
  /// hand-edited link must not be able to decide it — the group screen
  /// resolves it from `/api/me` itself. The `Future` it returns is what task
  /// 8.1b's return-reload is built on (`FinanceScaffold._openGroupDetail`) —
  /// a group detail screen can add an expense or archive the group, and the
  /// split tab underneath must reflect that once the user comes back.
  final Future<void> Function(BuildContext context, String groupId) onOpenGroup;

  /// Navigates to the friends page. Splitting needs at least one friend
  /// (or a group with another member in it), and nothing inside the finance
  /// shell can create one — without this, a user with no friends reaches an
  /// empty split tab and a record sheet whose Save can never be enabled,
  /// with no route onwards. Wired by `app.dart`, like [onOpenGroup].
  final void Function(BuildContext context) onAddFriend;

  const SplitTabDependencies({
    required this.getBalances,
    required this.listGroups,
    required this.listExpenses,
    required this.createExpense,
    required this.updateExpense,
    required this.deleteExpense,
    required this.createGroup,
    required this.listFriends,
    required this.getProfile,
    required this.onOpenGroup,
    required this.onAddFriend,
  });
}
