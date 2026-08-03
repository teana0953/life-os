import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/widgets/label_value_row.dart';
import '../../finance/domain/finance_money.dart';
import '../domain/split_expense.dart';

/// One expense row, shared by the split tab's recent-expenses list and a
/// group's own expense list — one implementation so the two can't drift.
///
/// The row answers both halves of the feature's question without opening
/// anything: **who paid** (`payerDisplayName`, which the API carries on the
/// expense itself precisely because a payer who merely fronted the money
/// holds no share to carry their name — backend PR #68) and **what the
/// viewer owes** (their own share, when they hold one). The edit action is
/// offered only to the expense's creator or payer (design D4), so those two
/// facts have to be readable from the row itself: a plain participant gets
/// no sheet to read them in.
class SplitExpenseRow extends StatelessWidget {
  final SplitExpense expense;
  final String? selfUserId;
  final VoidCallback onEdit;

  /// `split-expense` on the split tab, `split-group-expense` on a group's
  /// screen — the two lists keep their own distinct widget keys.
  final String keyPrefix;

  const SplitExpenseRow({
    super.key,
    required this.expense,
    required this.selfUserId,
    required this.onEdit,
    required this.keyPrefix,
  });

  bool get _canEdit =>
      selfUserId != null &&
      (expense.createdByUserId == selfUserId || expense.payerUserId == selfUserId);

  int? get _ownShare {
    for (final share in expense.shares) {
      if (share.userId == selfUserId) return share.amount;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final ownShare = _ownShare;
    return ListTile(
      key: Key('$keyPrefix-row-${expense.id}'),
      isThreeLine: ownShare != null,
      // The amount rides in the title row rather than in `trailing`: a
      // `ListTile`'s trailing slot is laid out unconstrained, so at a 2x text
      // scale a bold amount of NT$10,000 or more consumed the whole tile and
      // the tile refused to lay out at all — an assertion, not a RenderFlex
      // overflow, and the row simply vanished. Exactly the failure
      // `networth_tab.dart`'s account rows hit, and the same fix: inside
      // `LabelValueRow` the description wraps instead, and its 65% cap on the
      // value leaves both halves a floor. Only the edit button — a fixed
      // 48dp — is left in `trailing`, which that slot can carry.
      title: LabelValueRow(
        gap: 12,
        label: Text(expense.description),
        value: Text(
          formatMinorUnitsForDisplay(expense.amount, expense.currency),
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            key: Key('$keyPrefix-payer-${expense.id}'),
            loc.splitExpensePaidBy(
              expense.payerDisplayName ?? loc.splitUnknownMember,
              mediumDateLabelOrDash(context, expense.day),
            ),
          ),
          if (ownShare != null)
            Text(
              key: Key('$keyPrefix-your-share-${expense.id}'),
              loc.splitYourShare(formatMinorUnitsForDisplay(ownShare, expense.currency)),
            ),
        ],
      ),
      trailing: _canEdit
          ? IconButton(
              key: Key('$keyPrefix-edit-${expense.id}'),
              tooltip: loc.splitEditExpenseTooltip,
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            )
          : null,
    );
  }
}
