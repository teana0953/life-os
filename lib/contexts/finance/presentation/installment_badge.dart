import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../domain/installment_plan.dart';

/// Marks a ledger row that is one period of an instalment plan (tasks 4.1).
///
/// Shared by 明細 and the overview's recent-transactions list, mirroring
/// [SplitMirrorBadge] for the identical reason: the two lists show the same
/// transactions, and a mark on only one of them teaches the user the mark
/// means nothing. Each list keys its own instance.
///
/// [plan] is the plan behind the period, when the viewer owns it — `null`
/// falls back to a generic label (the row still knows its own period number,
/// just not the plan's total period count).
class InstallmentBadge extends StatelessWidget {
  final int? periodNo;
  final InstallmentPlan? plan;

  const InstallmentBadge({super.key, required this.periodNo, required this.plan});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    final plan = this.plan;
    final text = plan == null
        ? loc.financeInstallmentBadge
        : loc.financeInstallmentPeriodOfTotal(periodNo ?? 0, plan.periods);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.event_repeat, size: 14, color: color),
        const SizedBox(width: 4),
        // `Flexible`, not a bare `Text`: same reason as `SplitMirrorBadge` —
        // this sits in a `ListTile` subtitle beside a wrapping category name.
        Flexible(
          child: Text(text, style: theme.textTheme.labelSmall?.copyWith(color: color)),
        ),
      ],
    );
  }
}
