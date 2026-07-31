import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../auth/domain/auth_repository.dart';
import '../domain/finance_month.dart';
import '../domain/finance_transaction.dart';
import 'add_transaction_sheet.dart';
import 'budget_sheet.dart';
import 'finance_controller.dart';
import 'finance_overview_tab.dart';
import 'finance_transactions_tab.dart';

/// The finance module's home: a persistent bottom-nav scaffold with two
/// destinations — 總覽 (monthly overview) and 明細 (transaction list), both
/// reflecting the same selected month (design.md) — plus a FAB that opens
/// the record sheet from either tab. Owns the auth-token load, mirroring
/// `HealthScaffold`.
class FinanceScaffold extends StatefulWidget {
  final AuthRepository authRepository;
  final FinanceController controller;

  /// Returns the current time, used to resolve "today" (the initial month
  /// and the record sheet's default date). Defaults to [DateTime.now];
  /// tests inject a fixed clock.
  final DateTime Function() clock;

  const FinanceScaffold({
    super.key,
    required this.authRepository,
    required this.controller,
    this.clock = DateTime.now,
  });

  @override
  State<FinanceScaffold> createState() => _FinanceScaffoldState();
}

class _FinanceScaffoldState extends State<FinanceScaffold> {
  int _index = 0;
  String? _idToken;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    // Post-frame, not called directly from `initState`: `load`'s first
    // synchronous work (before its own first await) must not run as part of
    // this widget's own build — see FinanceController's no-sync-notify rule.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_load()));
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
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
      appBar: AppBar(title: Text(_index == 0 ? loc.financeTabOverview : loc.financeTabTransactions)),
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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('finance-fab'),
        tooltip: loc.financeFabTooltip,
        onPressed: () => _openSheet(),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
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
        ],
      ),
    );
  }
}
