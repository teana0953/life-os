import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/async_state_scaffold.dart';
import '../../../shared/widgets/fractional_progress_bar.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../../shared/widgets/month_nav_header.dart';
import '../domain/finance_category.dart';
import '../domain/finance_month.dart';
import '../domain/finance_money.dart';
import '../domain/finance_transaction.dart';
import '../domain/finance_type.dart';
import '../domain/monthly_summary.dart';
import 'budget_card.dart';
import 'finance_category_icons.dart';
import 'finance_controller.dart';

/// 總覽: the month switcher, per-currency expense/income/net cards, an
/// expense-category breakdown, and the five most recent transactions.
/// Loading/reauth go through [AsyncStateScaffold]; a load failure and the
/// empty-month guide are handled here (design.md — error+retry isn't one of
/// [AsyncStateScaffold]'s two built-in states, mirroring the health tabs).
class FinanceOverviewTab extends StatelessWidget {
  final FinanceController controller;
  final Future<void> Function(String month) onSwitchMonth;
  final VoidCallback onAdd;
  final VoidCallback onEditBudgets;

  const FinanceOverviewTab({
    super.key,
    required this.controller,
    required this.onSwitchMonth,
    required this.onAdd,
    required this.onEditBudgets,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return AsyncStateScaffold(
      isLoading:
          controller.status == FinanceStatus.loading && controller.summary == null,
      isReauth: controller.status == FinanceStatus.needsReauth,
      reauthMessage: loc.pleaseSignInAgain,
      builder: (context) {
        if (controller.status == FinanceStatus.error && controller.summary == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(loc.financeLoadFailed, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('finance-overview-retry'),
                    onPressed: () => onSwitchMonth(controller.selectedMonth),
                    child: Text(loc.retry),
                  ),
                ],
              ),
            ),
          );
        }

        final summary = controller.summary!;
        final isEmpty = summary.totals.isEmpty && controller.transactions.isEmpty;

        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  MonthNavHeader(
                    monthLabel: monthYearLabel(
                      context,
                      monthDateTime(controller.selectedMonth),
                    ),
                    keyPrefix: 'finance-month',
                    onPrevious: () =>
                        onSwitchMonth(previousMonth(controller.selectedMonth)),
                    onNext: () =>
                        onSwitchMonth(nextMonth(controller.selectedMonth)),
                  ),
                  const SizedBox(height: 16),
                  BudgetCard(controller: controller, onEdit: onEditBudgets),
                  const SizedBox(height: 16),
                  if (isEmpty)
                    _EmptyState(onAdd: onAdd)
                  else ...[
                    for (final total in summary.totals) ...[
                      _CurrencyTotalsCard(total: total),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 8),
                    if (summary.byCategory.isNotEmpty) ...[
                      Text(
                        loc.financeCategoryBreakdown,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      _CategoryBreakdown(
                        byCategory: summary.byCategory,
                        categories: controller.categories,
                      ),
                      const SizedBox(height: 20),
                    ],
                    Text(
                      loc.financeRecentTransactions,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _RecentTransactions(
                      transactions: controller.transactions,
                      categories: controller.categories,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One currency's expense/income/net rows (design.md — never summed across
/// currencies).
class _CurrencyTotalsCard extends StatelessWidget {
  final CurrencyTotal total;

  const _CurrencyTotalsCard({required this.total});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return LedgeCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(total.currency, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _TotalRow(
            label: loc.financeExpenseTotal,
            text: formatMinorUnits(total.expense, total.currency),
            color: theme.colorScheme.error,
          ),
          _TotalRow(
            label: loc.financeIncomeTotal,
            text: formatMinorUnits(total.income, total.currency),
            color: financeIncomeColor(theme.colorScheme),
          ),
          _TotalRow(
            label: loc.financeNetTotal,
            text:
                '${total.net < 0 ? '-' : ''}${formatMinorUnits(total.net.abs(), total.currency)}',
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String text;
  final Color? color;

  const _TotalRow({required this.label, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            text,
            style: theme.textTheme.bodyLarge?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Expense breakdown bars, per currency, category-sorted by amount
/// descending (`fractional_progress_bar` — design.md rules out fl_chart for
/// this repo's only-horizontal-bar use case).
class _CategoryBreakdown extends StatelessWidget {
  final List<CategoryAmount> byCategory;
  final List<FinanceCategory> categories;

  const _CategoryBreakdown({required this.byCategory, required this.categories});

  @override
  Widget build(BuildContext context) {
    final expenses = byCategory.where((a) => a.type == FinanceType.expense).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    if (expenses.isEmpty) return const SizedBox.shrink();

    final maxAmount = expenses.map((a) => a.amount).reduce((a, b) => a > b ? a : b);

    return LedgeCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final amount in expenses)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CategoryBar(
                amount: amount,
                category: _categoryFor(amount.categoryId),
                fraction: maxAmount == 0 ? 0 : amount.amount / maxAmount,
              ),
            ),
        ],
      ),
    );
  }

  FinanceCategory? _categoryFor(String id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }
}

class _CategoryBar extends StatelessWidget {
  final CategoryAmount amount;
  final FinanceCategory? category;
  final double fraction;

  const _CategoryBar({required this.amount, required this.category, required this.fraction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = category == null ? Icons.category : financeCategoryIcon(category!);
    final name = category?.name ?? amount.categoryId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(name, style: theme.textTheme.bodyMedium)),
            Text(
              formatMinorUnits(amount.amount, amount.currency),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 6),
        FractionalProgressBar(fraction: fraction, fillColor: theme.colorScheme.error),
      ],
    );
  }
}

/// The five most recent transactions (already the whole month's list; the
/// backend returns no ordering guarantee, so this sorts by date descending
/// itself).
class _RecentTransactions extends StatelessWidget {
  final List<FinanceTransaction> transactions;
  final List<FinanceCategory> categories;

  const _RecentTransactions({required this.transactions, required this.categories});

  @override
  Widget build(BuildContext context) {
    final sorted = List.of(transactions)..sort((a, b) => b.date.compareTo(a.date));
    final recent = sorted.take(5).toList();
    return LedgeCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (final txn in recent)
            _TransactionRow(transaction: txn, category: _categoryFor(txn.categoryId)),
        ],
      ),
    );
  }

  FinanceCategory? _categoryFor(String id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }
}

class _TransactionRow extends StatelessWidget {
  final FinanceTransaction transaction;
  final FinanceCategory? category;

  const _TransactionRow({required this.transaction, required this.category});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = category == null ? Icons.category : financeCategoryIcon(category!);
    final name = category?.name ?? transaction.categoryId;
    final color = transaction.type == FinanceType.expense
        ? theme.colorScheme.error
        : financeIncomeColor(theme.colorScheme);
    return ListTile(
      leading: Icon(icon),
      title: Text(name),
      subtitle: transaction.note == null || transaction.note!.isEmpty
          ? null
          : Text(transaction.note!),
      trailing: Text(
        formatSignedMinorUnits(transaction.amount, transaction.currency, transaction.type),
        style: theme.textTheme.bodyLarge?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Empty-month guide with a call-to-action that opens the record sheet
/// (design.md — never a blank page).
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            loc.financeEmptyTitle,
            key: const Key('finance-empty-title'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('finance-empty-cta'),
            onPressed: onAdd,
            child: Text(loc.financeEmptyCta),
          ),
        ],
      ),
    );
  }
}
