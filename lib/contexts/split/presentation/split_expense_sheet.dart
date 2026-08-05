import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../finance/domain/finance_money.dart';
import '../../social/domain/friend.dart';
import '../domain/equal_split.dart';
import '../domain/group_member.dart';
import '../domain/split_expense.dart';
import '../domain/split_group.dart';
import '../domain/split_input.dart';
import 'split_error_text.dart';
import 'split_expense_writer.dart';
import '../../../shared/auth/id_token_provider.dart';

/// The largest amount the backend accepts (a signed 32-bit int, design.md
/// task 6.5) — blocked client-side rather than sent and rejected.
const _maxAmount = 2147483647;

enum _SplitMode { equal, exact }

/// Why Save is disabled — one value per condition, so each one can be given
/// its own sentence on screen (design D3: an impossible form is refused
/// locally *with an explanation*, never silently greyed out).
enum _SaveBlock {
  noFriends,
  amountRequired,
  amountTooLarge,
  descriptionRequired,
  payerRequired,
  participantsRequired,
  noStake,
  tooFewPeople,
  amountBelowParticipants,
  exactMustSum,
}

/// One selectable payer/participant: a user id and the name to show for it.
class _Candidate {
  final String userId;
  final String name;
  const _Candidate(this.userId, this.name);
}

/// The record/edit sheet for a split expense (design.md 6, task 6.1):
/// group (optional, hidden while editing since `group_id` is immutable),
/// payer, amount + currency, description, day, participants, and an
/// equal/exact split mode with a live preview that mirrors the backend's
/// own remainder rule exactly (task 6.4b).
///
/// Takes a [writer] (either `SplitController` or `GroupDetailController`,
/// via the shared [SplitExpenseWriter] surface) and owns the save/delete
/// calls itself, mirroring `AddTransactionSheet`: a failed submission keeps
/// every typed field exactly as it was and only pops on success.
class SplitExpenseSheet extends StatefulWidget {
  final SplitExpenseWriter writer;
  final IdTokenProvider idToken;

  /// The caller's own user id (design D5c) — used for the default
  /// participant, the "you" candidate label, and the share-stake gate.
  final String selfUserId;

  /// Today's `YYYY-MM-DD`, the default day for a new expense.
  final String today;

  /// Groups the caller can pick from when creating a group-less-or-grouped
  /// expense (each with its members embedded, from `ListGroups`). Ignored
  /// when [lockedGroup] is set or [editing] is non-null — the selector is
  /// hidden in both cases.
  final List<SplitGroup> groups;

  /// When set, the expense is pre-locked to this group (its own members
  /// embedded) and the group selector is not shown — used when opening this
  /// sheet from within a group's own screen ("add expense" there).
  final SplitGroup? lockedGroup;

  /// Candidates for a group-less expense: the caller's friends (design
  /// D5b — reused from the social context, not a second friends path).
  final List<Friend> friends;

  /// `null` to record a new expense; the expense being edited otherwise.
  final SplitExpense? editing;

  /// Leaves for the friends page. Required, not optional: it is the only
  /// exit from the one blocked state the user cannot resolve inside this
  /// sheet (no group, no friends — the participant list is just them), and
  /// a caller that forgot to wire it would ship that dead end with every
  /// test still green. The caller is responsible for closing this sheet
  /// first — the sheet does not know how it was presented.
  final VoidCallback onAddFriend;

  const SplitExpenseSheet({
    super.key,
    required this.writer,
    required this.idToken,
    required this.selfUserId,
    required this.today,
    required this.onAddFriend,
    this.groups = const [],
    this.lockedGroup,
    this.friends = const [],
    this.editing,
  });

  @override
  State<SplitExpenseSheet> createState() => _SplitExpenseSheetState();
}

class _SplitExpenseSheetState extends State<SplitExpenseSheet> {
  String? _groupId;
  String? _payerUserId;
  Set<String> _participantIds = {};
  _SplitMode _mode = _SplitMode.equal;
  late String _currency;
  late String _day;
  bool _saving = false;

  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final Map<String, TextEditingController> _exactControllers = {};

  bool get _groupSelectorVisible => widget.lockedGroup == null && widget.editing == null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _groupId = editing.groupId;
      _payerUserId = editing.payerUserId;
      _participantIds = editing.shares.map((s) => s.userId).toSet();
      _mode = editing.splitMode == 'exact' ? _SplitMode.exact : _SplitMode.equal;
      _currency = editing.currency;
      _day = editing.day;
      _amountController.text = formatMinorUnits(editing.amount, editing.currency);
      _descriptionController.text = editing.description;
      for (final share in editing.shares) {
        // `..addListener(_onChanged)`, exactly like the lazy `_exactController`
        // path below: without it, typing into a pre-filled exact field
        // rebuilds nothing — the remaining-to-assign line, the stake warning
        // and the Save button all stay frozen at the values the sheet opened
        // with.
        _exactControllers[share.userId] = TextEditingController(
          text: formatMinorUnits(share.amount, editing.currency),
        )..addListener(_onChanged);
      }
    } else {
      _groupId = widget.lockedGroup?.id;
      _payerUserId = widget.selfUserId;
      _participantIds = {widget.selfUserId};
      _currency = defaultCurrency;
      _day = widget.today;
    }
    _amountController.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _amountController.removeListener(_onChanged);
    _amountController.dispose();
    _descriptionController.dispose();
    for (final c in _exactControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _exactController(String userId) => _exactControllers.putIfAbsent(
    userId,
    () => TextEditingController()..addListener(_onChanged),
  );

  /// The group this expense belongs to (locked, or picked from [widget.groups]
  /// while creating), or `null` for a group-less expense.
  SplitGroup? get _effectiveGroup {
    if (widget.lockedGroup != null) return widget.lockedGroup;
    final groupId = _groupId;
    if (groupId == null) return null;
    for (final g in widget.groups) {
      if (g.id == groupId) return g;
    }
    return null;
  }

  /// Candidate payers/participants: a selected group narrows this to its
  /// own members; no group means the caller's friends plus themselves
  /// (design.md, task 6.2). While editing, the expense's existing payer and
  /// share holders are always included even if they fall outside either
  /// source — a share holder need not be the *viewer's* friend or a
  /// co-member (design D1), and must stay selectable so an existing
  /// selection is never silently dropped.
  List<_Candidate> _candidates(AppLocalizations loc) {
    final byId = <String, _Candidate>{};
    void add(String userId, String? name) {
      byId.putIfAbsent(
        userId,
        () => _Candidate(
          userId,
          userId == widget.selfUserId ? loc.splitYouLabel : (name ?? loc.splitUnknownMember),
        ),
      );
    }

    final group = _effectiveGroup;
    if (group != null) {
      for (final member in group.members ?? const <GroupMember>[]) {
        add(member.userId, member.displayName);
      }
    } else {
      add(widget.selfUserId, null);
      for (final friend in widget.friends) {
        add(friend.userId, friend.displayName);
      }
    }
    final editing = widget.editing;
    if (editing != null) {
      add(editing.payerUserId, editing.payerDisplayName);
      for (final share in editing.shares) {
        add(share.userId, share.displayName);
      }
    }
    return byId.values.toList();
  }

  int? get _amount => parseAmountToMinorUnits(_amountController.text, _currency);

  int? _exactAmountFor(String userId) =>
      parseAmountToMinorUnits(_exactController(userId).text, _currency);

  Map<String, int> get _equalPreview =>
      equalSplitAmounts(_amount ?? 0, _participantIds.toList());

  int get _exactSum {
    var sum = 0;
    for (final id in _participantIds) {
      sum += _exactAmountFor(id) ?? 0;
    }
    return sum;
  }

  /// Design.md: the caller must be the payer, or hold a share above zero,
  /// or submission is refused locally with an explanation before any
  /// request is sent (task 6.3).
  bool get _hasStake {
    if (_payerUserId == widget.selfUserId) return true;
    if (!_participantIds.contains(widget.selfUserId)) return false;
    if (_mode == _SplitMode.equal) {
      return (_equalPreview[widget.selfUserId] ?? 0) > 0;
    }
    return (_exactAmountFor(widget.selfUserId) ?? 0) > 0;
  }

  /// Whether there is nobody at all to split with: no group, and no
  /// friends, so the participant list holds the caller alone. Unlike every
  /// other blocker this is not something the user can fix by typing — the
  /// prerequisite lives on the friends page — which is why it is stated
  /// first, before the fields they would otherwise fill in vain.
  ///
  /// Editing is excluded: an existing expense always brings its own payer
  /// and share holders into the candidate list (see [_candidates]). So is a
  /// caller who has a group to pick from — for them the next step is the
  /// selector right there in this sheet, not the friends page.
  ///
  /// "A group to pick from" means an **unarchived** one: an archived group
  /// takes no new expenses, so counting it as a next step leaves a friendless
  /// user with no route to the friends page and a form that completes only to
  /// be rejected by the server.
  bool get _noOneToSplitWith =>
      widget.editing == null &&
      _effectiveGroup == null &&
      _selectableGroups.isEmpty &&
      widget.friends.isEmpty;

  /// The groups that can take a new expense. An archived group is readable
  /// but refuses new expenses, so offering it here builds a form the server
  /// can only reject.
  List<SplitGroup> get _selectableGroups =>
      widget.groups.where((g) => g.archivedAt == null).toList();

  bool get _amountValid {
    final amount = _amount;
    return amount != null && amount > 0 && amount <= _maxAmount;
  }

  /// The single reason Save is disabled right now, or `null` when it isn't.
  ///
  /// One ordered list rather than a boolean conjunction, so that every
  /// disabling condition has a sentence the sheet can actually render — a
  /// greyed-out Save with nothing on screen explaining it is the dead end at
  /// the end of the main path.
  _SaveBlock? get _saveBlock {
    if (_noOneToSplitWith) return _SaveBlock.noFriends;
    if (!_amountValid) {
      final amount = _amount;
      return (amount != null && amount > _maxAmount)
          ? _SaveBlock.amountTooLarge
          : _SaveBlock.amountRequired;
    }
    if (_descriptionController.text.trim().isEmpty) return _SaveBlock.descriptionRequired;
    final payerUserId = _payerUserId;
    if (payerUserId == null) return _SaveBlock.payerRequired;
    if (_participantIds.isEmpty) return _SaveBlock.participantsRequired;
    if (!_hasStake) return _SaveBlock.noStake;
    // The backend refuses a split whose payer and share holders are one and
    // the same person (`split_too_small`) — the sheet's own default state,
    // so without this the very first form a user sees always 400s.
    if ({..._participantIds, payerUserId}.length < 2) return _SaveBlock.tooFewPeople;
    if (_mode == _SplitMode.equal && _amount! < _participantIds.length) {
      // Mirrors the backend's `amount < shares.length` rule for an equal
      // split, which it rejects outright however the zero shares fall.
      return _SaveBlock.amountBelowParticipants;
    }
    if (_mode == _SplitMode.exact && _exactSum != _amount) return _SaveBlock.exactMustSum;
    return null;
  }

  bool get _canSave => !_saving && _saveBlock == null;

  /// The exact-split running total, in the sense that actually happened.
  String _exactDifferenceText(AppLocalizations loc) {
    final difference = (_amount ?? 0) - _exactSum;
    if (difference > 0) {
      return loc.splitExactRemaining(formatMinorUnitsForDisplay(difference, _currency));
    }
    if (difference < 0) {
      return loc.splitExactOverAssigned(formatMinorUnitsForDisplay(-difference, _currency));
    }
    return loc.splitExactAssignedInFull;
  }

  String _saveBlockText(AppLocalizations loc, _SaveBlock block) => switch (block) {
    _SaveBlock.noFriends => loc.splitNoFriendsYet,
    _SaveBlock.amountRequired => loc.splitAmountRequired,
    _SaveBlock.amountTooLarge => loc.splitAmountTooLarge,
    _SaveBlock.descriptionRequired => loc.splitDescriptionRequired,
    _SaveBlock.payerRequired => loc.splitPayerRequired,
    _SaveBlock.participantsRequired => loc.splitParticipantsRequired,
    _SaveBlock.noStake => loc.splitStakeWarning,
    _SaveBlock.tooFewPeople => loc.splitTooFewPeople,
    _SaveBlock.amountBelowParticipants => loc.splitAmountBelowParticipants(_participantIds.length),
    _SaveBlock.exactMustSum => loc.splitExactMustSumToAmount,
  };

  SplitInput _buildSplit() {
    if (_mode == _SplitMode.equal) {
      return EqualSplitInput(_participantIds.toList());
    }
    return ExactSplitInput([
      for (final id in _participantIds)
        ExactShareInput(userId: id, amount: _exactAmountFor(id) ?? 0),
    ]);
  }

  Future<void> _pickDay() async {
    final initial = DateTime.tryParse(_day) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _day =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _save() async {
    final amount = _amount;
    final payerUserId = _payerUserId;
    if (!_canSave || amount == null || payerUserId == null) return;

    setState(() => _saving = true);
    final seqBefore = widget.writer.mutationErrorSeq;
    final split = _buildSplit();
    final editing = widget.editing;
    if (editing == null) {
      await widget.writer.createExpense(
        await widget.idToken(),
        groupId: _effectiveGroup?.id,
        payerUserId: payerUserId,
        amount: amount,
        currency: _currency,
        description: _descriptionController.text.trim(),
        day: _day,
        split: split,
      );
    } else {
      await widget.writer.updateExpense(
        await widget.idToken(),
        editing.id,
        groupId: _effectiveGroup?.id,
        payerUserId: payerUserId,
        amount: amount,
        currency: _currency,
        description: _descriptionController.text.trim(),
        day: _day,
        split: split,
      );
    }
    if (!mounted) return;
    if (widget.writer.mutationErrorSeq != seqBefore) {
      setState(() => _saving = false);
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(splitErrorText(loc, widget.writer.mutationError!))),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final editing = widget.editing;
    if (editing == null) return;
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        // Large text scales on short viewports can otherwise push the
        // actions below the fold (the friends-page dialogs' finding).
        scrollable: true,
        title: Text(loc.splitDeleteConfirmTitle(editing.description)),
        content: Text(loc.splitDeleteConfirmMessage),
        actions: [
          TextButton(
            key: const Key('split-delete-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            key: const Key('split-delete-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(loc.splitDeleteConfirmButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    final seqBefore = widget.writer.mutationErrorSeq;
    await widget.writer.deleteExpense(await widget.idToken(), editing.id);
    if (!mounted) return;
    if (widget.writer.mutationErrorSeq != seqBefore) {
      setState(() => _saving = false);
      final loc2 = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(splitErrorText(loc2, widget.writer.mutationError!))),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final candidates = _candidates(loc);
    final candidateIds = candidates.map((c) => c.userId).toSet();
    // A group switch can leave a stale payer/participant selection pointing
    // at someone outside the new candidate set — drop it rather than let an
    // invalid id ride into the request.
    if (_payerUserId != null && !candidateIds.contains(_payerUserId)) {
      _payerUserId = null;
    }
    _participantIds = _participantIds.intersection(candidateIds);
    // Read once, after the reconciliation above, so the rendered reason and
    // the button's own enabled state can never disagree.
    final saveBlock = _saveBlock;
    // An amount the user has actually typed gets its reason on the field
    // itself; every other reason (including a *blank* amount) goes on the
    // single line above Save, so exactly one place states it.
    final amountError =
        _amountController.text.trim().isNotEmpty &&
            (saveBlock == _SaveBlock.amountRequired || saveBlock == _SaveBlock.amountTooLarge)
        ? _saveBlockText(loc, saveBlock!)
        : null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.editing == null ? loc.splitExpenseAddTitle : loc.splitExpenseEditTitle,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (_groupSelectorVisible) ...[
                DropdownButtonFormField<String?>(
                  key: const Key('split-group-field'),
                  initialValue: _groupId,
                  // `isExpanded`: without it, the dropdown's internal
                  // selected-value Row sizes to the text's natural width —
                  // at a large text scale on a narrow screen that overflows
                  // the field itself (task 9.1 caught this at 320dp/
                  // textScale 2.0). `isExpanded: true` makes the value fill
                  // and ellipsize instead.
                  isExpanded: true,
                  decoration: InputDecoration(labelText: loc.splitGroupFieldLabel),
                  items: [
                    DropdownMenuItem(value: null, child: Text(loc.splitGroupNoneOption)),
                    for (final g in _selectableGroups) DropdownMenuItem(value: g.id, child: Text(g.name)),
                  ],
                  onChanged: (value) => setState(() {
                    _groupId = value;
                    _payerUserId = widget.selfUserId;
                    _participantIds = {widget.selfUserId};
                  }),
                ),
                const SizedBox(height: 16),
              ],
              DropdownButtonFormField<String>(
                key: const Key('split-payer-field'),
                initialValue: candidateIds.contains(_payerUserId) ? _payerUserId : null,
                isExpanded: true,
                decoration: InputDecoration(labelText: loc.splitPayerLabel),
                items: [
                  for (final c in candidates) DropdownMenuItem(value: c.userId, child: Text(c.name)),
                ],
                onChanged: (value) => setState(() => _payerUserId = value),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NumericAmountFieldWide(
                    fieldKey: const Key('split-amount-field'),
                    controller: _amountController,
                    label: loc.financeAmountLabel,
                    errorText: amountError,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: const Key('split-currency-field'),
                      initialValue: _currency,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: loc.financeCurrencyLabel),
                      items: [
                        for (final currency in supportedCurrencies)
                          DropdownMenuItem(value: currency, child: Text(currency)),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _currency = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('split-description-field'),
                controller: _descriptionController,
                decoration: InputDecoration(labelText: loc.splitDescriptionLabel),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                key: const Key('split-day-field'),
                onPressed: _pickDay,
                child: Text('${loc.splitDayLabel}: $_day'),
              ),
              const SizedBox(height: 16),
              Text(loc.splitParticipantsLabel, style: theme.textTheme.labelLarge),
              for (final c in candidates)
                CheckboxListTile(
                  key: Key('split-participant-${c.userId}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _participantIds.contains(c.userId),
                  title: Text(c.name),
                  onChanged: (checked) => setState(() {
                    if (checked ?? false) {
                      _participantIds.add(c.userId);
                    } else {
                      _participantIds.remove(c.userId);
                    }
                  }),
                ),
              const SizedBox(height: 8),
              Text(loc.splitSplitModeLabel, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<_SplitMode>(
                key: const Key('split-mode-toggle'),
                segments: [
                  ButtonSegment(value: _SplitMode.equal, label: Text(loc.splitModeEqual)),
                  ButtonSegment(value: _SplitMode.exact, label: Text(loc.splitModeExact)),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) => setState(() => _mode = selection.first),
              ),
              const SizedBox(height: 12),
              if (_mode == _SplitMode.equal) ...[
                for (final c in candidates)
                  if (_participantIds.contains(c.userId))
                    Padding(
                      key: Key('split-equal-preview-${c.userId}'),
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        loc.splitEqualShareRow(
                          c.name,
                          formatMinorUnitsForDisplay(_equalPreview[c.userId] ?? 0, _currency),
                        ),
                      ),
                    ),
              ] else ...[
                for (final c in candidates)
                  if (_participantIds.contains(c.userId))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(c.name)),
                          NumericAmountFieldWide(
                            fieldKey: Key('split-exact-field-${c.userId}'),
                            controller: _exactController(c.userId),
                            label: loc.splitExactShareLabel(c.name),
                          ),
                        ],
                      ),
                    ),
                const SizedBox(height: 4),
                Text(
                  key: const Key('split-exact-remaining'),
                  // Three separate strings, not one signed figure: a
                  // difference of -20 rendered through the shortfall string
                  // reads as "still short -20", the exact opposite of what
                  // happened.
                  _exactDifferenceText(loc),
                  style: theme.textTheme.bodySmall,
                ),
              ],
              // One line, driven by the one ordered `_saveBlock`. A separate
              // `if (!_hasStake)` branch used to preempt it, which made the
              // sheet state a reason that was not the blocker at all: with
              // the payer switched to a friend and the amount still blank,
              // the equal preview is all zeros, so `_hasStake` reads false
              // and the sheet accused a genuine participant of holding no
              // stake while suppressing the real reason (the missing
              // amount). `_SaveBlock.noStake` carries the same copy, so the
              // stake case keeps its sentence — and its key — but now only
              // when the stake really is what's blocking Save.
              if (saveBlock != null && amountError == null) ...[
                const SizedBox(height: 12),
                Text(
                  _saveBlockText(loc, saveBlock),
                  key: saveBlock == _SaveBlock.noStake
                      ? const Key('split-stake-warning')
                      : const Key('split-save-blocked'),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
                // The one blocker with nothing to do about it in this sheet
                // gets a way out, rather than an instruction the user cannot
                // carry out (the participant list holds only them).
                if (saveBlock == _SaveBlock.noFriends)
                  TextButton(
                    key: const Key('split-add-friend-action'),
                    onPressed: widget.onAddFriend,
                    child: Text(loc.splitAddFriendAction),
                  ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('split-save-button'),
                  onPressed: !_saving && saveBlock == null ? _save : null,
                  child: Text(loc.financeSaveButton),
                ),
              ),
              if (widget.editing != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    key: const Key('split-delete-button'),
                    onPressed: _saving ? null : _delete,
                    child: Text(loc.financeDeleteButton),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A wider variant of the app's fixed-80dp `NumericAmountField` — split
/// amounts commonly run to 6+ digits (unlike a portion count), so the
/// narrow field truncates. Otherwise identical (empty-zero convention via
/// `hintText: '0'`, centered).
class NumericAmountFieldWide extends StatelessWidget {
  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final String? errorText;

  const NumericAmountFieldWide({
    super.key,
    required this.fieldKey,
    required this.controller,
    required this.label,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: TextField(
        key: fieldKey,
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, hintText: '0', errorText: errorText),
      ),
    );
  }
}
