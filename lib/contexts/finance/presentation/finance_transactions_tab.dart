import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/async_state_scaffold.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../domain/finance_category.dart';
import '../domain/finance_money.dart';
import '../domain/finance_transaction.dart';
import '../domain/finance_type.dart';
import 'finance_category_icons.dart';
import 'finance_controller.dart';

/// 明細: the selected month's transactions grouped by day (newest day
/// first). Tapping a row opens the record sheet pre-filled for editing.
class FinanceTransactionsTab extends StatelessWidget {
  final FinanceController controller;
  final ValueChanged<FinanceTransaction> onEdit;
  final Future<void> Function(String month) onSwitchMonth;

  /// Invoked when the user taps the reauth state's sign-in-again control
  /// (see [AsyncStateScaffold]).
  final VoidCallback onSignInAgain;

  const FinanceTransactionsTab({
    super.key,
    required this.controller,
    required this.onEdit,
    required this.onSwitchMonth,
    required this.onSignInAgain,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return AsyncStateScaffold(
      isLoading:
          controller.status == FinanceStatus.loading && controller.summary == null,
      isReauth: controller.status == FinanceStatus.needsReauth,
      reauthMessage: loc.pleaseSignInAgain,
      onSignInAgain: onSignInAgain,
      builder: (context) {
        if (controller.status == FinanceStatus.error && controller.summary == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(loc.financeLoadFailed, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('finance-transactions-retry'),
                  onPressed: () => onSwitchMonth(controller.selectedMonth),
                  child: Text(loc.retry),
                ),
              ],
            ),
          );
        }

        if (controller.transactions.isEmpty) {
          // Tier 1 by region: this fills the whole tab body, so it is a
          // screen-level emptiness and not a gap inside something else —
          // which is why it stops being the app's one bare, unmuted line and
          // becomes the standard guide. It offers no action because this tab
          // is handed no way to add a transaction; the guide's actions are
          // optional precisely for this, and plumbing a callback through
          // would be a different change. The overview tab, which does have
          // one, shows the same title with its CTA.
          //
          // No scroll wrapper, unlike the care-history guide: `Center`
          // bounds the height, so an overflow here *does* throw — and with
          // one short title and no actions this guide fits 320dp at text
          // scale 2.0 in both locales with room to spare. Wrapping it would
          // only disarm that guard (a scroll view can never overflow), which
          // is exactly the "guard that cannot fail" this repo keeps hitting.
          // If an action is ever added here, the narrow-screen test in this
          // tab's suite is what will say so.
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: EmptyStateGuide(
                stateKey: const Key('finance-transactions-empty'),
                icon: Icons.receipt_long_outlined,
                title: loc.financeEmptyTitle,
              ),
            ),
          );
        }

        final byDay = <String, List<FinanceTransaction>>{};
        for (final txn in controller.transactions) {
          (byDay[txn.date] ??= []).add(txn);
        }
        final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  for (final day in days) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 8),
                      child: Text(day, style: Theme.of(context).textTheme.titleMedium),
                    ),
                    LedgeCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          for (final txn in byDay[day]!)
                            _TransactionListRow(
                              transaction: txn,
                              category: _categoryFor(txn.categoryId),
                              onTap: () => onEdit(txn),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  FinanceCategory? _categoryFor(String id) {
    for (final category in controller.categories) {
      if (category.id == id) return category;
    }
    return null;
  }
}

class _TransactionListRow extends StatelessWidget {
  final FinanceTransaction transaction;
  final FinanceCategory? category;
  final VoidCallback onTap;

  const _TransactionListRow({
    required this.transaction,
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = category == null ? Icons.category : financeCategoryIcon(category!);
    final name = category?.name ?? transaction.categoryId;
    final color = transaction.type == FinanceType.expense
        ? theme.colorScheme.error
        : financeIncomeColor(theme.colorScheme);
    return ListTile(
      key: Key('finance-transaction-${transaction.id}'),
      leading: Icon(icon),
      title: Text(name),
      subtitle: transaction.note == null || transaction.note!.isEmpty
          ? null
          : Text(transaction.note!),
      trailing: Text(
        formatSignedMinorUnits(transaction.amount, transaction.currency, transaction.type),
        style: theme.textTheme.bodyLarge?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
      onTap: onTap,
    );
  }
}
