import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/widgets/label_value_row.dart';
import '../../finance/domain/finance_money.dart';
import '../domain/settlement.dart';

/// One repayment row, rendered alongside [SplitExpenseRow] in the split
/// tab's combined activity list (design.md task 5.1/5.5 — spec's "A
/// repayment reads as a repayment, not as another expense" requirement).
///
/// Distinguishable from an expense row by more than icon/colour: the label
/// itself spells out "Repayment" (`splitSettlementRow`), never leaving it to
/// be inferred from a glyph alone.
///
/// Delete is offered only to the settlement's creator or its payer (design
/// D4) — anyone else would get a 404 from the server, so the icon is simply
/// absent for them rather than present and guaranteed to fail.
class SettlementRow extends StatelessWidget {
  final Settlement settlement;
  final String? selfUserId;
  final VoidCallback onDelete;
  final String keyPrefix;

  const SettlementRow({
    super.key,
    required this.settlement,
    required this.selfUserId,
    required this.onDelete,
    required this.keyPrefix,
  });

  bool get _canDelete =>
      selfUserId != null &&
      (settlement.createdByUserId == selfUserId || settlement.fromUserId == selfUserId);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final fromName = settlement.fromDisplayName ?? loc.splitUnknownMember;
    final toName = settlement.toDisplayName ?? loc.splitUnknownMember;
    return ListTile(
      key: Key('$keyPrefix-row-${settlement.id}'),
      leading: const Icon(Icons.sync_alt),
      title: LabelValueRow(
        gap: 12,
        label: Text(loc.splitSettlementRow(fromName, toName)),
        value: Text(
          formatMinorUnitsForDisplay(settlement.amount, settlement.currency),
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      subtitle: Text(mediumDateLabelOrDash(context, settlement.day)),
      trailing: _canDelete
          ? IconButton(
              key: Key('$keyPrefix-delete-${settlement.id}'),
              tooltip: loc.splitDeleteSettlementTooltip,
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            )
          : null,
    );
  }
}
