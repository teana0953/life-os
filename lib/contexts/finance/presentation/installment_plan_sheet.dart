import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/auth/id_token_provider.dart';
import '../domain/finance_category.dart';
import '../domain/finance_money.dart';
import '../domain/finance_repository.dart';
import '../domain/finance_type.dart';
import '../domain/installment_plan.dart';
import 'finance_category_icons.dart';

/// The standalone 定期扣款 create entry (installments-ui tasks 3.x): its own
/// sheet rather than a branch of `AddTransactionSheet`, because that sheet
/// already carries type/amount/category/date/note and two modes + periods +
/// the no-open-ended-subscription warning do not survive 320dp × textScale
/// 2.0 on top of them.
class InstallmentPlanSheet extends StatefulWidget {
  final FinanceRepository repository;
  final IdTokenProvider idToken;
  final List<FinanceCategory> categories;

  /// Today's `YYYY-MM-DD`, the default `start_day`.
  final String today;

  const InstallmentPlanSheet({
    super.key,
    required this.repository,
    required this.idToken,
    required this.categories,
    required this.today,
  });

  @override
  State<InstallmentPlanSheet> createState() => _InstallmentPlanSheetState();
}

class _InstallmentPlanSheetState extends State<InstallmentPlanSheet> {
  InstallmentMode _mode = InstallmentMode.total;
  String _currency = defaultCurrency;
  late String _startDay;
  String? _categoryId;
  final _amountController = TextEditingController();
  final _periodsController = TextEditingController();
  final _noteController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _startDay = widget.today;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _periodsController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  List<FinanceCategory> get _expenseCategories =>
      widget.categories.where((c) => c.type == FinanceType.expense).toList();

  /// The typed amount, meaning [_mode] — the whole sum in [InstallmentMode.total],
  /// the fixed per-period charge in [InstallmentMode.perInstallment] (tasks
  /// 3.2). This value is sent to the repository verbatim under [_mode]; the
  /// preview below is the only place either derived figure is computed.
  int? get _amount => parseAmountToMinorUnits(_amountController.text, _currency);

  int? get _periods => int.tryParse(_periodsController.text.trim());

  String? get _note =>
      _noteController.text.trim().isEmpty ? null : _noteController.text.trim();

  bool get _canSave =>
      (_amount ?? 0) > 0 && (_periods ?? 0) > 0 && _categoryId != null && !_saving;

  Future<void> _pickStartDay() async {
    final initial = DateTime.tryParse(_startDay) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _startDay =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _save() async {
    final amount = _amount;
    final periods = _periods;
    final categoryId = _categoryId;
    if (amount == null || amount <= 0 || periods == null || periods <= 0 || categoryId == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repository.createInstallmentPlan(
        await widget.idToken(),
        mode: _mode,
        amount: amount,
        periods: periods,
        currency: _currency,
        categoryId: categoryId,
        startDay: _startDay,
        note: _note,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.financeSaveFailed)));
      return;
    }
    if (!mounted) return;
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  /// The live derived-amount preview (tasks 3.2): a swapped label alone is
  /// not enough for the user to catch a wrong mode — this shows the number
  /// the other mode would have meant, computed from what is actually typed.
  Widget? _preview(AppLocalizations loc, ThemeData theme) {
    final amount = _amount;
    final periods = _periods;
    if (amount == null || amount <= 0 || periods == null || periods <= 0) return null;
    final text = _mode == InstallmentMode.total
        ? loc.financeInstallmentPreviewPerPeriod(
            formatMinorUnitsForDisplay(amount ~/ periods, _currency),
          )
        : loc.financeInstallmentPreviewTotal(
            formatMinorUnitsForDisplay(amount * periods, _currency),
          );
    return Text(
      key: const Key('installment-preview'),
      text,
      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final amountLabel = _mode == InstallmentMode.total
        ? loc.financeInstallmentTotalAmountLabel
        : loc.financeInstallmentPerAmountLabel;
    final preview = _preview(loc, theme);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(loc.financeInstallmentCreateTitle, style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    key: const Key('installment-mode-total'),
                    label: Text(loc.financeInstallmentModeTotal),
                    selected: _mode == InstallmentMode.total,
                    onSelected: (_) => setState(() => _mode = InstallmentMode.total),
                  ),
                  ChoiceChip(
                    key: const Key('installment-mode-per'),
                    label: Text(loc.financeInstallmentModePerInstallment),
                    selected: _mode == InstallmentMode.perInstallment,
                    onSelected: (_) => setState(() => _mode = InstallmentMode.perInstallment),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('installment-amount-field'),
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: amountLabel),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('installment-periods-field'),
                controller: _periodsController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: loc.financeInstallmentPeriodsLabel),
              ),
              if (preview != null) ...[
                const SizedBox(height: 8),
                preview,
              ],
              const SizedBox(height: 8),
              Text(
                loc.financeInstallmentNoEndDateWarning,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('installment-start-day-field'),
                      onPressed: _pickStartDay,
                      child: Text('${loc.financeDateLabel}: $_startDay'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: const Key('installment-currency-field'),
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
              Text(loc.financeCategoryLabel, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in _expenseCategories)
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
              TextField(
                key: const Key('installment-note-field'),
                controller: _noteController,
                decoration: InputDecoration(labelText: loc.financeNoteLabel),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('installment-save-button'),
                  onPressed: _canSave ? _save : null,
                  child: Text(loc.financeInstallmentSaveButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
