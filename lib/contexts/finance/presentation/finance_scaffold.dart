import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../auth/domain/auth_repository.dart';
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
class FinanceScaffold extends StatefulWidget {
  final AuthRepository authRepository;
  final FinanceController controller;
  final NetWorthController netWorthController;

  /// Returns the current time, used to resolve "today" (the initial month
  /// and the record sheet's default date). Defaults to [DateTime.now];
  /// tests inject a fixed clock.
  final DateTime Function() clock;

  const FinanceScaffold({
    super.key,
    required this.authRepository,
    required this.controller,
    required this.netWorthController,
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

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    widget.netWorthController.addListener(_onChanged);
    // Post-frame, not called directly from `initState`: `load`'s first
    // synchronous work (before its own first await) must not run as part of
    // this widget's own build — see FinanceController's no-sync-notify rule.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_load()));
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    widget.netWorthController.removeListener(_onChanged);
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

  /// Loads the 淨值 tab the first time it's opened. It is deliberately *not*
  /// loaded alongside the ledger: its month is its own, and its data is only
  /// needed once the user actually opens the tab.
  Future<void> _loadNetWorth() async {
    final idToken = _idToken;
    if (idToken == null || widget.netWorthController.selectedMonth.isNotEmpty) {
      return;
    }
    await widget.netWorthController.load(idToken, monthOf(_todayDate));
  }

  Future<void> _switchNetWorthMonth(String month) async {
    final idToken = _idToken;
    if (idToken == null) return;
    await widget.netWorthController.load(idToken, month, notifyOnStart: true);
  }

  Future<void> _openSnapshotSheet(NetWorthAccount account) async {
    final idToken = _idToken;
    if (idToken == null) return;
    int? currentValue;
    for (final value in widget.netWorthController.monthly?.accounts ?? const []) {
      if (value.accountId == account.id) currentValue = value.value;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AccountManageSheet(
        controller: widget.netWorthController,
        idToken: idToken,
      ),
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
          ),
          FinanceTransactionsTab(
            controller: controller,
            onEdit: (txn) => _openSheet(editing: txn),
            onSwitchMonth: _switchMonth,
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
            )
          else
            const SizedBox.shrink(),
        ],
      ),
      // The FAB records a transaction, which the 淨值 tab has no use for.
      floatingActionButton: _index == 2
          ? null
          : FloatingActionButton(
              key: const Key('finance-fab'),
              tooltip: loc.financeFabTooltip,
              onPressed: () => _openSheet(),
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() {
            _index = value;
            if (value == 2) _netWorthOpened = true;
          });
          if (value == 2) unawaited(_loadNetWorth());
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
        ],
      ),
    );
  }
}
