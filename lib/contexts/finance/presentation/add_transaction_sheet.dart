import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/widgets/numeric_amount_field.dart';
import '../domain/finance_category.dart';
import '../domain/finance_money.dart';
import '../domain/finance_transaction.dart';
import '../domain/finance_type.dart';
import '../domain/installment_plan.dart';
import 'finance_category_icons.dart';
import 'finance_controller.dart';
import '../../../shared/auth/id_token_provider.dart';

/// The record/edit bottom sheet (design.md 3.4): a numeric amount field
/// (empty-zero convention), an expense/income toggle that swaps the
/// category grid, a category grid, a date field (defaults to [today]), a
/// currency selector (defaults to TWD), and an optional note. Used both to
/// record a new transaction ([editing] is `null`) and to edit an existing
/// one (shows a delete action with confirmation).
///
/// Owns the save/delete calls itself (rather than popping a draft value for
/// the caller to apply) so a failure can keep the sheet open with every
/// field's content intact — the spec's "failure keeps input" requirement —
/// and only pops on success.
class AddTransactionSheet extends StatefulWidget {
  final FinanceController controller;
  final IdTokenProvider idToken;
  final List<FinanceCategory> categories;

  /// Today's `YYYY-MM-DD`, used as the default date for a new transaction.
  final String today;

  /// `null` to record a new transaction; the transaction being edited
  /// otherwise.
  final FinanceTransaction? editing;

  /// Leaves for the split records. Required and non-null, mirroring
  /// `SplitExpenseSheet.onAddFriend` for the same reason: it is the only exit
  /// from the mirrored sheet's locked half, and a caller that forgot to wire
  /// it would ship a sentence telling the user to go somewhere with no way to
  /// get there — with every test still green. The caller closes this sheet
  /// first; the sheet does not know how it was presented.
  final VoidCallback onGoToSplit;

  /// Leaves for the instalment plan this row belongs to (tasks 2.1) — shown
  /// only when the plan is the viewer's own (task 2.1's ownership gate).
  /// Optional: a caller that has not wired plan navigation yet still gets a
  /// correctly-gated `finance-go-to-plan` control, just an inert one.
  /// Required, not optional, for the same reason [onGoToSplit] is: a caller
  /// that forgot to wire it would ship a button that does nothing, with every
  /// test still green.
  final void Function(InstallmentPlan plan) onGoToPlan;

  const AddTransactionSheet({
    super.key,
    required this.controller,
    required this.idToken,
    required this.categories,
    required this.today,
    required this.onGoToSplit,
    required this.onGoToPlan,
    this.editing,
  });

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  late FinanceType _type;
  late String _currency;
  late String _date;
  String? _categoryId;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _type = editing.type;
      _currency = editing.currency;
      _date = editing.date;
      _categoryId = editing.categoryId;
      // Seeded even for a mirrored transaction, whose sheet shows no amount
      // field at all: `_canSave` reads this controller, so leaving it empty
      // would leave Save permanently dead on the one sheet whose whole point
      // is saving a recategorisation.
      _amountController.text = formatMinorUnits(
        editing.amount,
        editing.currency,
      );
      _noteController.text = editing.note ?? '';
    } else {
      _type = FinanceType.expense;
      _currency = defaultCurrency;
      _date = widget.today;
    }
    // Re-evaluate the save gate as the amount is typed (NumericAmountField
    // owns the field and exposes no onChanged).
    _amountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() => setState(() {});

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Whether the transaction being edited is one the server mirrored out of a
  /// split expense. Everything the split owns — amount, date, currency and
  /// **type** — is then a fact rather than a field: the backend refuses a write
  /// that changes any of them, and the type control would additionally clear
  /// `_categoryId` on the way (see the toggle below), costing the user the one
  /// field they opened this sheet to change.
  bool get _isMirror => widget.editing?.splitExpenseId != null;

  /// The plan behind the row being edited, `null` off a plan. **Independent
  /// of [_isMirror]** (tasks 1.1/1.2): `splitExpenseId` and `planId` are two
  /// separate nullable columns the backend never treats as exclusive, and
  /// 分帳分期 is expected to produce rows carrying both — so this reads
  /// straight off [FinanceTransaction.planId] rather than being gated behind
  /// `!_isMirror` the way a copy of the old two-way branch would have it.
  String? get _planId => widget.editing?.planId;

  /// The plan itself, if the viewer owns it. [FinanceController.load]
  /// already attempted to fetch every `planId` this month's transactions
  /// reference and kept only the ones that answered — a plan absent here
  /// answered 404, the API's only ownership signal (tasks 2.1/2.2), so
  /// plan-level actions (the "go to plan" exit) hang on this being non-null,
  /// never on `_planId != null` alone.
  InstallmentPlan? get _plan =>
      _planId == null ? null : widget.controller.installmentPlans[_planId];

  List<FinanceCategory> get _categoriesForType =>
      widget.categories.where((c) => c.type == _type).toList();

  int? get _amount =>
      parseAmountToMinorUnits(_amountController.text, _currency);

  bool get _canSave => (_amount ?? 0) > 0 && _categoryId != null && !_saving;

  String? get _note =>
      _noteController.text.trim().isEmpty ? null : _noteController.text.trim();

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_date) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _save() async {
    final amount = _amount;
    final categoryId = _categoryId;
    if (amount == null || amount <= 0 || categoryId == null) return;

    setState(() => _saving = true);
    // `_saving` is set before the first await, so every path out of the work
    // below — including a throw — has to clear it. Without the catch below, a
    // throw (a failed token renewal reaches the network and throws) left the
    // submit button `onPressed: null` for good, stranding the typed
    // transaction with the sheet's only exit being to dismiss and lose it.
    // `catch` rather than `finally`: on the success path the sheet pops and
    // `_saving` is deliberately left set.
    final controller = widget.controller;
    final editing = widget.editing;
    // This write's own outcome, read instead of `controller.status` (#165):
    // `status` is the screen, and any concurrent call — a background reload
    // fired by a split write elsewhere, a month switch — moves it while this
    // save is in flight. Reading it here reported other calls' failures as
    // this save's, leaving the sheet open over a transaction the server had
    // already accepted and inviting the user to record it twice.
    final FinanceWriteResult result;
    try {
      if (editing == null) {
        result = await controller.addTransaction(
          await widget.idToken(),
          type: _type,
          amount: amount,
          currency: _currency,
          categoryId: categoryId,
          date: _date,
          note: _note,
        );
      } else {
        result = await controller.updateTransaction(
          await widget.idToken(),
          editing.id,
          type: _type,
          amount: amount,
          currency: _currency,
          categoryId: categoryId,
          date: _date,
          note: _note,
        );
      }
    } catch (_) {
      // Not rethrown: an escaping async error is invisible to the user and
      // would leave them staring at an unchanged sheet. Clearing `_saving`
      // and showing the same save-failed message the error status shows keeps
      // the typed transaction on screen and retryable.
      if (!mounted) return;
      setState(() => _saving = false);
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.financeSaveFailed)));
      return;
    }
    if (!mounted) return;
    if (result == FinanceWriteResult.saved) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = false);
    final loc = AppLocalizations.of(context)!;
    // Read before any `pop` below: the messenger is looked up from this
    // sheet's own context, which is defunct once the route is gone.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (editing != null &&
        _isMirror &&
        result == FinanceWriteResult.conflict) {
      // `_isMirror`, not `editing != null`: 409 is the split-moved-underneath
      // answer and the backend returns it from exactly one place, so a
      // non-mirror cannot get here today. If one ever did, the re-seed below
      // would overwrite the amount, date, currency and type the user had just
      // typed on an ordinary edit — the opposite of the "a refusal consumes
      // nothing you typed" property this branch exists to hold.
      //
      // The split changed between this sheet opening and the save, and the
      // server applied *none* of the write. `_mutate` has already reloaded the
      // month, so the current facts are sitting in `controller.transactions` —
      // re-seed only those. `_categoryId`/`_noteController` are deliberately
      // left alone: nothing the user typed was consumed by the refused write,
      // and pulling them back from the reloaded row would silently undo the
      // choice they are being asked to re-confirm.
      // `where`/`isEmpty`, not `firstWhere`: the row genuinely may not be in
      // the reloaded month (see below), and `firstWhere` would answer that
      // with a `StateError` out of a save handler.
      //
      // **`controller.transactions` is shared, and this deliberately still
      // reads it.** `result == FinanceWriteResult.conflict` (as opposed to
      // `conflictReloadFailed`) is `_mutate`'s own guarantee — computed and
      // returned from `_reportRefusedWrite` as this write's `Future` value,
      // never read off a controller field a concurrent call could since have
      // overwritten (#165, round 5) — that this write's own post-refusal
      // reload either landed loaded, or was itself superseded by a *newer*
      // concurrent `load` whose data fields are a valid current answer. So
      // the list read here was fetched by this call or a fresher one, never
      // by a reload that ran and failed. The id gate below is what makes
      // reading a possibly-newer-call's list safe, and it leaves exactly two
      // outcomes, both pinned by tests in `add_transaction_sheet_test.dart`:
      //
      // * a row with this id is present — then whichever call fetched it, it
      //   is the server's current facts *about this very row*, which is all
      //   the re-seed claims; and
      // * no such row — then the sheet closes with "the split moved out of
      //   this month" instead of re-seeding, i.e. it degrades by giving up,
      //   never by showing figures that belong to something else.
      //
      // A reload that ran and did not land (a fetch failure, a 401) reports
      // `conflictReloadFailed` instead and never reaches this branch — see
      // the fall-through to the generic retryable message below, which
      // leaves the sheet (and what the user typed) open without touching
      // `controller.transactions` at all.
      final reloaded = controller.transactions.where((t) => t.id == editing.id);
      final fresh = reloaded.isEmpty ? null : reloaded.first;
      if (fresh == null) {
        // The date is one of the facts the payer can change, so the reload of
        // *this* month can legitimately come back without the row. Same exit
        // as a deleted split rather than an error from looking for it.
        messenger.showSnackBar(
          SnackBar(content: Text(loc.financeSplitMovedOutOfMonth)),
        );
        navigator.pop();
        return;
      }
      setState(() {
        _type = fresh.type;
        _currency = fresh.currency;
        _date = fresh.date;
        _amountController.text = formatMinorUnits(fresh.amount, fresh.currency);
      });
      messenger.showSnackBar(
        SnackBar(content: Text(loc.financeSplitChangedReloaded)),
      );
      return;
    }
    if (result == FinanceWriteResult.notFound) {
      // For a mirror: the payer deleted the split and the cascade took this row
      // with it. For a row the user recorded themselves: it was deleted on
      // another device. Either way `_mutate`'s reload has already dropped it
      // from the list behind them, so leaving the sheet open would leave them
      // editing a record that no longer exists — the dead end this branch
      // exists to prevent. Gating it on `_isMirror` would have relocated that
      // dead end to non-mirrors rather than closing it.
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isMirror
                ? loc.financeSplitDeletedElsewhere
                : loc.financeTransactionGoneElsewhere,
          ),
        ),
      );
      navigator.pop();
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result == FinanceWriteResult.needsReauth ? loc.pleaseSignInAgain : loc.financeSaveFailed,
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final editing = widget.editing;
    if (editing == null) return;
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.financeDeleteConfirmTitle),
        content: Text(loc.financeDeleteConfirmMessage),
        actions: [
          TextButton(
            key: const Key('finance-delete-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(loc.financeCancelButton),
          ),
          FilledButton(
            key: const Key('finance-delete-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(loc.financeDeleteConfirmButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    // The delete's own outcome, not `controller.status` — see `_save`.
    final result = await widget.controller.deleteTransaction(
      await widget.idToken(),
      editing.id,
    );
    if (!mounted) return;
    if (result == FinanceWriteResult.saved) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == FinanceWriteResult.needsReauth ? loc.pleaseSignInAgain : loc.financeSaveFailed,
        ),
      ),
    );
  }

  /// The mirrored sheet's top half (design D2): what the split owns, as a
  /// title plus one line of plain text, and the exit to where those parts are
  /// actually changed.
  ///
  /// Plain text rather than disabled fields, because a form with three of five
  /// inputs greyed out reads as broken and buries the two that work. The
  /// *why* is stated on the first line instead of left for the user to infer
  /// from what won't respond.
  List<Widget> _mirrorHeader(AppLocalizations loc, ThemeData theme) {
    final editing = widget.editing!;
    // The *facts* are read out of the state fields, not off `widget.editing`:
    // after a refused save these hold the reloaded values, and rendering the
    // snapshot the sheet opened with would show stale figures under a message
    // saying they changed. The title below is the exception and deliberately
    // so — it reads `editing.note`, which is the holder's own text and must
    // survive the reload, so after a 409 the amount updates while the title
    // keeps the description the sheet opened with.
    final amount = _amount ?? editing.amount;
    // The note, not "the split's description": the note starts out as the
    // description but belongs to the user from then on, and this same sheet
    // lets them change it. A mirror with no note at all falls back to the
    // list's own marker rather than showing a dangling separator.
    final note = editing.note?.trim() ?? '';
    final title = note.isEmpty
        ? loc.financeSplitMirrorBadge
        : loc.financeSplitMirrorSheetTitle(note);
    final typeLabel = _type == FinanceType.expense
        ? loc.financeTypeExpense
        : loc.financeTypeIncome;
    return [
      // `Wrap`, not a `Row`. A `Row` gives a bare `TextButton` unbounded
      // main-axis constraints, so at 320dp / textScale 2.0 the English label
      // outgrows what `Expanded` left it and the row overflows by ~73px
      // (zh_Hant fits, which is why that is easy to ship). But making the
      // button `Flexible` instead trades that for a worse bug: the two flex
      // children then split the row and "Go to splits" wraps to two lines on
      // **every** English phone at ordinary text size — and a wrap raises no
      // layout error at all, so `expectNoLayoutErrors` cannot see it. `Wrap`
      // lets the button keep its natural width and drop to its own line only
      // when it genuinely cannot fit.
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.start,
        children: [
          // Capped: the note is the user's own free text with no length limit,
          // and at `titleLarge` a 55-character one is a 728dp headline at
          // 320dp / textScale 2.0 — the whole viewport, with the category
          // picker they opened the sheet to use pushed off the bottom. The
          // note is editable in its own field just below, so nothing is lost
          // by ellipsising it here.
          Text(
            title,
            key: const Key('finance-mirror-title'),
            style: theme.textTheme.titleLarge,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          TextButton(
            key: const Key('finance-go-to-split'),
            onPressed: widget.onGoToSplit,
            child: Text(loc.financeSplitMirrorGoToSplit),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        key: const Key('finance-mirror-facts'),
        '${formatMinorUnitsForDisplay(amount, _currency)} $_currency'
        ' · ${mediumDateLabelOrDash(context, _date)}'
        ' · $typeLabel',
        style: theme.textTheme.bodyMedium,
      ),
      const SizedBox(height: 12),
      const Divider(height: 1),
      const SizedBox(height: 12),
    ];
  }

  /// The instalment marker (tasks 1.3/2.3): "period N of M" plus the exit to
  /// the plan, **additive** to whichever header rendered above — it renders
  /// whenever the row carries a period number, regardless of [_isMirror], so
  /// a row that is both a mirror and an instalment period shows both.
  ///
  /// The condition is the period number, not [_planId]: a split repayment
  /// period has no plan, and keying on the plan showed nothing for every one
  /// of them. Where there is no plan there is also no total, so the copy is
  /// "period N" — inventing "of 12" from anywhere else would be a figure the
  /// server never gave.
  ///
  /// [_plan] governs only the "go to plan" exit (task 2.1/2.2's ownership
  /// gate), never whether the period marker itself shows: a share holder
  /// looking at somebody else's period still sees which period it is, just
  /// with no way to manage or settle that plan.
  List<Widget> _installmentInfo(AppLocalizations loc, ThemeData theme) {
    final periodNo = widget.editing!.installmentNo ?? 0;
    final plan = _plan;
    final text = plan == null
        ? loc.financeInstallmentPeriodOnly(periodNo)
        : loc.financeInstallmentPeriodOfTotal(periodNo, plan.periods);
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              text,
              key: const Key('finance-installment-info'),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (plan != null)
            TextButton(
              key: const Key('finance-go-to-plan'),
              onPressed: () => widget.onGoToPlan(plan),
              child: Text(loc.financeInstallmentGoToPlan),
            ),
        ],
      ),
      const SizedBox(height: 12),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      // Lift the sheet above the on-screen keyboard (exercise_screen.dart
      // pattern) so the amount/note fields stay visible while typing.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isMirror)
                ..._mirrorHeader(loc, theme)
              else ...[
                Text(
                  widget.editing == null
                      ? loc.financeAddTitle
                      : loc.financeEditTitle,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                SegmentedButton<FinanceType>(
                  key: const Key('finance-type-toggle'),
                  segments: [
                    ButtonSegment(
                      value: FinanceType.expense,
                      label: Text(loc.financeTypeExpense),
                    ),
                    ButtonSegment(
                      value: FinanceType.income,
                      label: Text(loc.financeTypeIncome),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _type = selection.first;
                      // The category grid swaps to the new type's categories;
                      // a category chosen under the old type may not exist in
                      // the new list, so it must not stay silently selected.
                      _categoryId = null;
                    });
                  },
                ),
                const SizedBox(height: 16),
                NumericAmountField(
                  fieldKey: const Key('amount-field'),
                  controller: _amountController,
                  label: loc.financeAmountLabel,
                ),
                const SizedBox(height: 16),
              ],
              if (widget.editing?.installmentNo != null) ..._installmentInfo(loc, theme),
              Text(loc.financeCategoryLabel, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in _categoriesForType)
                    ChoiceChip(
                      key: Key('finance-category-${category.id}'),
                      avatar: Icon(financeCategoryIcon(category), size: 18),
                      label: Text(category.name),
                      selected: _categoryId == category.id,
                      onSelected: (_) =>
                          setState(() => _categoryId = category.id),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (!_isMirror) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('finance-date-field'),
                        onPressed: _pickDate,
                        child: Text('${loc.financeDateLabel}: $_date'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: const Key('finance-currency-field'),
                        initialValue: _currency,
                        decoration: InputDecoration(
                          labelText: loc.financeCurrencyLabel,
                        ),
                        items: [
                          for (final currency in supportedCurrencies)
                            DropdownMenuItem(
                              value: currency,
                              child: Text(currency),
                            ),
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
              ],
              TextField(
                key: const Key('finance-note-field'),
                controller: _noteController,
                decoration: InputDecoration(labelText: loc.financeNoteLabel),
              ),
              if (_isMirror) ...[
                const SizedBox(height: 12),
                Text(
                  key: const Key('finance-mirror-locked-note'),
                  loc.financeSplitMirrorLockedNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                // The same exit again, beside the sentence that says you need
                // it. The one in the header is ~240dp away at textScale 1.0
                // and scrolled off entirely at 2.0, so whoever reads the
                // explanation would have to scroll back up to act on it.
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    key: const Key('finance-go-to-split-footer'),
                    onPressed: widget.onGoToSplit,
                    child: Text(loc.financeSplitMirrorGoToSplit),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('save-transaction-button'),
                  onPressed: _canSave ? _save : null,
                  child: Text(loc.financeSaveButton),
                ),
              ),
              // Absent for a mirror, not disabled: a greyed-out delete still
              // invites the press, and the press cannot be honoured — the
              // expense is deleted on the split, which the locked-note above
              // says and the header's exit reaches.
              if (widget.editing != null && !_isMirror) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    key: const Key('finance-delete-button'),
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
