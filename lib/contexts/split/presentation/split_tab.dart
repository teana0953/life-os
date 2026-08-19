import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/async_state_scaffold.dart';
import '../../../shared/widgets/last_loaded_label.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/stale_notice.dart';
import '../../finance/domain/finance_money.dart';
import '../domain/balance.dart';
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

  /// Pull-to-refresh for the 總覽 section only — the 變更紀錄 section keeps
  /// its own (design D1): they are two independently fetched views, and
  /// pulling one must not silently refetch the other. The returned future is
  /// what the spinner waits on, so it must not resolve before the reload has
  /// actually settled.
  final Future<void> Function() onRefresh;
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
    required this.onRefresh,
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
      // `lastLoadedAt == null` is "has never loaded successfully", the same
      // gate the finance tabs express as `summary == null`. Plain `status ==
      // loading` would swap the whole section out for a spinner on every
      // pull-to-refresh — and the spinner does not contain the
      // [RefreshIndicator], so the gesture would be unmounted mid-pull.
      isLoading:
          widget.controller.status == SplitStatus.loading &&
          widget.controller.lastLoadedAt == null,
      isReauth: widget.controller.status == SplitStatus.needsReauth,
      reauthMessage: loc.pleaseSignInAgain,
      onSignInAgain: widget.onSignInAgain,
      builder: (context) {
        // `lastLoadedAt == null` guard mirrors the `isLoading` gate above and
        // `NetWorthTab`'s error branch: a same-load failure while balances/
        // groups/expenses are already on screen must not swap them out for
        // this full-page exit (that data is still good) — it surfaces as a
        // [StaleNotice] over the still-live content below instead.
        if (widget.controller.status == SplitStatus.error &&
            widget.controller.lastLoadedAt == null) {
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
              owedToMe.add(_BalanceRow(balance.userId, name, cb.currency, cb.amount, schedules: cb.schedules));
            } else if (cb.amount < 0) {
              owedByMe.add(_BalanceRow(balance.userId, name, cb.currency, cb.amount, schedules: cb.schedules));
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

        // A failed refresh over kept data is exactly `NetWorthTab`'s
        // `reloadFailed`/[StaleNotice] case: the content on screen is still
        // good, only older than the reader thinks. Pinned above the
        // [RefreshIndicator], not inside the [ListView], so it stays visible
        // regardless of scroll position (mirrors `SplitActivitySection`'s
        // placement of its own [StaleNotice]).
        final staleNotice = StaleNotice(
          failed: widget.controller.reloadFailed,
          loading:
              widget.controller.status == SplitStatus.loading &&
              widget.controller.lastLoadedAt != null,
          subject: loc.splitSectionOverview,
          onRetry: widget.onRefresh,
        );

        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  staleNotice,
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: widget.onRefresh,
                      child: ListView(
                        // Always scrollable so a near-empty overview still
                        // takes the overscroll the refresh gesture needs.
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        children: [
                          LastLoadedLabel(
                            lastLoadedAt: widget.controller.lastLoadedAt,
                          ),
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 16,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    loc.splitAllSettledUp,
                                    key: const Key('split-all-settled'),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (owedToMe.isNotEmpty) ...[
                              Text(
                                loc.splitSectionOwedToMe,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              _BalanceCard(
                                rows: owedToMe,
                                keyPrefix: 'split-owed-to-me',
                                rowText: (r) => loc.splitOwedToMeRow(
                                  r.name,
                                  formatMinorUnitsForDisplay(
                                    r.amount.abs(),
                                    r.currency,
                                  ),
                                ),
                                onSettleUp: widget.onSettleUp,
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (owedByMe.isNotEmpty) ...[
                              Text(
                                loc.splitSectionOwedByMe,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              _BalanceCard(
                                rows: owedByMe,
                                keyPrefix: 'split-owed-by-me',
                                rowText: (r) => loc.splitOwedByMeRow(
                                  r.name,
                                  formatMinorUnitsForDisplay(
                                    r.amount.abs(),
                                    r.currency,
                                  ),
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
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
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
                              // Tier 2: the Groups *section* of a populated tab is
                              // empty, not the tab. Gains the muted colour and the
                              // centring. (Missed by the change's own inventory.)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: EmptyStateNote(
                                  stateKey: const Key('split-no-groups'),
                                  text: loc.splitNoGroupsYet,
                                ),
                              )
                            else
                              LedgeCard(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Column(
                                  children: [
                                    for (final group
                                        in widget.controller.groups)
                                      ListTile(
                                        key: Key('split-group-row-${group.id}'),
                                        title: Text(group.name),
                                        trailing: const Icon(
                                          Icons.chevron_right,
                                        ),
                                        onTap: () =>
                                            widget.onOpenGroup(group.id),
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
                              // Tier 2: the Recent activity section, same reasoning
                              // as Groups above. (Also missed by the inventory.)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: EmptyStateNote(
                                  stateKey: const Key('split-no-activity'),
                                  text: loc.splitNoActivityYet,
                                ),
                              )
                            else
                              LedgeCard(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Column(
                                  children: [
                                    for (final entry in activity)
                                      entry.expense != null
                                          ? SplitExpenseRow(
                                              expense: entry.expense!,
                                              selfUserId:
                                                  widget.controller.selfUserId,
                                              keyPrefix: 'split-expense',
                                              onEdit: () =>
                                                  widget.onEditExpense(
                                                    entry.expense!,
                                                  ),
                                            )
                                          : SettlementRow(
                                              settlement: entry.settlement!,
                                              selfUserId:
                                                  widget.controller.selfUserId,
                                              keyPrefix: 'split-settlement',
                                              onDelete: () =>
                                                  widget.onDeleteSettlement(
                                                    entry.settlement!,
                                                  ),
                                            ),
                                  ],
                                ),
                              ),
                          ],
                        ],
                      ),
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

  /// Every repayment schedule behind this balance, one entry per split
  /// expense. Kept as a list all the way to the screen: the same person can
  /// be repaying two expenses in the same currency, and one combined line
  /// would report a period count and an amount that belong to different
  /// schedules (the bug backend #84 removed).
  final List<BalanceSchedule> schedules;

  const _BalanceRow(this.userId, this.name, this.currency, this.amount, {this.schedules = const []});
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(rowText(rows[i])),
                        // The amount above is the whole debt and stays that
                        // way: a schedule says when the money moves, not
                        // whether it is owed. These lines say where each
                        // schedule has got to, one per expense — never folded
                        // together.
                        for (var s = 0; s < rows[i].schedules.length; s++)
                          Text(
                            key: Key('$keyPrefix-schedule-$i-$s'),
                            loc.splitBalanceSchedule(
                              rows[i].schedules[s].nextPeriod,
                              rows[i].schedules[s].totalPeriods,
                              formatMinorUnitsForDisplay(rows[i].schedules[s].periodAmount, rows[i].currency),
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
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
    // Tier 1: nothing on the whole tab — no balances, no groups, no
    // expenses, no settlements. Gains the icon and the standard
    // `titleMedium` heading; the "no friends yet" line becomes the guide's
    // muted body, in the same position it already occupied.
    //
    // Three actions render at once here, which is why the guide takes a
    // *list*: a primary/secondary pair cannot express three, and the
    // alternative — a third shape for this one screen — would give the
    // standard an exception on its second day. Reading order is unchanged:
    // "you have no friends yet", then add a friend, record an expense,
    // create a group. A `ListView` child, so no scroll of its own.
    //
    // **One primary, the rest secondary** — the same shape `care_history`
    // uses. Which one is primary follows the body: while `needsFriends`, the
    // body says a friend is needed first and "record an expense" opens a
    // sheet that cannot be saved (only 「你」 to split with), so it must not
    // sit at the same weight as the action that unblocks it. Once there are
    // friends the add-friend action is gone and recording *is* the first
    // move, so it takes the primary weight back.
    //
    // The 12dp break that used to group add-friend with its reason is not
    // restored: the emphasis now carries that grouping, and re-introducing a
    // per-action gap would mean widening the shared widget's API for one
    // call site.
    final recordIsPrimary = !needsFriends;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: EmptyStateGuide(
        stateKey: const Key('split-empty-title'),
        icon: Icons.call_split,
        title: loc.splitEmptyTitle,
        body: needsFriends ? loc.splitNoFriendsYet : null,
        actions: [
          if (needsFriends)
            FilledButton(
              key: const Key('split-empty-add-friend'),
              onPressed: onAddFriend,
              child: Text(loc.splitAddFriendAction),
            ),
          if (recordIsPrimary)
            FilledButton(
              key: const Key('split-empty-cta'),
              onPressed: onCta,
              child: Text(loc.splitEmptyCta),
            )
          else
            OutlinedButton(
              key: const Key('split-empty-cta'),
              onPressed: onCta,
              child: Text(loc.splitEmptyCta),
            ),
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
