import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/numeric_amount_field.dart';
import '../domain/finance_category.dart';
import '../domain/finance_money.dart';
import '../domain/finance_transaction.dart';
import '../domain/finance_type.dart';
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

  const AddTransactionSheet({
    super.key,
    required this.controller,
    required this.idToken,
    required this.categories,
    required this.today,
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
      _amountController.text = formatMinorUnits(editing.amount, editing.currency);
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

  List<FinanceCategory> get _categoriesForType =>
      widget.categories.where((c) => c.type == _type).toList();

  int? get _amount => parseAmountToMinorUnits(_amountController.text, _currency);

  bool get _canSave => (_amount ?? 0) > 0 && _categoryId != null && !_saving;

  String? get _note => _noteController.text.trim().isEmpty ? null : _noteController.text.trim();

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
      _date = '${picked.year.toString().padLeft(4, '0')}-'
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
    try {
      if (editing == null) {
        await controller.addTransaction(
          await widget.idToken(),
          type: _type,
          amount: amount,
          currency: _currency,
          categoryId: categoryId,
          date: _date,
          note: _note,
        );
      } else {
        await controller.updateTransaction(
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
    if (controller.status == FinanceStatus.loaded) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = false);
    final loc = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.financeSaveFailed)));
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
    await widget.controller.deleteTransaction(await widget.idToken(), editing.id);
    if (!mounted) return;
    if (widget.controller.status == FinanceStatus.loaded) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.financeSaveFailed)));
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
              Text(
                widget.editing == null ? loc.financeAddTitle : loc.financeEditTitle,
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
                      onSelected: (_) => setState(() => _categoryId = category.id),
                    ),
                ],
              ),
              const SizedBox(height: 16),
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
                key: const Key('finance-note-field'),
                controller: _noteController,
                decoration: InputDecoration(labelText: loc.financeNoteLabel),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('save-transaction-button'),
                  onPressed: _canSave ? _save : null,
                  child: Text(loc.financeSaveButton),
                ),
              ),
              if (widget.editing != null) ...[
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
