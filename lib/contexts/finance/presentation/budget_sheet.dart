import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/numeric_amount_field.dart';
import '../domain/finance_money.dart';
import '../domain/finance_type.dart';
import 'finance_controller.dart';

/// One editable row in [BudgetSheet]: the overall budget ([categoryId]
/// `null`) or an expense category's budget. [archived] rows come from a
/// category that's since been archived but still has a budget — design.md:
/// listed, marked, clearable, but not editable to a new amount.
class _BudgetRowSpec {
  final String? categoryId;
  final String label;
  final bool archived;

  const _BudgetRowSpec({required this.categoryId, required this.label, this.archived = false});
}

/// The budget-setting bottom sheet (design.md 3.3): one TWD amount field for
/// the overall budget and one for every non-archived expense category
/// (empty-zero convention — empty means "not set"), plus any archived
/// category that still has a budget (shown, marked, clearable only). Saving
/// sends only the diff via [FinanceController.saveBudgets]; on failure the
/// controller has already reloaded, so this sheet just stays open with every
/// field's typed content untouched and surfaces the error — a retry sends
/// only what's still pending.
class BudgetSheet extends StatefulWidget {
  final FinanceController controller;
  final String idToken;

  const BudgetSheet({super.key, required this.controller, required this.idToken});

  @override
  State<BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<BudgetSheet> {
  late final List<_BudgetRowSpec> _rows;
  final Map<String?, TextEditingController> _amountControllers = {};
  final Set<String?> _clearedArchived = {};
  bool _saving = false;
  bool _initialized = false;

  // The overall row's label comes from AppLocalizations.of(context), which
  // can't be read in initState — so the one-time row/controller seeding runs
  // here (the framework-recommended place for inherited-widget-dependent init)
  // guarded to run only on first mount.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _rows = _buildRows();
    for (final row in _rows) {
      final existing = _existingAmount(row.categoryId);
      _amountControllers[row.categoryId] = TextEditingController(
        text: existing == null || existing == 0 ? '' : formatMinorUnits(existing, defaultCurrency),
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _amountControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<_BudgetRowSpec> _buildRows() {
    final controller = widget.controller;
    final rows = <_BudgetRowSpec>[
      _BudgetRowSpec(categoryId: null, label: _overallLabel()),
    ];
    final activeExpenseCategories = controller.categories.where(
      (c) => c.type == FinanceType.expense && !c.archived,
    );
    for (final category in activeExpenseCategories) {
      rows.add(_BudgetRowSpec(categoryId: category.id, label: category.name));
    }
    final activeIds = activeExpenseCategories.map((c) => c.id).toSet();
    for (final budget in controller.budgets) {
      final categoryId = budget.categoryId;
      if (categoryId == null || activeIds.contains(categoryId)) continue;
      rows.add(
        _BudgetRowSpec(
          categoryId: categoryId,
          label: _categoryName(categoryId) ?? categoryId,
          archived: true,
        ),
      );
    }
    return rows;
  }

  String _overallLabel() => AppLocalizations.of(context)!.financeBudgetOverallLabel;

  String? _categoryName(String id) {
    for (final category in widget.controller.categories) {
      if (category.id == id) return category.name;
    }
    return null;
  }

  int? _existingAmount(String? categoryId) {
    for (final budget in widget.controller.budgets) {
      if (budget.categoryId == categoryId) return budget.amount;
    }
    return null;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final desired = <String?, int?>{};
    for (final row in _rows) {
      if (row.archived) {
        desired[row.categoryId] = _clearedArchived.contains(row.categoryId)
            ? null
            : _existingAmount(row.categoryId);
        continue;
      }
      desired[row.categoryId] = parseAmountToMinorUnits(
        _amountControllers[row.categoryId]!.text,
        defaultCurrency,
      );
    }

    await widget.controller.saveBudgets(widget.idToken, desired);
    if (!mounted) return;
    if (widget.controller.status == FinanceStatus.loaded) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = false);
    final loc = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.financeSaveFailed)));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      // Lift the sheet above the on-screen keyboard, mirroring
      // AddTransactionSheet.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(loc.financeBudgetSheetTitle, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(loc.financeBudgetSheetHint, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              for (final row in _rows) ...[
                _BudgetFieldRow(
                  row: row,
                  amountController: _amountControllers[row.categoryId]!,
                  saving: _saving,
                  cleared: _clearedArchived.contains(row.categoryId),
                  onToggleCleared: row.archived
                      ? () => setState(() {
                          final controller = _amountControllers[row.categoryId]!;
                          if (_clearedArchived.remove(row.categoryId)) {
                            controller.text = formatMinorUnits(
                              _existingAmount(row.categoryId) ?? 0,
                              defaultCurrency,
                            );
                          } else {
                            _clearedArchived.add(row.categoryId);
                            controller.text = '';
                          }
                        })
                      : null,
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('budget-sheet-save'),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(loc.financeSaveButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetFieldRow extends StatelessWidget {
  final _BudgetRowSpec row;
  final TextEditingController amountController;
  final bool saving;
  final bool cleared;
  final VoidCallback? onToggleCleared;

  const _BudgetFieldRow({
    required this.row,
    required this.amountController,
    required this.saving,
    required this.cleared,
    required this.onToggleCleared,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row.label, style: theme.textTheme.bodyMedium),
              if (row.archived)
                Text(
                  cleared ? loc.financeBudgetClearedLabel : loc.financeBudgetArchivedLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        NumericAmountField(
          fieldKey: Key('budget-field-${row.categoryId ?? 'total'}'),
          controller: amountController,
          label: loc.financeAmountLabel,
          allowDecimal: false,
          enabled: !saving && !row.archived,
        ),
        if (row.archived) ...[
          const SizedBox(width: 4),
          TextButton(
            key: Key('budget-archived-clear-${row.categoryId}'),
            onPressed: saving ? null : onToggleCleared,
            child: Text(loc.financeBudgetClearButton),
          ),
        ],
      ],
    );
  }
}
