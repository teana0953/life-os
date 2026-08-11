import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../auth/domain/auth_repository.dart';
import '../../split/domain/settlement.dart';
import '../../split/domain/split_expense.dart';
import '../../split/presentation/settle_up_sheet.dart';
import '../../split/presentation/split_activity_controller.dart';
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
import '../domain/finance_repository.dart';
import '../domain/installment_plan.dart';
import 'finance_controller.dart';
import 'finance_overview_tab.dart';
import 'finance_transactions_tab.dart';
import 'installment_plan_screen.dart';
import 'installment_plan_sheet.dart';
import 'networth_controller.dart';
import 'networth_tab.dart';
import 'snapshot_input_sheet.dart';
import '../../../shared/auth/id_token_provider.dart';

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

  /// Only for the instalment-plan screens, which talk to the plan endpoints
  /// directly rather than through [controller] — the controller's job is the
  /// month, and a plan is not month-shaped.
  final FinanceRepository financeRepository;
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
    required this.financeRepository,
    required this.split,
    this.clock = DateTime.now,
  });

  @override
  State<FinanceScaffold> createState() => _FinanceScaffoldState();
}

/// The 分帳 destination's index in the nav bar below — named because two
/// places select it now: the bar itself, and the mirrored-transaction sheet's
/// exit.
const _splitTabIndex = 3;

class _FinanceScaffoldState extends State<FinanceScaffold> {
  int _index = 0;

  /// Whether the entry load has run — the gate for the first-frame spinner in
  /// [build]. A *flag*, deliberately not the token: this scaffold is one of
  /// the long-mounted shells issue #106 is about, so the token is re-resolved
  /// per request by [_idToken] instead of being cached here.
  bool _bootstrapped = false;

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

  /// Drives the 分帳 tab's 變更紀錄 section. Per-`State` for the same reason
  /// as [_splitController]; it resolves its own token per request through
  /// [_idToken], since it issues requests as the reader scrolls.
  late final SplitActivityController _splitActivityController;

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
    )..addListener(_onSplitChanged);
    _splitActivityController = SplitActivityController(
      listActivity: widget.split.listActivity,
      // Its own profile request, not `_splitController.selfUserId` — see
      // `SplitActivityController.selfUserId`.
      getProfile: widget.split.getProfile,
      idToken: _idToken,
    );
    // Post-frame, not called directly from `initState`: `load`'s first
    // synchronous work (before its own first await) must not run as part of
    // this widget's own build — see FinanceController's no-sync-notify rule.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_load()));
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    widget.netWorthController.removeListener(_onChanged);
    _splitController.removeListener(_onSplitChanged);
    _splitController.dispose();
    _splitActivityController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// The last [SplitController.writeSeq] this scaffold has already reacted to.
  int _splitWriteSeq = 0;

  /// The 分帳 tab changed. Every split write funnels through
  /// `SplitController._mutate`, which bumps `writeSeq` on success — and every
  /// one of those writes is also a row of the 變更紀錄 change log, which is
  /// fetched separately and would otherwise sit there unmoved. That is the
  /// worst possible screen to go stale on: the 記一筆 FAB is deliberately kept
  /// on it, so the reader records an expense while looking straight at the
  /// log that promises to hold everything that happened, and watches nothing
  /// appear. Keyed off the counter, not called from each write's call site,
  /// so a write added later cannot forget to do it.
  void _onSplitChanged() {
    if (_splitController.writeSeq != _splitWriteSeq) {
      _splitWriteSeq = _splitController.writeSeq;
      unawaited(_splitActivityController.refreshIfLoaded());
      unawaited(_reloadLedger());
    }
    _onChanged();
  }

  /// Refetches the ledger month a split write may have changed.
  ///
  /// The payer's own share of a split expense is a real transaction, written
  /// server-side (backend #79), so 總覽's totals and 明細's list are stale the
  /// moment a split write lands — and switching destinations does not
  /// refetch, so nothing else would ever correct them (issue #160). Called
  /// for every split write rather than only the expense ones: a repayment or
  /// a deleted expense moves the same numbers, and keying it off `writeSeq`
  /// is what keeps a write added later from forgetting.
  ///
  /// Nothing here awaits a month check — a write dated outside the selected
  /// month lands in a month this reload does not fetch, and that is correct:
  /// the ledger shows one month at a time and the reader is looking at this
  /// one.
  Future<void> _reloadLedger() async {
    final month = widget.controller.selectedMonth.isEmpty
        ? monthOf(_todayDate)
        : widget.controller.selectedMonth;
    final token = await _idToken();
    if (!mounted) return;
    await widget.controller.load(token, month);
  }

  String get _todayDate => dayString(widget.clock());

  /// A fresh id token per request (see [IdTokenProvider]); the shape
  /// `FriendsScreen._token` uses.
  Future<String> _idToken() => guardedIdToken(widget.authRepository);

  Future<void> _load() async {
    final token = await _idToken();
    if (!mounted) return;
    setState(() => _bootstrapped = true);
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
    if (_netWorthLoaded) return;
    _netWorthLoaded = true;
    final month = widget.netWorthController.selectedMonth.isEmpty
        ? monthOf(_todayDate)
        : widget.netWorthController.selectedMonth;
    await widget.netWorthController.load(await _idToken(), month);
  }

  Future<void> _switchNetWorthMonth(String month) async {
    await widget.netWorthController.load(await _idToken(), month, notifyOnStart: true);
  }

  /// Loads the 分帳 tab the first time it's opened *in this scaffold*,
  /// mirroring [_loadNetWorth]. Unlike net worth, [_splitController] is
  /// itself per-`State` (design.md), so re-entering finance always gets a
  /// fresh controller and a fresh load without needing this flag for
  /// correctness — it exists only so re-selecting an already-open tab
  /// doesn't re-fetch on every tap.
  Future<void> _loadSplit() async {
    if (_splitLoaded) return;
    _splitLoaded = true;
    await _splitController.load(await _idToken());
  }

  /// A genuine retry (the tab's retry button) always re-fetches, bypassing
  /// [_splitLoaded] — a stale-profile or fetch failure must not be stuck
  /// forever behind the "only load once" gate above.
  Future<void> _retrySplit() async {
    await _splitController.load(await _idToken());
  }

  Future<void> _openSplitExpenseSheet({SplitExpense? editing}) async {
    final selfUserId = _splitController.selfUserId;
    if (selfUserId == null) return;
    await showAppSheet<void>(
      context,
      builder: (_) => SplitExpenseSheet(
        writer: _splitController,
        idToken: _idToken,
        selfUserId: selfUserId,
        today: _todayDate,
        groups: _splitController.groups,
        friends: _splitController.friends,
        editing: editing,
        // Already loaded for the ledger tabs' own category grid — this
        // scaffold is the one call site that has them without a second
        // request.
        financeCategories: widget.controller.categories,
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
    final selfUserId = _splitController.selfUserId;
    if (selfUserId == null) return;
    await showAppSheet<void>(
      context,
      builder: (_) => SettleUpSheet(
        writer: _splitController,
        idToken: _idToken,
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
    final selfUserId = _splitController.selfUserId;
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
    await _splitController.deleteSettlement(await _idToken(), settlement.id);
    if (!mounted || _splitController.mutationErrorSeq == seqBefore) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(splitErrorText(loc, _splitController.mutationError!))));
  }

  Future<void> _openCreateGroupDialog() async {
    final loc = AppLocalizations.of(context)!;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _CreateGroupDialog(),
    );
    if (name == null || !mounted) return;
    final seqBefore = _splitController.mutationErrorSeq;
    await _splitController.createGroup(await _idToken(), name);
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
    // The change log too: group detail's writes go through its *own*
    // controller, so `writeSeq` never moves for them and [_onSplitChanged]
    // never fires.
    unawaited(_splitActivityController.refreshIfLoaded());
    // And the ledger: an expense added in the group mirrors into it the same
    // way one added here does (see [_reloadLedger]), and for the same reason
    // as the line above — `writeSeq` never moves for group detail's writes,
    // so [_onSplitChanged]'s reload never fires for them.
    unawaited(_reloadLedger());
    await _retrySplit();
  }

  Future<void> _openSnapshotSheet(NetWorthAccount account) async {
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
        idToken: _idToken,
        account: account,
        currentValue: currentValue,
      ),
    );
  }

  Future<void> _openAccountManageSheet() async {
    await showAppSheet<void>(
      context,
      builder: (_) => AccountManageSheet(controller: widget.netWorthController, idToken: _idToken),
    );
  }

  Future<void> _switchMonth(String month) async {
    // notifyOnStart: this is a user-gesture call (the month switcher or a
    // retry tap), not the initial entry load, so it's safe to notify before
    // the fetch resolves — giving the switch immediate loading feedback
    // instead of leaving the old month's content on screen while it loads.
    await widget.controller.load(await _idToken(), month, notifyOnStart: true);
  }

  /// Selects the 分帳 destination, with the same side effects tapping it in
  /// the nav bar has (the lazy build gate and the first-open load) — the only
  /// destination this scaffold switches to from anywhere but that bar.
  ///
  /// Deliberately only the tab, not the individual expense: there is no route
  /// for a single split, and a mirrored transaction carries no group id
  /// either. A half-built deep link would look like one and land nowhere.
  void _goToSplitTab() {
    setState(() {
      _index = _splitTabIndex;
      _splitOpened = true;
    });
    unawaited(_loadSplit());
  }

  Future<void> _openSheet({FinanceTransaction? editing}) async {
    await showAppSheet<void>(
      context,
      builder: (_) => AddTransactionSheet(
        controller: widget.controller,
        idToken: _idToken,
        categories: widget.controller.categories,
        today: _todayDate,
        editing: editing,
        // Close the sheet before switching tabs, same as the split sheet's
        // `onAddFriend` above: the sheet is a modal route this scaffold
        // pushed, and swapping the tab underneath it would leave it stranded
        // on top of the split tab.
        onGoToSplit: () {
          Navigator.of(context).pop();
          _goToSplitTab();
        },
        // Same reason as `onGoToSplit`: pop the sheet before pushing the plan
        // screen, or the sheet is left stranded under it.
        onGoToPlan: (plan) {
          Navigator.of(context).pop();
          _openPlanScreen(plan);
        },
      ),
    );
  }

  Future<void> _openPlanScreen(InstallmentPlan plan) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => InstallmentPlanScreen(
          plan: plan,
          repository: widget.financeRepository,
          idToken: _idToken,
        ),
      ),
    );
    // A settle rewrites the month's transactions, so the ledger behind this
    // screen is stale the moment it returns.
    if (!mounted) return;
    await widget.controller.load(await _idToken(), widget.controller.selectedMonth);
  }

  Future<void> _openInstallmentPlanSheet() async {
    await showAppSheet<void>(
      context,
      builder: (_) => InstallmentPlanSheet(
        repository: widget.financeRepository,
        idToken: _idToken,
        categories: widget.controller.categories,
        today: _todayDate,
      ),
    );
    if (!mounted) return;
    await widget.controller.load(await _idToken(), widget.controller.selectedMonth);
  }

  /// Opens the assistant carrying what this scaffold is showing right now —
  /// the active tab and *its* month — as `/assistant` query parameters, so
  /// the context survives a web refresh (`AssistantChatContext.fromQuery`
  /// rebuilds it from the URL).
  ///
  /// The month is per-tab: the ledger tabs share [FinanceController]'s
  /// month, 淨值 keeps its own (see [NetWorthController]), and 分帳 has no
  /// month at all — sending the ledger's month from those two would put a
  /// view on the URL that this screen never showed.
  ///
  /// Awaited, then reloaded (the `_openPlanScreen` shape): the assistant can
  /// record a transaction, so the ledger behind it is stale the moment the
  /// user returns — a fire-and-forget push would show them a ledger missing
  /// the entry they just watched the assistant save.
  Future<void> _openAssistant() async {
    const tabs = ['overview', 'transactions', 'networth', 'split'];
    final month = switch (_index) {
      0 || 1 => widget.controller.selectedMonth,
      2 => widget.netWorthController.selectedMonth,
      _ => '',
    };
    final uri = Uri(
      path: '/assistant',
      queryParameters: {
        'ctx': 'finance',
        'tab': tabs[_index],
        if (month.isNotEmpty) 'month': month,
      },
    );
    await context.push(uri.toString());
    if (!mounted) return;
    await widget.controller.load(await _idToken(), widget.controller.selectedMonth);
  }

  Future<void> _openBudgetSheet() async {
    await showAppSheet<void>(
      context,
      builder: (_) => BudgetSheet(controller: widget.controller, idToken: _idToken),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final controller = widget.controller;

    if (!_bootstrapped) {
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
        actions: [
          // Labelled, not an icon-only `IconButton`: its tooltip is the only
          // thing that named it, and a tooltip needs a hover or a long-press
          // — on the phone/PWA this app is used on, that left a bare robot
          // glyph in the app bar's utility corner meaning nothing.
          TextButton.icon(
            key: const Key('finance-assistant-button'),
            icon: const Icon(Icons.smart_toy_outlined),
            // The app bar's title ellipsizes to make room for actions, so a
            // long translation at a large text scale would eat the tab name
            // whole before it ever overflowed. Capped and ellipsized here so
            // the pressure stops at this label instead.
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 96),
              child: Text(loc.assistantOpenButton, overflow: TextOverflow.ellipsis),
            ),
            onPressed: () => unawaited(_openAssistant()),
          ),
        ],
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
              activityController: _splitActivityController,
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
      //
      // On 分帳 it is shown only once the caller's own user id is known.
      // `_openSplitExpenseSheet` cannot build the sheet without it (there is
      // no "you" to pre-select, and the share gate has nothing to check), and
      // returned early — so after a `SplitError.profileFailed`, or simply
      // before the first load lands, the FAB sat there on a page that
      // otherwise looks healthy and did *nothing at all* when tapped. The
      // change-log section makes that worse, not better: it renders its own
      // entries fine from its own profile request, so the whole screen looks
      // loaded. A button that is absent is honest; one that swallows taps is
      // not, and the overview's retry is the way back.
      floatingActionButton: _index == 2
          ? null
          : _index == 3
          ? _splitController.selfUserId == null
                ? null
                : FloatingActionButton(
                    key: const Key('split-fab'),
                    // Explicit, distinct hero tags: switching tabs cross-fades
                    // one FAB into the other, and for those ~200ms both are in
                    // the tree. On Flutter's default tag any route transition
                    // started in that window (back, opening a group) finds two
                    // heroes sharing a tag and throws.
                    heroTag: 'split-fab',
                    tooltip: loc.splitFabTooltip,
                    onPressed: () => _openSplitExpenseSheet(),
                    child: const Icon(Icons.add),
                  )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // A second, smaller button rather than a menu on the main FAB:
                // recording one charge is the overwhelmingly common action and
                // must stay a single tap. Setting up a recurring one is rare,
                // deliberate, and takes a form either way, so paying one extra
                // tap for it costs nothing and keeps the common path untouched.
                FloatingActionButton.small(
                  key: const Key('finance-installment-fab'),
                  heroTag: 'finance-installment-fab',
                  tooltip: loc.financeInstallmentFabTooltip,
                  onPressed: () => _openInstallmentPlanSheet(),
                  child: const Icon(Icons.event_repeat),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  key: const Key('finance-fab'),
                  heroTag: 'finance-fab',
                  tooltip: loc.financeFabTooltip,
                  onPressed: () => _openSheet(),
                  child: const Icon(Icons.add),
                ),
              ],
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
            if (value == _splitTabIndex) _splitOpened = true;
          });
          if (value == 2) unawaited(_loadNetWorth());
          if (value == _splitTabIndex) unawaited(_loadSplit());
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
