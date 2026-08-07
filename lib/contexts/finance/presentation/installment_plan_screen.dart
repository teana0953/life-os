import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/auth/id_token_provider.dart';
import '../domain/finance_money.dart';
import '../domain/finance_repository.dart';
import '../domain/installment_plan.dart';

/// The plan page (installments-ui tasks 5.x): see the whole plan and settle it
/// in one go.
///
/// **Editing the amount or period count is not here yet** — the endpoint
/// exists (`FinanceRepository.updateInstallmentPlan`) and is covered at the
/// repository layer, but nothing on this screen calls it. Said plainly
/// because the earlier version of this comment claimed the edit existed,
/// which is worse than the gap: a reader trusts the doc over the widget.
///
/// Settling **must look at [InstallmentPlan.mode] first**: the system
/// can compute the payoff only for [InstallmentMode.total]; a
/// per-instalment payoff comes from the bank (remaining × per-period would
/// wrongly include future interest), so that mode asks the user.
class InstallmentPlanScreen extends StatefulWidget {
  final InstallmentPlan plan;
  final FinanceRepository repository;
  final IdTokenProvider idToken;

  const InstallmentPlanScreen({
    super.key,
    required this.plan,
    required this.repository,
    required this.idToken,
  });

  @override
  State<InstallmentPlanScreen> createState() => _InstallmentPlanScreenState();
}

class _InstallmentPlanScreenState extends State<InstallmentPlanScreen> {
  bool _settling = false;

  /// Widget-lifetime, not created fresh per dialog open and disposed the
  /// moment it closes: `showDialog`'s future resolves on `pop`, while the
  /// dialog route's exit transition is still animating the `TextField` out —
  /// disposing immediately then throws "used after being disposed" on the
  /// next frame. Cleared before each open instead (see [_openSettleDialog]).
  final _settleAmountController = TextEditingController();

  @override
  void dispose() {
    _settleAmountController.dispose();
    super.dispose();
  }

  /// Prompts for a payoff amount (per-instalment mode) or confirms the
  /// system-computed one (total mode), then calls
  /// [FinanceRepository.settleInstallmentPlan] (tasks 5.2/5.3/5.4).
  Future<void> _openSettleDialog() async {
    final loc = AppLocalizations.of(context)!;
    final isPerInstallment = widget.plan.mode == InstallmentMode.perInstallment;
    _settleAmountController.clear();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.financeInstallmentSettleButton),
        // Scrollable: `AlertDialog.content` is not scrollable on its own, and
        // the per-instalment note plus the amount field overflowed the
        // dialog's available height at 320dp / textScale 2.0 (task 7.1's
        // sweep caught it) — the same shape `AddTransactionSheet`'s delete
        // confirmation avoids by being a short, single-line dialog.
        content: SingleChildScrollView(
          child: isPerInstallment
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loc.financeInstallmentSettlePerNote),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('installment-settle-amount-field'),
                      controller: _settleAmountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: loc.financeInstallmentSettleAmountLabel,
                      ),
                    ),
                  ],
                )
              : Text(loc.financeInstallmentSettleTotalNote),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(loc.financeCancelButton),
          ),
          FilledButton(
            key: const Key('installment-settle-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(loc.financeInstallmentSettleConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final amount = isPerInstallment
        ? parseAmountToMinorUnits(_settleAmountController.text, widget.plan.currency)
        : null;

    // Captured before the awaits below: after `pop` this widget's context is
    // defunct, and the messenger has to outlive it.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _settling = true);
    try {
      await widget.repository.settleInstallmentPlan(
        await widget.idToken(),
        widget.plan.id,
        amount: amount,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _settling = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.financeSaveFailed)));
      return;
    }
    if (!mounted) return;
    setState(() => _settling = false);
    // Pop, don't stay: `widget.plan` is injected once and never refetched, so
    // staying would re-render the identical amount/periods with the settle
    // button still offered — no signal that anything happened, over numbers
    // that are now wrong. The scaffold reloads the month on return, which is
    // where the change is actually visible.
    messenger.showSnackBar(SnackBar(content: Text(loc.financeInstallmentSettled)));
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final plan = widget.plan;
    return Scaffold(
      appBar: AppBar(title: Text(loc.financeInstallmentPlanTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatMinorUnitsForDisplay(plan.amount, plan.currency),
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                plan.mode == InstallmentMode.total
                    ? loc.financeInstallmentModeTotal
                    : loc.financeInstallmentModePerInstallment,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                loc.financeInstallmentPeriodsLabel,
                style: theme.textTheme.labelLarge,
              ),
              Text('${plan.periods}', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('installment-settle-button'),
                  onPressed: _settling ? null : _openSettleDialog,
                  child: Text(loc.financeInstallmentSettleButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
