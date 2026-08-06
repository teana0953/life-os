import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../auth/domain/auth_repository.dart';
import '../../finance/domain/finance_money.dart';
import '../../social/application/friend_use_cases.dart';
import '../../user/application/get_profile.dart';
import '../application/balance_use_cases.dart';
import '../application/expense_use_cases.dart';
import '../application/group_use_cases.dart';
import '../application/settlement_use_cases.dart';
import '../domain/balance.dart';
import '../domain/split_expense.dart';
import '../domain/split_group.dart';
import 'group_detail_controller.dart';
import 'settle_up_sheet.dart';
import 'split_error_text.dart';
import 'split_expense_row.dart';
import 'split_expense_sheet.dart';
import '../../../shared/auth/id_token_provider.dart';

/// A single group's screen (design.md 7, task 7.1): members, per-currency
/// group balances (design D2 — "should collect/should pay", never the
/// two-person "owed to me" wording), and the group's own expenses. Adding a
/// member and recording an expense are hidden once the group is archived;
/// archiving is offered only to the group's creator (task 7.2/7.3).
///
/// Owns its own [GroupDetailController] (`initState`/`dispose`), like every
/// controller in this context — not an app-lifetime singleton.
class GroupDetailScreen extends StatefulWidget {
  final GetGroup getGroup;
  final GetGroupBalances getGroupBalances;
  final ListExpenses listExpenses;
  final AddGroupMember addGroupMember;
  final ArchiveGroup archiveGroup;
  final CreateExpense createExpense;
  final UpdateExpense updateExpense;
  final DeleteExpense deleteExpense;
  final ListFriends listFriends;

  /// The caller's own two-person balances (design D8) — `splitGetBalances`
  /// in `main.dart`, already a field on `App`; this screen filters it to
  /// this group's members for the "your balance with each member" section.
  final GetBalances getBalances;
  final CreateSettlement createSettlement;

  /// Resolves the caller's own user id (design D5c). This screen fetches it
  /// itself rather than taking it from the URL: it is reachable by a
  /// bookmarked/shared/hand-edited link, and every gate here is decided by
  /// that id.
  final GetProfile getProfile;

  final AuthRepository authRepository;
  final String groupId;

  final DateTime Function() clock;

  const GroupDetailScreen({
    super.key,
    required this.getGroup,
    required this.getGroupBalances,
    required this.listExpenses,
    required this.addGroupMember,
    required this.archiveGroup,
    required this.createExpense,
    required this.updateExpense,
    required this.deleteExpense,
    required this.listFriends,
    required this.getBalances,
    required this.createSettlement,
    required this.getProfile,
    required this.authRepository,
    required this.groupId,
    this.clock = DateTime.now,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  late final GroupDetailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = GroupDetailController(
      widget.getGroup,
      widget.getGroupBalances,
      widget.listExpenses,
      widget.addGroupMember,
      widget.archiveGroup,
      widget.createExpense,
      widget.updateExpense,
      widget.deleteExpense,
      widget.listFriends,
      widget.getProfile,
      widget.getBalances,
      widget.createSettlement,
    );
    _controller.addListener(_onChanged);
    _load();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// A fresh id token per request (see [IdTokenProvider]); the shape
  /// `FriendsScreen._token` uses. Deliberately not cached in a field: this
  /// screen can sit open past the token's one-hour life, and every mutation
  /// below would then go out with a dead one.
  Future<String> _idToken() => guardedIdToken(widget.authRepository);

  Future<void> _load() async {
    final token = await _idToken();
    if (!mounted) return;
    await _controller.load(token, widget.groupId);
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  /// The current group, with its members embedded — reconstructed for
  /// [SplitExpenseSheet]'s `lockedGroup`, which expects members on the
  /// group itself (mirroring `ListGroups`' shape) rather than as the
  /// sibling list `GetGroup` actually returns.
  SplitGroup? get _groupWithMembers {
    final group = _controller.group;
    if (group == null) return null;
    return SplitGroup(
      id: group.id,
      name: group.name,
      createdByUserId: group.createdByUserId,
      archivedAt: group.archivedAt,
      members: _controller.members,
    );
  }

  /// Shows a mutation failure the same way every other mutation surface in
  /// this app does (`friends_screen.dart`): a controller mutation that fails
  /// only bumps `mutationErrorSeq`, so without this the dialog just closes
  /// and nothing happens.
  void _surfaceMutationError(int seqBefore) {
    if (!mounted || _controller.mutationErrorSeq == seqBefore) return;
    final loc = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(splitErrorText(loc, _controller.mutationError!))),
    );
  }

  Future<void> _openExpenseSheet({SplitExpense? editing}) async {
    final group = _groupWithMembers;
    final selfUserId = _controller.selfUserId;
    if (group == null || selfUserId == null) return;
    await showAppSheet<void>(
      context,
      builder: (_) => SplitExpenseSheet(
        writer: _controller,
        idToken: _idToken,
        selfUserId: selfUserId,
        today: dayString(widget.clock()),
        lockedGroup: group,
        editing: editing,
        // Never reached from here — the sheet's no-one-to-split-with block
        // only fires without a group, and this one is always locked to one
        // — but the exit is wired rather than stubbed so it stays correct
        // if that ever changes.
        onAddFriend: () {
          Navigator.of(context).pop();
          context.push('/friends');
        },
      ),
    );
  }

  /// Opens the settle-up sheet for one currency of a two-person balance with
  /// one of this group's members (design D8). `_controller` implements
  /// `SettlementWriter` and reloads itself on success (mirrors
  /// `FinanceScaffold._openSettleUpSheet`), so nothing further is needed on
  /// return.
  Future<void> _openSettleUpSheet({
    required String otherUserId,
    required String? otherDisplayName,
    required int balanceAmount,
    required String currency,
  }) async {
    final selfUserId = _controller.selfUserId;
    if (selfUserId == null) return;
    await showAppSheet<void>(
      context,
      builder: (_) => SettleUpSheet(
        writer: _controller,
        idToken: _idToken,
        selfUserId: selfUserId,
        otherUserId: otherUserId,
        otherDisplayName: otherDisplayName,
        balanceAmount: balanceAmount,
        currency: currency,
        today: dayString(widget.clock()),
      ),
    );
  }

  Future<void> _openAddMemberDialog() async {
    final memberIds = _controller.members.map((m) => m.userId).toSet();
    final candidates = _controller.friends.where((f) => !memberIds.contains(f.userId)).toList();
    final loc = AppLocalizations.of(context)!;
    final chosen = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(loc.splitAddMemberTitle),
        content: candidates.isEmpty
            ? Text(loc.splitAddMemberEmpty, key: const Key('split-add-member-empty'))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final friend in candidates)
                    ListTile(
                      key: Key('split-add-member-candidate-${friend.userId}'),
                      title: Text(friend.displayName),
                      onTap: () => Navigator.of(dialogContext).pop(friend.userId),
                    ),
                ],
              ),
        actions: [
          TextButton(
            key: const Key('split-add-member-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(loc.cancel),
          ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    final seqBefore = _controller.mutationErrorSeq;
    await _controller.addMember(await _idToken(), widget.groupId, chosen);
    _surfaceMutationError(seqBefore);
  }

  Future<void> _confirmArchive() async {
    final group = _controller.group;
    if (group == null) return;
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(loc.splitArchiveConfirmTitle(group.name)),
        content: Text(loc.splitArchiveConfirmMessage),
        actions: [
          TextButton(
            key: const Key('split-archive-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            key: const Key('split-archive-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(loc.splitArchiveConfirmButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final seqBefore = _controller.mutationErrorSeq;
    await _controller.archive(await _idToken(), widget.groupId);
    _surfaceMutationError(seqBefore);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final appBar = AppBar(
      title: Text(_controller.group?.name ?? ''),
      leading: IconButton(
        key: const Key('split-group-back-button'),
        icon: const Icon(Icons.arrow_back),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: _back,
      ),
    );

    if (_controller.status == GroupDetailStatus.loading) {
      return Scaffold(
        appBar: appBar,
        body: const Center(child: CircularProgressIndicator(key: Key('split-group-loading'))),
      );
    }

    if (_controller.status == GroupDetailStatus.needsReauth) {
      return Scaffold(
        appBar: appBar,
        body: Center(child: Text(loc.pleaseSignInAgain, textAlign: TextAlign.center)),
      );
    }

    if (_controller.status == GroupDetailStatus.error) {
      return Scaffold(
        appBar: appBar,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _controller.error == GroupDetailError.profileFailed
                    ? loc.splitProfileFailedMessage
                    : loc.splitGroupLoadFailedMessage,
                key: const Key('split-group-load-error'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('split-group-retry'),
                onPressed: _load,
                child: Text(loc.retry),
              ),
            ],
          ),
        ),
      );
    }

    final group = _controller.group!;
    final archived = group.archivedAt != null;
    final selfUserId = _controller.selfUserId;
    final isCreator = group.createdByUserId == selfUserId;

    return Scaffold(
      appBar: AppBar(
        title: Text(group.name),
        leading: appBar.leading,
        actions: [
          if (archived)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(loc.splitGroupArchivedBadge, key: const Key('split-group-archived-badge')),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        loc.splitGroupMembersTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (!archived)
                      // `Flexible`, not left bare: at a large text scale on a
                      // narrow screen "Add member" alone can need more width
                      // than the whole Row has (task 9.1 caught this at
                      // 320dp/textScale 2.0) — letting it shrink and ellipsize
                      // keeps the Row from overflowing instead.
                      Flexible(
                        child: TextButton(
                          key: const Key('split-add-member-button'),
                          onPressed: _openAddMemberDialog,
                          child: Text(
                            loc.splitAddMemberButton,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                  ],
                ),
                LedgeCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      for (final member in _controller.members)
                        ListTile(
                          key: Key('split-member-row-${member.userId}'),
                          title: Text(member.displayName ?? loc.splitUnknownMember),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(loc.splitGroupBalancesTitle, style: Theme.of(context).textTheme.titleLarge),
                Text(
                  loc.splitGroupBalancesNote,
                  key: const Key('split-group-balances-note'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                _GroupBalancesCard(balances: _controller.groupBalances),
                const SizedBox(height: 20),
                Text(
                  loc.splitGroupPersonalBalancesTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  loc.splitGroupPersonalBalancesNote,
                  key: const Key('split-group-personal-balances-note'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                _PersonalBalancesCard(
                  balances: _controller.personalBalances,
                  memberIds: _controller.members.map((m) => m.userId).where((id) => id != selfUserId).toSet(),
                  onSettleUp: _openSettleUpSheet,
                ),
                const SizedBox(height: 20),
                Text(loc.splitGroupExpensesTitle, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (_controller.expenses.isEmpty)
                  // Tier 2: the Expenses section of a group page that still
                  // shows its members and balances above. Gains the muted
                  // colour and the centring.
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: EmptyStateNote(
                      stateKey: const Key('split-group-no-expenses'),
                      text: loc.splitGroupNoExpensesYet,
                    ),
                  )
                else
                  LedgeCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        for (final expense in _controller.expenses)
                          SplitExpenseRow(
                            expense: expense,
                            selfUserId: selfUserId,
                            keyPrefix: 'split-group-expense',
                            onEdit: () => _openExpenseSheet(editing: expense),
                          ),
                      ],
                    ),
                  ),
                if (isCreator && !archived) ...[
                  const SizedBox(height: 20),
                  OutlinedButton(
                    key: const Key('split-archive-button'),
                    onPressed: _confirmArchive,
                    child: Text(loc.splitArchiveButton),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: archived
          ? null
          : FloatingActionButton(
              key: const Key('split-group-fab'),
              tooltip: loc.splitAddExpenseTooltip,
              onPressed: () => _openExpenseSheet(),
              child: const Icon(Icons.add),
            ),
    );
  }
}

/// "Your balance with each member" (design D8) — the caller's own two-person
/// balances ([balances], from `GetBalances`, the same signed convention as
/// the split tab), filtered to [memberIds]. **Not** the same figures as
/// [_GroupBalancesCard] above: those are each member's net against the
/// whole group and never move when a repayment is recorded, while these are
/// settle-able (design D8's "no friendship gate" — every row here gets a
/// settle action regardless of whether the member is a friend, since a
/// shared group is enough, per backend PR #70).
class _PersonalBalancesCard extends StatelessWidget {
  final List<Balance> balances;
  final Set<String> memberIds;
  final void Function({
    required String otherUserId,
    required String? otherDisplayName,
    required int balanceAmount,
    required String currency,
  })
  onSettleUp;

  const _PersonalBalancesCard({
    required this.balances,
    required this.memberIds,
    required this.onSettleUp,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final rows = <(String userId, String name, String currency, int amount)>[];
    for (final balance in balances) {
      if (!memberIds.contains(balance.userId)) continue;
      final name = balance.displayName ?? loc.splitUnknownMember;
      for (final cb in balance.balances) {
        if (cb.amount == 0) continue;
        rows.add((balance.userId, name, cb.currency, cb.amount));
      }
    }
    if (rows.isEmpty) {
      return LedgeCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(loc.splitAllSettledUp, key: const Key('split-group-personal-no-balances')),
        ),
      );
    }
    return LedgeCard(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Padding(
              key: Key('split-group-personal-balance-$i'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        rows[i].$4 > 0
                            ? loc.splitOwedToMeRow(
                                rows[i].$2,
                                formatMinorUnitsForDisplay(rows[i].$4.abs(), rows[i].$3),
                              )
                            : loc.splitOwedByMeRow(
                                rows[i].$2,
                                formatMinorUnitsForDisplay(rows[i].$4.abs(), rows[i].$3),
                              ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: Key('split-group-personal-settle-$i'),
                    tooltip: loc.splitSettleUpTooltip,
                    icon: const Icon(Icons.handshake_outlined),
                    onPressed: () => onSettleUp(
                      otherUserId: rows[i].$1,
                      otherDisplayName: rows[i].$2,
                      balanceAmount: rows[i].$4,
                      currency: rows[i].$3,
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

class _GroupBalancesCard extends StatelessWidget {
  final List<Balance> balances;

  const _GroupBalancesCard({required this.balances});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final rows = <String>[];
    for (final balance in balances) {
      final name = balance.displayName ?? loc.splitUnknownMember;
      for (final cb in balance.balances) {
        if (cb.amount == 0) continue;
        final amountText = formatMinorUnitsForDisplay(cb.amount.abs(), cb.currency);
        rows.add(
          cb.amount > 0
              ? loc.splitGroupBalanceShouldCollect(name, amountText)
              : loc.splitGroupBalanceShouldPay(name, amountText),
        );
      }
    }
    // An empty list is "everyone is square", not "nothing loaded" — the
    // server omits settled pairs entirely, and a bare bordered box under the
    // heading reads as a rendering bug.
    if (rows.isEmpty) {
      return LedgeCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(loc.splitAllSettledUp, key: const Key('split-group-no-balances')),
        ),
      );
    }
    return LedgeCard(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Padding(
              key: Key('split-group-balance-$i'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Align(alignment: Alignment.centerLeft, child: Text(rows[i])),
            ),
        ],
      ),
    );
  }
}

