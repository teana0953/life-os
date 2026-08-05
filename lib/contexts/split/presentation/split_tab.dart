import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/async_state_scaffold.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../finance/domain/finance_money.dart';
import '../domain/settlement.dart';
import '../domain/split_expense.dart';
import 'settlement_row.dart';
import 'split_activity_controller.dart';
import 'split_activity_section.dart';
import 'split_controller.dart';
import 'split_expense_row.dart';

/// Which of the tab's two sections is showing.
enum SplitSection {
  /// Balances, groups and the existing 最近活動 list: what currently
  /// **exists**, ordered by the day the user entered.
  overview,

  /// The change log: what **happened**, including deletions and edits,
  /// ordered by when it was recorded. A different question from the
  /// overview's, which is why both are kept.
  changeLog,
}

/// The 分帳 tab: the caller's own per-currency balances split into "owed to
/// you" / "you owe" (design.md — the tab's very first content, never a
/// combined figure across currencies, direction always in words), groups,
/// and recent expenses. Mirrors `NetWorthTab`'s shape: loading/reauth via
/// [AsyncStateScaffold], the load failure and empty guide handled here.
///
/// A second section, 變更紀錄, shows what *happened* instead (see
/// [SplitSection]). The switch between them is a [SegmentedButton] inside
/// this tab, deliberately **not** a fifth destination on `FinanceScaffold`'s
/// bottom bar — that bar is already the app's second navigation level, and a
/// section of one tab does not belong on it.
///
/// **The 記一筆 FAB stays visible on both sections** (`finance_scaffold.dart`
/// keys it off the *tab* index, which this change leaves alone). It is the
/// 分帳 tab's action, not the overview section's: recording an expense is
/// what a reader who just noticed a missing entry in the change log wants to
/// do next, and nothing else in the tab offers it. Hiding it would also make
/// it appear and disappear as the reader flips between two sections that are
/// one tap apart. Its write feeds straight back into the change log — see
/// [SplitActivityController.refreshIfLoaded] for the wiring that makes the
/// log move when the reader records from on top of it.
class SplitTab extends StatefulWidget {
  final SplitController controller;

  /// Drives the 變更紀錄 section. Its first page is fetched when that
  /// section is first opened — never at app start, and never as part of the
  /// overview's load: they are two independent sets of data, which is also
  /// why the section switch sits *above* the overview's loading/error
  /// branches. A failed overview must not take the change log down with it.
  final SplitActivityController activityController;
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

  /// Invoked when the user taps the reauth state's sign-in-again control
  /// (see [AsyncStateScaffold]).
  final VoidCallback onSignInAgain;

  const SplitTab({
    super.key,
    required this.controller,
    required this.activityController,
    required this.onRetry,
    required this.onRecordExpense,
    required this.onOpenGroup,
    required this.onCreateGroup,
    required this.onEditExpense,
    required this.onAddFriend,
    required this.onSettleUp,
    required this.onDeleteSettlement,
    required this.onSignInAgain,
  });

  @override
  State<SplitTab> createState() => _SplitTabState();
}

class _SplitTabState extends State<SplitTab> {
  SplitSection _section = SplitSection.overview;

  /// Whether the change log has ever been selected. The two sections live in
  /// an [IndexedStack], which builds every child, so without this gate the
  /// change log would fetch its first page while the user is still looking
  /// at the overview.
  bool _changeLogOpened = false;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: SegmentedButton<SplitSection>(
              key: const Key('split-section-selector'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: SplitSection.overview,
                  label: Text(loc.splitSectionOverview),
                ),
                ButtonSegment(
                  value: SplitSection.changeLog,
                  label: Text(loc.splitSectionChangeLog),
                ),
              ],
              selected: {_section},
              onSelectionChanged: (selection) => setState(() {
                _section = selection.first;
                if (_section == SplitSection.changeLog) _changeLogOpened = true;
              }),
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _section.index,
            children: [
              _overview(context),
              if (_changeLogOpened)
                SplitActivitySection(
                  controller: widget.activityController,
                  onSignInAgain: widget.onSignInAgain,
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _overview(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return AsyncStateScaffold(
      isLoading: widget.controller.status == SplitStatus.loading,
      isReauth: widget.controller.status == SplitStatus.needsReauth,
      reauthMessage: loc.pleaseSignInAgain,
      onSignInAgain: widget.onSignInAgain,
      builder: (context) {
        if (widget.controller.status == SplitStatus.error) {
          final message = widget.controller.error == SplitError.profileFailed
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
                    onPressed: widget.onRetry,
                    child: Text(loc.retry),
                  ),
                ],
              ),
            ),
          );
        }

        final owedToMe = <_BalanceRow>[];
        final owedByMe = <_BalanceRow>[];
        for (final balance in widget.controller.balances) {
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
          for (final expense in widget.controller.expenses) _ActivityEntry.expense(expense),
          for (final settlement in widget.controller.settlements) _ActivityEntry.settlement(settlement),
        ]..sort((a, b) => b.day.compareTo(a.day));

        final isEmpty =
            widget.controller.balances.isEmpty &&
            widget.controller.groups.isEmpty &&
            widget.controller.expenses.isEmpty &&
            widget.controller.settlements.isEmpty;

        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (isEmpty)
                    _EmptyState(
                      onCta: widget.onRecordExpense,
                      onCreateGroup: widget.onCreateGroup,
                      onAddFriend: widget.onAddFriend,
                      // A first-time user typically has no friends yet, and
                      // then every route out of this empty state leads to a
                      // sheet whose participant list is just them and whose
                      // Save can never be enabled. The prerequisite lives on
                      // another page, so the empty state has to say so.
                      needsFriends: widget.controller.friends.isEmpty,
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
                        onSettleUp: widget.onSettleUp,
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
                        onSettleUp: widget.onSettleUp,
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
                          onPressed: widget.onCreateGroup,
                          child: Text(loc.splitAddGroupButton),
                        ),
                      ],
                    ),
                    if (widget.controller.groups.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(loc.splitNoGroupsYet, key: const Key('split-no-groups')),
                      )
                    else
                      LedgeCard(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: [
                            for (final group in widget.controller.groups)
                              ListTile(
                                key: Key('split-group-row-${group.id}'),
                                title: Text(group.name),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => widget.onOpenGroup(group.id),
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
                                      selfUserId: widget.controller.selfUserId,
                                      keyPrefix: 'split-expense',
                                      onEdit: () => widget.onEditExpense(entry.expense!),
                                    )
                                  : SettlementRow(
                                      settlement: entry.settlement!,
                                      selfUserId: widget.controller.selfUserId,
                                      keyPrefix: 'split-settlement',
                                      onDelete: () => widget.onDeleteSettlement(entry.settlement!),
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
