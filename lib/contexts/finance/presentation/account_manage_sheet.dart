import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../domain/networth_account.dart';
import 'finance_controller.dart';
import 'networth_controller.dart';
import '../../../shared/auth/id_token_provider.dart';

/// The net worth account management sheet (design.md 4.4): add an account
/// (kind + name), rename, reorder within its group, and archive/restore.
///
/// Archived accounts stay listed *here* (so they can be restored) but leave
/// the tab's entry list — their past snapshots keep counting toward historical
/// net worth, which the backend guarantees.
class AccountManageSheet extends StatefulWidget {
  final NetWorthController controller;
  final IdTokenProvider idToken;

  const AccountManageSheet({
    super.key,
    required this.controller,
    required this.idToken,
  });

  @override
  State<AccountManageSheet> createState() => _AccountManageSheetState();
}

class _AccountManageSheetState extends State<AccountManageSheet> {
  final _newNameController = TextEditingController();
  final Map<String, TextEditingController> _nameControllers = {};
  NetWorthKind _newKind = NetWorthKind.asset;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _newNameController.addListener(_onChanged);
    // Keep the per-account fields in step with the controller *outside* of
    // build: every account list change arrives as a notification, and this
    // listener runs before the rebuild it triggers.
    widget.controller.addListener(_syncNameControllers);
    _syncNameControllers();
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_syncNameControllers);
    _newNameController.removeListener(_onChanged);
    _newNameController.dispose();
    for (final controller in _nameControllers.values) {
      controller.removeListener(_onChanged);
      controller.dispose();
    }
    super.dispose();
  }

  /// Creates the name field for any account that doesn't have one yet, seeded
  /// once and then kept across the reloads a write triggers. Each field
  /// notifies the sheet as it is typed in, so the row can show whether the
  /// edit is saved yet.
  ///
  /// Deliberately *not* called from `build`: creating a controller and
  /// subscribing to it is a side effect, and doing it mid-build is how this
  /// repo has previously grown "notifies listeners during build" bugs.
  void _syncNameControllers() {
    for (final account in widget.controller.accounts) {
      _nameControllers.putIfAbsent(account.id, () {
        final controller = TextEditingController(text: account.name);
        controller.addListener(_onChanged);
        return controller;
      });
    }
  }

  /// [account]'s name field. Always already built by [_syncNameControllers] —
  /// this is a pure read, safe to call from `build`.
  TextEditingController _nameControllerFor(NetWorthAccount account) =>
      _nameControllers[account.id]!;

  /// The typed name differs from the stored one — i.e. there is an edit on
  /// screen that the backend hasn't been told about.
  bool _isDirty(NetWorthAccount account) =>
      _nameControllerFor(account).text.trim() != account.name;

  /// A dirty field emptied to nothing: an error, never a silent no-op.
  bool _isNameMissing(NetWorthAccount account) =>
      _nameControllerFor(account).text.trim().isEmpty;

  /// Sorted by (sortOrder, id) — sortOrder alone is not a stable key because
  /// every user-created account arrives at sortOrder 0 (issue #130), so ties
  /// are the normal state, not an edge case. id is the tiebreaker so the
  /// display order is a pure function of the data, independent of whatever
  /// order the backend happened to return tied rows in.
  List<NetWorthAccount> _group(NetWorthKind kind) =>
      widget.controller.accounts.where((a) => a.kind == kind).toList()..sort(
        (a, b) => a.sortOrder != b.sortOrder
            ? a.sortOrder.compareTo(b.sortOrder)
            : a.id.compareTo(b.id),
      );

  /// Runs a write and surfaces a failure as a snackbar, leaving the sheet
  /// open — the controller has already reloaded either way.
  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (widget.controller.status == FinanceStatus.loaded) return;
    final loc = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.controller.status == FinanceStatus.needsReauth
              ? loc.pleaseSignInAgain
              : loc.financeSaveFailed,
        ),
      ),
    );
  }

  Future<void> _add() {
    final name = _newNameController.text.trim();
    // A fresh account joins the end of its group, never sortOrder 0's tie —
    // otherwise the pile-up of ties this feature exists to fix would just
    // keep growing with every new account.
    final group = _group(_newKind);
    final nextSortOrder = group.isEmpty
        ? 0
        : group.map((a) => a.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    return _run(() async {
      await widget.controller.createAccount(
        await widget.idToken(),
        kind: _newKind,
        name: name,
        sortOrder: nextSortOrder,
      );
      if (widget.controller.status == FinanceStatus.loaded) {
        _newNameController.clear();
      }
    });
  }

  /// Saves the typed name. Called only from the row's explicit save button
  /// (and the keyboard's done action, which is the same action) — an empty
  /// name is surfaced as an `errorText` by the row instead of being written.
  Future<void> _rename(NetWorthAccount account) {
    final name = _nameControllerFor(account).text.trim();
    if (name.isEmpty || name == account.name) return Future.value();
    return _run(
      () async => widget.controller.updateAccount(
        await widget.idToken(),
        account.id,
        name: name,
      ),
    );
  }

  Future<void> _moveUp(NetWorthAccount account) => _reorder(account, -1);

  Future<void> _moveDown(NetWorthAccount account) => _reorder(account, 1);

  /// Moves [account] one slot ([delta] `-1`/`+1`) within its group, then
  /// renumbers the *whole* group to 0..n-1 in its new order.
  ///
  /// Swapping just the two moved sortOrders is not enough: every
  /// user-created account arrives tied at sortOrder 0 (issue #130), and
  /// swapping two equal values is a no-op. Renumbering the whole group is
  /// what actually breaks the tie.
  ///
  /// Writes are sequential, one per account, and stop at the first failure
  /// rather than racing ahead — a failed write must surface as a failure
  /// (via [_run]'s status check), never get silently overtaken by a later
  /// write's success.
  Future<void> _reorder(NetWorthAccount account, int delta) {
    final group = _group(account.kind);
    final from = group.indexWhere((a) => a.id == account.id);
    final to = from + delta;
    if (to < 0 || to >= group.length) return Future.value();
    final reordered = List.of(group)
      ..removeAt(from)
      ..insert(to, account);
    return _run(() async {
      for (var i = 0; i < reordered.length; i++) {
        await widget.controller.updateAccount(
          await widget.idToken(),
          reordered[i].id,
          sortOrder: i,
        );
        if (widget.controller.status != FinanceStatus.loaded) return;
      }
    });
  }

  Future<void> _toggleArchived(NetWorthAccount account) => _run(
    () async => widget.controller.updateAccount(
      await widget.idToken(),
      account.id,
      archived: !account.archived,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.networthManageAccounts,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              // `Wrap`: two chips whose labels grow with the text scale do not
              // fit a 320dp line at 2.0 (213px over). Pre-existing — this
              // sheet had no narrow-screen guard until now.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    key: const Key('account-add-kind-asset'),
                    label: Text(loc.networthKindAsset),
                    selected: _newKind == NetWorthKind.asset,
                    onSelected: _busy
                        ? null
                        : (_) => setState(() => _newKind = NetWorthKind.asset),
                  ),
                  ChoiceChip(
                    key: const Key('account-add-kind-liability'),
                    label: Text(loc.networthKindLiability),
                    selected: _newKind == NetWorthKind.liability,
                    onSelected: _busy
                        ? null
                        : (_) =>
                              setState(() => _newKind = NetWorthKind.liability),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // The add button's label grows with the text scale too, and an
              // `Expanded` field beside it still leaves the button its natural
              // width — 61px over at 320dp / 2.0. Stacked instead.
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    child: TextField(
                      key: const Key('account-add-name'),
                      controller: _newNameController,
                      enabled: !_busy,
                      decoration: InputDecoration(
                        labelText: loc.networthAccountNameLabel,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    key: const Key('account-add-submit'),
                    onPressed: _busy || _newNameController.text.trim().isEmpty
                        ? null
                        : _add,
                    child: Text(loc.networthAddAccount),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _GroupSection(
                title: loc.networthAssetsTitle,
                accounts: _group(NetWorthKind.asset),
                builder: _accountRow,
              ),
              const SizedBox(height: 16),
              _GroupSection(
                title: loc.networthLiabilitiesTitle,
                accounts: _group(NetWorthKind.liability),
                builder: _accountRow,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountRow(
    NetWorthAccount account,
    bool isFirstInGroup,
    bool isLastInGroup,
  ) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      // A column, not a row: the name field plus save/up/down/archive is more
      // than 320dp holds even at textScale 1.0 (13px over), and 213px over at
      // 2.0 — this sheet is mobile-first, so the controls get their own line
      // rather than the name being squeezed toward zero. A single layout at
      // every width, not a LayoutBuilder branch, so there is one thing to test.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: Key('account-name-${account.id}'),
                controller: _nameControllerFor(account),
                enabled: !_busy,
                decoration: InputDecoration(
                  isDense: true,
                  errorText: _isDirty(account) && _isNameMissing(account)
                      ? loc.networthAccountNameRequired
                      : null,
                ),
                onSubmitted: (_) => _rename(account),
              ),
              if (account.archived)
                Text(
                  loc.networthArchivedLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          // `Wrap`, not a `Row`: at textScale 2.0 the archive button's *text*
          // is what blows the line, and a `Row` has no answer to that but to
          // overflow. `Wrap` lets the controls drop to another line at the
          // sizes where they genuinely do not fit, and reads as one line
          // everywhere else.
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Only shown while the typed name differs from the stored one, so a
              // pending edit is visible as pending — the rename is never lost by
              // tapping elsewhere or closing the sheet believing it was saved.
              if (_isDirty(account) && !_isNameMissing(account))
                IconButton(
                  key: Key('account-name-save-${account.id}'),
                  tooltip: loc.networthSaveNameTooltip,
                  icon: const Icon(Icons.check),
                  onPressed: _busy ? null : () => _rename(account),
                ),
              IconButton(
                key: Key('account-move-up-${account.id}'),
                tooltip: loc.networthMoveUpTooltip,
                icon: const Icon(Icons.arrow_upward),
                onPressed: _busy || isFirstInGroup
                    ? null
                    : () => _moveUp(account),
              ),
              IconButton(
                key: Key('account-move-down-${account.id}'),
                tooltip: loc.networthMoveDownTooltip,
                icon: const Icon(Icons.arrow_downward),
                onPressed: _busy || isLastInGroup
                    ? null
                    : () => _moveDown(account),
              ),
              TextButton(
                key: Key('account-archive-${account.id}'),
                onPressed: _busy ? null : () => _toggleArchived(account),
                child: Text(
                  account.archived
                      ? loc.networthRestoreButton
                      : loc.networthArchiveButton,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  final String title;
  final List<NetWorthAccount> accounts;
  final Widget Function(
    NetWorthAccount account,
    bool isFirstInGroup,
    bool isLastInGroup,
  )
  builder;

  const _GroupSection({
    required this.title,
    required this.accounts,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        for (var i = 0; i < accounts.length; i++)
          builder(accounts[i], i == 0, i == accounts.length - 1),
      ],
    );
  }
}
