import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/fractional_progress_bar.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../domain/finance_budget.dart';
import '../domain/finance_category.dart';
import '../domain/finance_money.dart';
import 'finance_controller.dart';

/// The overview tab's budget progress card (design.md): one row per budget
/// (the overall budget, if set, then each category budget), each showing the
/// name, `spent / amount`, a textual percent, and a progress bar. Color and
/// the over-budget label are always driven by the backend's rounded integer
/// [FinanceBudget.percent] — never a value recomputed on the frontend from
/// `spent`/`amount`, so the three-tier judgement never disagrees with the
/// backend's own 79/80 rounding boundary. An edit icon always opens the
/// budget sheet; when no budgets are set an additional guide + CTA does too
/// — the feature stays discoverable, never hidden.
class BudgetCard extends StatelessWidget {
  final FinanceController controller;
  final VoidCallback onEdit;

  const BudgetCard({super.key, required this.controller, required this.onEdit});

  FinanceCategory? _categoryFor(String? id) {
    if (id == null) return null;
    for (final category in controller.categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final budgets = controller.budgets;

    return LedgeCard(
      key: const Key('budget-card'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(loc.financeBudgetCardTitle, style: theme.textTheme.titleMedium),
              IconButton(
                key: const Key('budget-edit-button'),
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEdit,
              ),
            ],
          ),
          if (budgets.isEmpty) ...[
            // Tier 2: what is empty is the budget *rows* inside this card,
            // on a tab that is otherwise full — a full guide here would
            // plant a page-sized thing in the middle of the overview. The
            // note gains the muted colour and the centring it lacked.
            //
            // The CTA stays, as the card's own action beside the note rather
            // than part of it: the two tiers describe how emptiness is
            // explained, not whether a card may carry a button. Without it
            // the only way to set a first budget would be the pencil icon
            // in the header.
            EmptyStateNote(
              stateKey: const Key('budget-empty-title'),
              text: loc.financeBudgetEmptyTitle,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('budget-empty-cta'),
              onPressed: onEdit,
              child: Text(loc.financeBudgetEmptyCta),
            ),
          ] else
            for (final budget in budgets) ...[
              const SizedBox(height: 12),
              _BudgetRow(budget: budget, category: _categoryFor(budget.categoryId)),
            ],
        ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  final FinanceBudget budget;
  final FinanceCategory? category;

  const _BudgetRow({required this.budget, required this.category});

  Color _colorFor(ColorScheme scheme) {
    if (budget.percent >= 100) return scheme.error;
    if (budget.percent >= 80) return financeBudgetWarningColor(scheme);
    return scheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final name = category?.name ?? loc.financeBudgetOverallLabel;
    final color = _colorFor(theme.colorScheme);
    final fraction = budget.amount == 0 ? 0.0 : budget.spent / budget.amount;

    return Column(
      key: Key('budget-row-${budget.categoryId ?? 'total'}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(name, style: theme.textTheme.bodyMedium)),
            Text(
              '${formatMinorUnitsForDisplay(budget.spent, defaultCurrency)} / '
              '${formatMinorUnitsForDisplay(budget.amount, defaultCurrency)}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '${budget.percent}%',
              style: theme.textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
            if (budget.percent >= 100) ...[
              const SizedBox(width: 8),
              Text(
                loc.financeBudgetOverLabel,
                key: const Key('budget-over-label'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        FractionalProgressBar(fraction: fraction, fillColor: color),
      ],
    );
  }
}
