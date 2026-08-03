import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/async_state_scaffold.dart';
import '../../../shared/widgets/fractional_progress_bar.dart';
import '../../../shared/widgets/label_value_row.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../../shared/widgets/month_nav_header.dart';
import '../../../shared/widgets/month_picker_dialog.dart';
import '../domain/finance_category.dart';
import '../domain/finance_month.dart';
import '../domain/finance_money.dart';
import '../domain/finance_transaction.dart';
import '../domain/finance_type.dart';
import '../domain/monthly_summary.dart';
import '../domain/split_spending.dart';
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

  /// Opens the month picker and, if a month was chosen, switches to it through
  /// [onSwitchMonth] — the same guarded path the arrows use, so the stale-
  /// response guard still applies. No first/last bound: the arrows have none
  /// either (the ledger records both past and future months).
  Future<void> _pickMonth(BuildContext context) async {
    final picked = await showMonthPicker(
      context,
      initialMonth: monthDateTime(controller.selectedMonth),
    );
    if (picked == null) return;
    await onSwitchMonth(monthStringOf(picked));
  }

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
                    onPickMonth: () => _pickMonth(context),
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
                  else
                    for (final total in summary.totals) ...[
                      _CurrencyTotalsCard(total: total),
                      const SizedBox(height: 12),
                    ],
                  // Rendered unconditionally, outside the isEmpty/non-empty
                  // branch above (design D7/task 6.3): a month can have split
                  // shares but no recorded transactions, and that branch
                  // replaces the whole totals area with a call-to-action — the
                  // split-spending line must survive that swap rather than be
                  // hidden along with it.
                  //
                  // Placed *after* the recorded totals rather than between the
                  // budget card and them (the spec's "beside the recorded
                  // expense totals"): read top-to-bottom from the budget card
                  // it looked like part of either figure, and it is part of
                  // neither — the double-count design D6 exists to prevent.
                  if (controller.splitSpendingStatus == SplitSpendingStatus.error) ...[
                    Text(
                      loc.financeSplitSpendingLoadFailed,
                      key: const Key('finance-split-spending-error'),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    const SizedBox(height: 16),
                  ] else if (controller.splitSpending.isNotEmpty) ...[
                    _SplitSpendingCard(totals: controller.splitSpending),
                    const SizedBox(height: 16),
                  ],
                  if (!isEmpty) ...[
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
            text: formatMinorUnitsForDisplay(total.expense, total.currency),
            color: theme.colorScheme.error,
          ),
          _TotalRow(
            label: loc.financeIncomeTotal,
            text: formatMinorUnitsForDisplay(total.income, total.currency),
            color: financeIncomeColor(theme.colorScheme),
          ),
          _TotalRow(
            label: loc.financeNetTotal,
            text:
                '${total.net < 0 ? '-' : ''}${formatMinorUnitsForDisplay(total.net.abs(), total.currency)}',
          ),
        ],
      ),
    );
  }
}

/// The overview's own split-spending line (design D6) — per currency, shown
/// beside the recorded expense/income/net cards but never folded into them
/// or into the budget card ([BudgetCard] reads only [FinanceController.budgets],
/// untouched by this).
class _SplitSpendingCard extends StatelessWidget {
  final List<SplitSpending> totals;

  const _SplitSpendingCard({required this.totals});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return LedgeCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(loc.financeSplitSpendingTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          // The card is a `LedgeCard` with a bold per-currency amount, i.e.
          // visually a totals card — without this sentence nothing on the
          // screen rules out reading it as part of the expense total or of
          // the budget's consumed figure, and it is in neither (design D6).
          Text(
            loc.financeSplitSpendingNote,
            key: const Key('finance-split-spending-note'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          for (final total in totals)
            Padding(
              key: Key('finance-split-spending-${total.currency}'),
              padding: const EdgeInsets.symmetric(vertical: 2),
              // `LabelValueRow`, not `_TotalRow`: a seven-figure amount at a
              // large text scale needs the value-gets-priority-and-wraps
              // shape that row provides — `_TotalRow`'s plain `Row` overflows
              // in exactly that case (design.md task 7.4's layout guard).
              child: LabelValueRow(
                gap: 12,
                label: Text(total.currency, style: theme.textTheme.bodyMedium),
                value: Text(
                  formatMinorUnitsForDisplay(total.amount, total.currency),
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
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
      // `LabelValueRow`, not a bare `Row` with `spaceBetween`: neither child
      // of that row could yield, so a seven-figure amount — or a three-digit
      // one at a 2x text scale — overflowed to the right instead of wrapping
      // (QA measured 4.3px at 320dp/1x for 1,234,567 and 51px for 900 at
      // 320dp/2x). This is the same shape `_SplitSpendingCard` below and the
      // net-worth account rows already use; see `label_value_row.dart` for why
      // the value is the non-flex half and the label is the one that wraps.
      child: LabelValueRow(
        label: Text(label, style: theme.textTheme.bodyMedium),
        value: Text(
          text,
          textAlign: TextAlign.end,
          style: theme.textTheme.bodyLarge?.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
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
            // The icon stays outside, so the row keeps exactly one flex child
            // and `LabelValueRow`'s "what the value is refused is what the
            // label is given" arithmetic still holds (see its doc comment).
            // Before this the name was `Expanded` and the amount was the loose
            // child — the priority backwards, so a long category name squeezed
            // the amount off the right edge (QA: 246px + 166px + 36px at
            // 320dp/2x).
            Expanded(
              child: LabelValueRow(
                label: Text(name, style: theme.textTheme.bodyMedium),
                value: Text(
                  formatMinorUnitsForDisplay(amount.amount, amount.currency),
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
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

/// Minimum space between the transaction row's icon-plus-name half and its
/// amount. See the comment on the row's `title` for the arithmetic this feeds.
const double _amountGap = 12;

/// The width [_TransactionRow] keeps back from the amount for the
/// icon-plus-name half, so neither half's box can collapse to 0dp.
///
/// Absolute rather than a fraction of the row, which is the whole reason this
/// row does not use `LabelValueRow` — see the comment on the row's `title`.
/// 48dp = the 24dp icon, the 12dp that follows it, and 12dp of name. It is a
/// floor on the *box*, not a promise the name is comfortable: at 320dp the name
/// still wraps one CJK glyph per line, exactly as it does on `main`.
const double _amountLabelFloor = 48;

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
      // The amount rides in the title row rather than in `trailing`, for the
      // same reason the net-worth account rows do (see the comment on
      // `networth_tab.dart`'s `ListTile`): a `ListTile`'s trailing slot is laid
      // out unconstrained, so at a 2x text scale the amount consumed the whole
      // tile and the tile refused to lay out at all — "Trailing widget consumes
      // the entire tile width", an assertion rather than a RenderFlex overflow,
      // followed by a cascade of unlaid-out ancestors. Inside the row the
      // category name wraps instead.
      //
      // The category icon rides *inside the label* rather than in the tile's
      // `leading` slot, so the amount is measured against the whole tile width
      // instead of what a 40dp leading slot leaves of it.
      //
      // This is `LabelValueRow`'s shape — `Expanded` label, non-flex value that
      // takes its natural width, value capped so the label cannot be squeezed
      // to 0dp — but **not** `LabelValueRow` itself, and the reason is measured,
      // not stylistic. That row caps the value at a fixed 65% of the row, and
      // 65% is not enough here at 320dp:
      //
      //   320dp screen -> 280dp card -> 276dp inside the border -> 236dp of
      //   `ListTile` title. A seven-figure signed amount at `bodyLarge`/w700,
      //   textScale 1.0, is 165.0dp wide. `LabelValueRow` would allow it
      //   (236 - 12) * 0.65 = 145.6dp, so `-1,234,567` painted as `-1,234,5` /
      //   `67` — two lines, broken mid-digit-group, reading as two numbers, and
      //   raising no layout error at all.
      //
      // The cap this row needs at 320dp is 165/(236 - gap) >= 0.72 of the row,
      // and no gutter buys the difference: even flush against the card border
      // (276dp) the 65% cap gives 174.2dp only with a 0dp inset, and with the
      // usual 16dp it gives 153.4dp. So the fraction is the wrong shape of
      // limit — the amount's requirement is an absolute width, and a fraction
      // cannot guarantee an absolute one. `label_value_row.dart` is shared with
      // the net-worth and totals rows whose geometry was settled over several
      // rounds, so the cap is re-expressed here for this row only rather than
      // re-derived there.
      //
      // Hence [_amountLabelFloor]: the amount may take everything except a
      // floor reserved for the icon-plus-name half. At 320dp that leaves the
      // amount 236 - 12 - 48 = 176dp against the 165.0dp it needs (11dp of
      // headroom) and the label 48dp — where `main`, which laid the amount out
      // unconstrained in `trailing`, left the name a 15.0dp box and broke `餐飲`
      // one glyph per line. So this is no worse than `main` on the label side
      // and equal to it on the amount.
      //
      // The row still has exactly one flex child, which is what makes "what the
      // value is refused is what the label is given" hold — see
      // `label_value_row.dart`'s doc comment for why that matters.
      title: LayoutBuilder(
        builder: (context, constraints) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon),
                  const SizedBox(width: 12),
                  Flexible(child: Text(name)),
                ],
              ),
            ),
            const SizedBox(width: _amountGap),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: (constraints.maxWidth - _amountGap - _amountLabelFloor)
                    .clamp(0.0, double.infinity),
              ),
              child: Text(
                formatSignedMinorUnits(
                  transaction.amount,
                  transaction.currency,
                  transaction.type,
                ),
                // Only holds the continuation lines against the right edge once
                // the amount is forced to wrap (textScale 2.0, where 165.0dp
                // becomes 330dp and no cap can fit it on one line). While it
                // fits, the box is the glyphs and this is invisible.
                textAlign: TextAlign.end,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      subtitle: transaction.note == null || transaction.note!.isEmpty
          ? null
          : Text(transaction.note!),
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
