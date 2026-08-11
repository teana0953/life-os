import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/async_state_scaffold.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/stale_notice.dart';
import '../domain/finance_category.dart';
import '../domain/finance_transaction.dart';
import 'finance_controller.dart';
import 'finance_transaction_row.dart';

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
          controller.status == FinanceStatus.loading &&
          controller.summary == null,
      isReauth: controller.status == FinanceStatus.needsReauth,
      reauthMessage: loc.pleaseSignInAgain,
      onSignInAgain: onSignInAgain,
      builder: (context) {
        if (controller.status == FinanceStatus.error &&
            controller.summary == null) {
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

        // See `FinanceOverviewTab`'s identical notice for why this is here,
        // always built rather than conditionally, and pinned outside the
        // scrollable content rather than appended as its row 0: a background
        // reload (a split write elsewhere) can fail while this month's list
        // is already on screen, and as row 0 of a `ListView` — lazily built,
        // and off the top the moment the reader scrolls — that failure was
        // invisible exactly when nobody happened to be looking at the top.
        final staleNotice = StaleNotice(
          failed: controller.reloadFailed,
          loading:
              controller.status == FinanceStatus.loading &&
              controller.summary != null,
          subject: loc.financeTabTransactions,
          onRetry: () => onSwitchMonth(controller.selectedMonth),
        );

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
          return Column(
            children: [
              staleNotice,
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: EmptyStateGuide(
                      stateKey: const Key('finance-transactions-empty'),
                      icon: Icons.receipt_long_outlined,
                      title: loc.financeEmptyTitle,
                    ),
                  ),
                ),
              ),
            ],
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
              child: Column(
                children: [
                  staleNotice,
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        for (final day in days) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8, top: 8),
                            child: Text(
                              day,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          LedgeCard(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              children: [
                                for (final txn in byDay[day]!)
                                  FinanceTransactionRow(
                                    key: Key('finance-transaction-${txn.id}'),
                                    transaction: txn,
                                    category: _categoryFor(txn.categoryId),
                                    mirrorKeyPrefix:
                                        'finance-transaction-mirror',
                                    installmentKeyPrefix:
                                        'finance-transaction-installment',
                                    plan: txn.planId == null
                                        ? null
                                        : controller.installmentPlans[txn
                                              .planId],
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
