import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/async_state_scaffold.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../finance/domain/finance_money.dart';
import '../domain/settlement.dart';
import '../domain/split_expense.dart';
import 'settlement_row.dart';
import 'split_controller.dart';
import 'split_expense_row.dart';

/// The 分帳 tab: the caller's own per-currency balances split into "owed to
/// you" / "you owe" (design.md — the tab's very first content, never a
/// combined figure across currencies, direction always in words), groups,
/// and recent expenses. Mirrors `NetWorthTab`'s shape: loading/reauth via
/// [AsyncStateScaffold], the load failure and empty guide handled here.
class SplitTab extends StatelessWidget {
  final SplitController controller;
  final VoidCallback onRetry;
  final VoidCallback onRecordExpense;
  final void Function(String groupId) onOpenGroup;
  final VoidCallback onCreateGroup;
  final void Function(SplitExpense expense) onEditExpense;

  /// Leaves for the friends page — the prerequisite for splitting with
  /// anyone at all, and not reachable from inside this tab otherwise.
  final VoidCallback onAddFriend;

  /// Opens the settle-up sheet for one currency of a two-person balance
  /// (design D0–D2). [balanceAmount] is the *signed* balance with
  /// [otherUserId] — positive means they owe the caller, negative the
  /// caller owes them — carried through unnegated so the sheet can derive
  /// the from/to direction itself (design D1); a row that had already
  /// negated it away could not tell the sheet which way the money goes.
  final void Function({
    required String otherUserId,
    required String? otherDisplayName,
    required int balanceAmount,
    required String currency,
  })
  onSettleUp;

  final void Function(Settlement settlement) onDeleteSettlement;

  const SplitTab({
    super.key,
    required this.controller,
    required this.onRetry,
    required this.onRecordExpense,
    required this.onOpenGroup,
    required this.onCreateGroup,
    required this.onEditExpense,
    required this.onAddFriend,
    required this.onSettleUp,
    required this.onDeleteSettlement,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return AsyncStateScaffold(
      isLoading: controller.status == SplitStatus.loading,
      isReauth: controller.status == SplitStatus.needsReauth,
      reauthMessage: loc.pleaseSignInAgain,
      builder: (context) {
        if (controller.status == SplitStatus.error) {
          final message = controller.error == SplitError.profileFailed
              ? loc.splitProfileFailedMessage
              : loc.splitLoadFailedMessage;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message, key: const Key('split-load-error'), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('split-retry'),
                    onPressed: onRetry,
                    child: Text(loc.retry),
                  ),
                ],
              ),
            ),
          );
        }

        final owedToMe = <_BalanceRow>[];
        final owedByMe = <_BalanceRow>[];
        for (final balance in controller.balances) {
          final name = balance.displayName ?? loc.splitUnknownMember;
          for (final cb in balance.balances) {
            if (cb.amount > 0) {
              owedToMe.add(_BalanceRow(balance.userId, name, cb.currency, cb.amount));
            } else if (cb.amount < 0) {
              owedByMe.add(_BalanceRow(balance.userId, name, cb.currency, cb.amount));
            }
          }
        }

        // The recent-activity list combines expenses and repayments (design
        // D5 — repayments must appear alongside expenses, distinguishably),
        // most recent day first.
        final activity = <_ActivityEntry>[
          for (final expense in controller.expenses) _ActivityEntry.expense(expense),
          for (final settlement in controller.settlements) _ActivityEntry.settlement(settlement),
        ]..sort((a, b) => b.day.compareTo(a.day));

        final isEmpty =
            controller.balances.isEmpty &&
            controller.groups.isEmpty &&
            controller.expenses.isEmpty &&
            controller.settlements.isEmpty;

        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (isEmpty)
                    _EmptyState(
                      onCta: onRecordExpense,
                      onCreateGroup: onCreateGroup,
                      onAddFriend: onAddFriend,
                      // A first-time user typically has no friends yet, and
                      // then every route out of this empty state leads to a
                      // sheet whose participant list is just them and whose
                      // Save can never be enabled. The prerequisite lives on
                      // another page, so the empty state has to say so.
                      needsFriends: controller.friends.isEmpty,
                    )
                  else ...[
                    // Nothing owed either way is a statement, not an absence:
                    // without it the tab silently opens on "Groups" and the
                    // user cannot tell settled from not-yet-loaded.
                    if (owedToMe.isEmpty && owedByMe.isEmpty) ...[
                      LedgeCard(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(loc.splitAllSettledUp, key: const Key('split-all-settled')),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (owedToMe.isNotEmpty) ...[
                      Text(loc.splitSectionOwedToMe, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      _BalanceCard(
                        rows: owedToMe,
                        keyPrefix: 'split-owed-to-me',
                        rowText: (r) => loc.splitOwedToMeRow(
                          r.name,
                          formatMinorUnitsForDisplay(r.amount.abs(), r.currency),
                        ),
                        onSettleUp: onSettleUp,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (owedByMe.isNotEmpty) ...[
                      Text(loc.splitSectionOwedByMe, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      _BalanceCard(
                        rows: owedByMe,
                        keyPrefix: 'split-owed-by-me',
                        rowText: (r) => loc.splitOwedByMeRow(
                          r.name,
                          formatMinorUnitsForDisplay(r.amount.abs(), r.currency),
                        ),
                        onSettleUp: onSettleUp,
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            loc.splitSectionGroups,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        TextButton(
                          key: const Key('split-add-group-button'),
                          onPressed: onCreateGroup,
                          child: Text(loc.splitAddGroupButton),
                        ),
                      ],
                    ),
                    if (controller.groups.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(loc.splitNoGroupsYet, key: const Key('split-no-groups')),
                      )
                    else
                      LedgeCard(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: [
                            for (final group in controller.groups)
                              ListTile(
                                key: Key('split-group-row-${group.id}'),
                                title: Text(group.name),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => onOpenGroup(group.id),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    Text(
                      loc.splitSectionRecentActivity,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    if (activity.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(loc.splitNoActivityYet, key: const Key('split-no-activity')),
                      )
                    else
                      LedgeCard(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: [
                            for (final entry in activity)
                              entry.expense != null
                                  ? SplitExpenseRow(
                                      expense: entry.expense!,
                                      selfUserId: controller.selfUserId,
                                      keyPrefix: 'split-expense',
                                      onEdit: () => onEditExpense(entry.expense!),
                                    )
                                  : SettlementRow(
                                      settlement: entry.settlement!,
                                      selfUserId: controller.selfUserId,
                                      keyPrefix: 'split-settlement',
                                      onDelete: () => onDeleteSettlement(entry.settlement!),
                                    ),
                          ],
                        ),
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

/// One counterpart's balance in one currency. [amount] is carried *signed*
/// (positive = owed to the caller, negative = the caller owes) rather than
/// pre-negated for display — `split_expense_sheet.dart`'s predecessor
/// negated `owedByMe` before this row ever saw it, which made the row's own
/// value always positive and left it unable to tell `SettleUpSheet` which
/// direction the money goes (design.md task 5).
class _BalanceRow {
  final String userId;
  final String name;
  final String currency;
  final int amount;
  const _BalanceRow(this.userId, this.name, this.currency, this.amount);
}

class _BalanceCard extends StatelessWidget {
  final List<_BalanceRow> rows;
  final String keyPrefix;
  final String Function(_BalanceRow) rowText;
  final void Function({
    required String otherUserId,
    required String? otherDisplayName,
    required int balanceAmount,
    required String currency,
  })
  onSettleUp;

  const _BalanceCard({
    required this.rows,
    required this.keyPrefix,
    required this.rowText,
    required this.onSettleUp,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return LedgeCard(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Padding(
              key: Key('$keyPrefix-$i'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Align(alignment: Alignment.centerLeft, child: Text(rowText(rows[i])))),
                  IconButton(
                    key: Key('$keyPrefix-settle-$i'),
                    tooltip: loc.splitSettleUpTooltip,
                    icon: const Icon(Icons.handshake_outlined),
                    onPressed: () => onSettleUp(
                      otherUserId: rows[i].userId,
                      otherDisplayName: rows[i].name,
                      balanceAmount: rows[i].amount,
                      currency: rows[i].currency,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One entry in the split tab's combined recent-activity list — either an
/// expense or a settlement, never both (design.md task 5.1). A sealed-ish
/// pair of nullable fields rather than a class hierarchy: the list is built
/// and sorted in one place ([SplitTab.build]) and this only needs to carry
/// enough to render the right row and sort by day.
class _ActivityEntry {
  final SplitExpense? expense;
  final Settlement? settlement;

  const _ActivityEntry._(this.expense, this.settlement);

  factory _ActivityEntry.expense(SplitExpense expense) => _ActivityEntry._(expense, null);

  factory _ActivityEntry.settlement(Settlement settlement) => _ActivityEntry._(null, settlement);

  String get day => expense?.day ?? settlement!.day;
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCta;
  final VoidCallback onCreateGroup;
  final VoidCallback onAddFriend;

  /// Whether the caller has no friends yet — in which case both actions
  /// below lead to a form they cannot complete, and the real first step is
  /// on the friends page.
  final bool needsFriends;

  const _EmptyState({
    required this.onCta,
    required this.onCreateGroup,
    required this.onAddFriend,
    required this.needsFriends,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            loc.splitEmptyTitle,
            key: const Key('split-empty-title'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (needsFriends) ...[
            const SizedBox(height: 8),
            Text(
              loc.splitNoFriendsYet,
              key: const Key('split-empty-needs-friends'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('split-empty-add-friend'),
              onPressed: onAddFriend,
              child: Text(loc.splitAddFriendAction),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('split-empty-cta'),
            onPressed: onCta,
            child: Text(loc.splitEmptyCta),
          ),
          const SizedBox(height: 8),
          // The other natural first move for a trip is "create the group" —
          // offered here too, because the Groups section (and its own New
          // group action) is not rendered at all while the tab is empty.
          OutlinedButton(
            key: const Key('split-empty-create-group'),
            onPressed: onCreateGroup,
            child: Text(loc.splitAddGroupButton),
          ),
        ],
      ),
    );
  }
}
