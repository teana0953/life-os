import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../auth/domain/auth_repository.dart';
import '../../split/domain/settlement.dart';
import '../../split/domain/split_expense.dart';
import '../../split/presentation/settle_up_sheet.dart';
import '../../split/presentation/split_controller.dart';
import '../../split/presentation/split_error_text.dart';
import '../../split/presentation/split_expense_sheet.dart';
import '../../split/presentation/split_tab.dart';
import '../../split/presentation/split_tab_dependencies.dart';
import '../domain/finance_money.dart';
import '../domain/finance_month.dart';
import '../domain/finance_transaction.dart';
import '../domain/networth_account.dart';
import 'account_manage_sheet.dart';
import 'add_transaction_sheet.dart';
import 'budget_sheet.dart';
import 'finance_controller.dart';
import 'finance_overview_tab.dart';
import 'finance_transactions_tab.dart';
import 'networth_controller.dart';
import 'networth_tab.dart';
import 'snapshot_input_sheet.dart';

/// The finance module's home: a persistent bottom-nav scaffold with three
/// destinations — 總覽 (monthly overview) and 明細 (transaction list), which
/// share one selected month (design.md), plus 淨值 (net worth), which
/// deliberately keeps **its own** month (see [NetWorthController]) — and a FAB
/// that opens the record sheet from the two ledger tabs. Owns the auth-token
/// load, mirroring `HealthScaffold`.
///
/// A fourth destination, 分帳, is always rendered — see
/// [SplitTabDependencies] for what wires it. Unlike [netWorthController] (an
/// app-lifetime singleton built in `main.dart`), the split tab's
/// `SplitController` is built and disposed by **this widget's own `State`**
/// (design.md) — unwiring the exact leak `netWorthController` needs
/// `_resetControllersOnSignOut` to work around.
class FinanceScaffold extends StatefulWidget {
  final AuthRepository authRepository;
  final FinanceController controller;
  final NetWorthController netWorthController;
  final SplitTabDependencies split;

  /// Returns the current time, used to resolve "today" (the initial month
  /// and the record sheet's default date). Defaults to [DateTime.now];
  /// tests inject a fixed clock.
  final DateTime Function() clock;

  const FinanceScaffold({
    super.key,
    required this.authRepository,
    required this.controller,
    required this.netWorthController,
    required this.split,
    this.clock = DateTime.now,
  });

  @override
  State<FinanceScaffold> createState() => _FinanceScaffoldState();
}

class _FinanceScaffoldState extends State<FinanceScaffold> {
  int _index = 0;
  String? _idToken;

  /// Whether the 淨值 tab has ever been opened (see the IndexedStack below).
  bool _netWorthOpened = false;

  /// Whether [_loadNetWorth] has already run **for this State**. Deliberately
  /// not derived from `netWorthController.selectedMonth`: that controller is
  /// an app-lifetime singleton, so a non-empty month there only means *some*
  /// earlier visit loaded it — re-entering finance would then never refetch,
  /// and a newly signed-in user could be shown the previous user's figures.
  bool _netWorthLoaded = false;

  /// Built in [initState], released in [dispose] — **not** an app-lifetime
  /// singleton like [FinanceScaffold.netWorthController] (class doc).
  late final SplitController _splitController;

  /// Whether the 分帳 tab has ever been opened (mirrors [_netWorthOpened] —
  /// the same `IndexedStack`-builds-every-child reason).
  bool _splitOpened = false;

  /// Whether [_loadSplit] has already run for this `State` (mirrors
  /// [_netWorthLoaded]). Unlike net worth this controller is per-`State`
  /// already, so a leftover-singleton refetch bug can't happen here — the
  /// flag still exists so re-selecting the tab without leaving finance
  /// doesn't re-fetch on every tap.
  bool _splitLoaded = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    widget.netWorthController.addListener(_onChanged);
    _splitController = SplitController(
      widget.split.getBalances,
      widget.split.listGroups,
      widget.split.listExpenses,
      widget.split.createExpense,
      widget.split.updateExpense,
      widget.split.deleteExpense,
      widget.split.createGroup,
      widget.split.listFriends,
      widget.split.getProfile,
      widget.split.listSettlements,
      widget.split.createSettlement,
      widget.split.deleteSettlement,
    )..addListener(_onChanged);
    // Post-frame, not called directly from `initState`: `load`'s first
    // synchronous work (before its own first await) must not run as part of
    // this widget's own build — see FinanceController's no-sync-notify rule.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_load()));
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    widget.netWorthController.removeListener(_onChanged);
    _splitController.removeListener(_onChanged);
    _splitController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  String get _todayDate => dayString(widget.clock());

  Future<void> _load() async {
    final token = await widget.authRepository.idToken() ?? '';
    if (!mounted) return;
    setState(() => _idToken = token);
    final month = widget.controller.selectedMonth.isEmpty
        ? monthOf(_todayDate)
        : widget.controller.selectedMonth;
    await widget.controller.load(token, month);
  }

  /// Loads the 淨值 tab the first time it's opened *in this scaffold*. It is
  /// deliberately *not* loaded alongside the ledger: its month is its own, and
  /// its data is only needed once the user actually opens the tab. Mirroring
  /// [_load], the month the user last looked at is kept across a re-entry —
  /// only the data is refetched.
  Future<void> _loadNetWorth() async {
    final idToken = _idToken;
    if (idToken == null || _netWorthLoaded) return;
    _netWorthLoaded = true;
    final month = widget.netWorthController.selectedMonth.isEmpty
        ? monthOf(_todayDate)
        : widget.netWorthController.selectedMonth;
    await widget.netWorthController.load(idToken, month);
  }

  Future<void> _switchNetWorthMonth(String month) async {
    final idToken = _idToken;
    if (idToken == null) return;
    await widget.netWorthController.load(idToken, month, notifyOnStart: true);
  }

  /// Loads the 分帳 tab the first time it's opened *in this scaffold*,
  /// mirroring [_loadNetWorth]. Unlike net worth, [_splitController] is
  /// itself per-`State` (design.md), so re-entering finance always gets a
  /// fresh controller and a fresh load without needing this flag for
  /// correctness — it exists only so re-selecting an already-open tab
  /// doesn't re-fetch on every tap.
  Future<void> _loadSplit() async {
    final idToken = _idToken;
    if (idToken == null || _splitLoaded) return;
    _splitLoaded = true;
    await _splitController.load(idToken);
  }

  /// A genuine retry (the tab's retry button) always re-fetches, bypassing
  /// [_splitLoaded] — a stale-profile or fetch failure must not be stuck
  /// forever behind the "only load once" gate above.
  Future<void> _retrySplit() async {
    final idToken = _idToken;
    if (idToken == null) return;
    await _splitController.load(idToken);
  }

  Future<void> _openSplitExpenseSheet({SplitExpense? editing}) async {
    final idToken = _idToken;
    final selfUserId = _splitController.selfUserId;
    if (idToken == null || selfUserId == null) return;
    await showAppSheet<void>(
      context,
      builder: (_) => SplitExpenseSheet(
        writer: _splitController,
        idToken: idToken,
        selfUserId: selfUserId,
        today: _todayDate,
        groups: _splitController.groups,
        friends: _splitController.friends,
        editing: editing,
        // Close the sheet before leaving for the friends page: the sheet is
        // an imperative modal route this scaffold pushed, and a router
        // navigation underneath it would leave it stranded on top of the
        // new page.
        onAddFriend: () {
          Navigator.of(context).pop();
          widget.split.onAddFriend(context);
        },
      ),
    );
  }

  /// Opens the settle-up sheet for one currency of a two-person balance
  /// (design D0–D2). A successful submission already reloads
  /// [_splitController] itself (`SplitController.createSettlement`'s
  /// `_mutate`/`load` path), so nothing further is needed here on return.
  Future<void> _openSettleUpSheet({
    required String otherUserId,
    required String? otherDisplayName,
    required int balanceAmount,
    required String currency,
  }) async {
    final idToken = _idToken;
    final selfUserId = _splitController.selfUserId;
    if (idToken == null || selfUserId == null) return;
    await showAppSheet<void>(
      context,
      builder: (_) => SettleUpSheet(
        writer: _splitController,
        idToken: idToken,
        selfUserId: selfUserId,
        otherUserId: otherUserId,
        otherDisplayName: otherDisplayName,
        balanceAmount: balanceAmount,
        currency: currency,
        today: _todayDate,
      ),
    );
  }

  /// Confirms and deletes a repayment (design D4) — naming the other person
  /// and the amount, mirroring `SplitExpenseSheet._delete`'s confirmation
  /// shape but as a standalone dialog since a repayment has no edit sheet to
  /// host it in.
  Future<void> _confirmDeleteSettlement(Settlement settlement) async {
    final idToken = _idToken;
    final selfUserId = _splitController.selfUserId;
    if (idToken == null) return;
    final loc = AppLocalizations.of(context)!;
    final otherName = settlement.fromUserId == selfUserId
        ? (settlement.toDisplayName ?? loc.splitUnknownMember)
        : (settlement.fromDisplayName ?? loc.splitUnknownMember);
    final amountText = formatMinorUnitsForDisplay(settlement.amount, settlement.currency);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(loc.splitDeleteSettlementConfirmTitle),
        content: Text(loc.splitDeleteSettlementConfirmMessage(otherName, amountText)),
        actions: [
          TextButton(
            key: const Key('split-delete-settlement-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            key: const Key('split-delete-settlement-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(loc.splitDeleteSettlementConfirmButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final seqBefore = _splitController.mutationErrorSeq;
    await _splitController.deleteSettlement(idToken, settlement.id);
    if (!mounted || _splitController.mutationErrorSeq == seqBefore) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(splitErrorText(loc, _splitController.mutationError!))));
  }

  Future<void> _openCreateGroupDialog() async {
    final idToken = _idToken;
    if (idToken == null) return;
    final loc = AppLocalizations.of(context)!;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _CreateGroupDialog(),
    );
    if (name == null || !mounted) return;
    final seqBefore = _splitController.mutationErrorSeq;
    await _splitController.createGroup(idToken, name);
    // Without this the dialog simply closes and the group is not there:
    // `_mutate` records the failure on `mutationErrorSeq` and nothing else
    // reads it. Same shape as `SplitExpenseSheet._save`.
    if (!mounted || _splitController.mutationErrorSeq == seqBefore) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(splitErrorText(loc, _splitController.mutationError!))));
  }

  /// Opens a group's detail screen and reloads the split tab once the user
  /// comes back (task 8.1b). Group detail can add an expense or archive the
  /// group, either of which the balances/groups/expenses shown here must
  /// reflect; a genuinely `void` `onOpenGroup` couldn't signal "the user has
  /// returned" at all, so [SplitTabDependencies.onOpenGroup] returns a
  /// `Future` that completes on return (mirrors `DietDayScreen`'s own
  /// await-push-then-reload) and this reloads unconditionally rather than
  /// threading a "did anything change" result back out of every mutation
  /// group detail can make.
  Future<void> _openGroupDetail(String groupId) async {
    await widget.split.onOpenGroup(context, groupId);
    if (!mounted) return;
    await _retrySplit();
  }

  Future<void> _openSnapshotSheet(NetWorthAccount account) async {
    final idToken = _idToken;
    if (idToken == null) return;
    int? currentValue;
    for (final value in widget.netWorthController.monthly?.accounts ?? const []) {
      if (value.accountId == account.id) currentValue = value.value;
    }
    // The concrete case behind `showAppSheet`'s drag handle: with many
    // accounts this sheet fills the viewport, and without the handle the
    // scrim is gone and the drag is swallowed by the content's own
    // scrolling.
    await showAppSheet<void>(
      context,
      builder: (_) => SnapshotInputSheet(
        controller: widget.netWorthController,
        idToken: idToken,
        account: account,
        currentValue: currentValue,
      ),
    );
  }

  Future<void> _openAccountManageSheet() async {
    final idToken = _idToken;
    if (idToken == null) return;
    await showAppSheet<void>(
      context,
      builder: (_) => AccountManageSheet(controller: widget.netWorthController, idToken: idToken),
    );
  }

  Future<void> _switchMonth(String month) async {
    final idToken = _idToken;
    if (idToken == null) return;
    // notifyOnStart: this is a user-gesture call (the month switcher or a
    // retry tap), not the initial entry load, so it's safe to notify before
    // the fetch resolves — giving the switch immediate loading feedback
    // instead of leaving the old month's content on screen while it loads.
    await widget.controller.load(idToken, month, notifyOnStart: true);
  }

  Future<void> _openSheet({FinanceTransaction? editing}) async {
    final idToken = _idToken;
    if (idToken == null) return;
    await showAppSheet<void>(
      context,
      builder: (_) => AddTransactionSheet(
        controller: widget.controller,
        idToken: idToken,
        categories: widget.controller.categories,
        today: _todayDate,
        editing: editing,
      ),
    );
  }

  Future<void> _openBudgetSheet() async {
    final idToken = _idToken;
    if (idToken == null) return;
    await showAppSheet<void>(
      context,
      builder: (_) => BudgetSheet(controller: widget.controller, idToken: idToken),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final controller = widget.controller;
    final idToken = _idToken;

    if (idToken == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(key: Key('finance-loading'))),
      );
    }

    // Loading/reauth are each tab's own responsibility (via
    // AsyncStateScaffold, design.md), not handled here — so the bottom nav
    // and FAB stay usable (e.g. switching tabs) even while one is loading.
    return Scaffold(
      appBar: AppBar(
        title: Text(
          [
            loc.financeTabOverview,
            loc.financeTabTransactions,
            loc.financeTabNetWorth,
            loc.financeTabSplit,
          ][_index],
        ),
      ),
      body: IndexedStack(
        index: _index,
        children: [
          FinanceOverviewTab(
            controller: controller,
            onSwitchMonth: _switchMonth,
            onAdd: () => _openSheet(),
            onEditBudgets: _openBudgetSheet,
            onSignInAgain: () => unawaited(widget.authRepository.signOut()),
          ),
          FinanceTransactionsTab(
            controller: controller,
            onEdit: (txn) => _openSheet(editing: txn),
            onSwitchMonth: _switchMonth,
            onSignInAgain: () => unawaited(widget.authRepository.signOut()),
          ),
          // Built only once the 淨值 tab has actually been opened: an
          // IndexedStack builds every child, and an unopened tab would
          // otherwise sit here spinning forever on a load that was never
          // started.
          if (_netWorthOpened)
            NetWorthTab(
              controller: widget.netWorthController,
              onSwitchMonth: _switchNetWorthMonth,
              onEditAccountValue: _openSnapshotSheet,
              onManageAccounts: _openAccountManageSheet,
              onSignInAgain: () => unawaited(widget.authRepository.signOut()),
            )
          else
            const SizedBox.shrink(),
          // Same lazy-build gate as 淨值 above: an IndexedStack builds every
          // child, and an unopened tab would otherwise sit here spinning
          // forever on a load that was never started.
          if (_splitOpened)
            SplitTab(
              controller: _splitController,
              onRetry: () => unawaited(_retrySplit()),
              onRecordExpense: () => _openSplitExpenseSheet(),
              onOpenGroup: _openGroupDetail,
              onCreateGroup: _openCreateGroupDialog,
              onEditExpense: (expense) => _openSplitExpenseSheet(editing: expense),
              onAddFriend: () => widget.split.onAddFriend(context),
              onSettleUp: ({
                required otherUserId,
                required otherDisplayName,
                required balanceAmount,
                required currency,
              }) => _openSettleUpSheet(
                otherUserId: otherUserId,
                otherDisplayName: otherDisplayName,
                balanceAmount: balanceAmount,
                currency: currency,
              ),
              onDeleteSettlement: _confirmDeleteSettlement,
              onSignInAgain: () => unawaited(widget.authRepository.signOut()),
            )
          else
            const SizedBox.shrink(),
        ],
      ),
      // The 淨值 tab has no use for the record-transaction FAB; the 分帳 tab
      // gets its own FAB (recording a split expense, not a transaction) —
      // the previous `_index == 2` check alone would otherwise leave the
      // *transaction* FAB showing on top of the split tab.
      floatingActionButton: _index == 2
          ? null
          : _index == 3
          ? FloatingActionButton(
              key: const Key('split-fab'),
              // Explicit, distinct hero tags: switching tabs cross-fades one
              // FAB into the other, and for those ~200ms both are in the
              // tree. On Flutter's default tag any route transition started
              // in that window (back, opening a group) finds two heroes
              // sharing a tag and throws.
              heroTag: 'split-fab',
              tooltip: loc.splitFabTooltip,
              onPressed: () => _openSplitExpenseSheet(),
              child: const Icon(Icons.add),
            )
          : FloatingActionButton(
              key: const Key('finance-fab'),
              heroTag: 'finance-fab',
              tooltip: loc.financeFabTooltip,
              onPressed: () => _openSheet(),
              child: const Icon(Icons.add),
            ),
      // A taller bar at large text scales, rather than the Material
      // default's fixed 80dp: `NavigationBar` builds each label as a bare
      // `Text` with no `maxLines`, so at textScale 2.0 on a 320dp screen a
      // two-word label ("Transactions", "Net worth") wraps to two lines and
      // paints ~10dp *below* the bar — silently clipped, raising no layout
      // error at all. Four destinations narrow each slot to 80dp, which is
      // what tips those labels over. Growing the bar keeps the label at the
      // size the user asked for instead of clamping their text scale away.
      //
      // `max` against 80 — Material 3's own `NavigationBar` height — bounds
      // this deliberately: up to 80/70 ≈ 1.14 the bar is byte-for-byte the
      // one 總覽/交易/淨值 had before this change, so ordinary text scales
      // see no chrome change at all. Above that threshold it does grow for
      // all four destinations, which is the intended trade: that is exactly
      // where their labels have outgrown the default too.
      // Pinned by split_layout_test.dart's nav-bar guard (both halves: the
      // slot-containment sweep, and the height at 1.0/1.14/2.0).
      bottomNavigationBar: NavigationBar(
        height: math.max(80, MediaQuery.textScalerOf(context).scale(70)),

        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() {
            _index = value;
            if (value == 2) _netWorthOpened = true;
            if (value == 3) _splitOpened = true;
          });
          if (value == 2) unawaited(_loadNetWorth());
          if (value == 3) unawaited(_loadSplit());
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: loc.financeTabOverview,
          ),
          NavigationDestination(
            icon: const Icon(Icons.list_alt_outlined),
            selectedIcon: const Icon(Icons.list_alt),
            label: loc.financeTabTransactions,
          ),
          NavigationDestination(
            key: const Key('networth-tab'),
            icon: const Icon(Icons.savings_outlined),
            selectedIcon: const Icon(Icons.savings),
            label: loc.financeTabNetWorth,
          ),
          NavigationDestination(
            key: const Key('split-tab'),
            icon: const Icon(Icons.groups_outlined),
            selectedIcon: const Icon(Icons.groups),
            label: loc.financeTabSplit,
          ),
        ],
      ),
    );
  }
}

/// The create-group dialog, as a widget that owns its own text controller.
///
/// Not a `TextEditingController` created next to `showDialog` and disposed
/// right after it returns: the dialog keeps rebuilding through its exit
/// animation, so a controller disposed at that point is used after disposal
/// (a red screen on an ordinary "Create" tap). A `State` disposes it when
/// the route is actually gone.
class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog();

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return AlertDialog(
      scrollable: true,
      title: Text(loc.splitCreateGroupTitle),
      content: TextField(
        key: const Key('split-group-name-field'),
        controller: _nameController,
        decoration: InputDecoration(labelText: loc.splitGroupNameLabel),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          key: const Key('split-create-group-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(loc.cancel),
        ),
        FilledButton(
          key: const Key('split-create-group-confirm'),
          // Disabled rather than inert: the old version ran
          // `if (trimmed.isEmpty) return;`, so an empty name made the button
          // swallow the tap with no message and no close.
          onPressed: _nameController.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_nameController.text.trim()),
          child: Text(loc.splitCreateButton),
        ),
      ],
    );
  }
}
