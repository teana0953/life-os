import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';
import '../domain/finance_category.dart';
import '../domain/finance_transaction.dart';
import '../domain/finance_money.dart';
import '../domain/finance_type.dart';
import '../domain/installment_plan.dart';
import 'finance_category_icons.dart';
import 'installment_badge.dart';
import 'split_mirror_badge.dart';

/// One transaction, as both the 明細 list and the 總覽 recent list draw it.
///
/// Shared rather than duplicated because the geometry below was derived once,
/// against measurements, and 明細 shipped without it: with the amount in
/// `ListTile.trailing` at textScale 2.0 the trailing slot took 130dp of a 320dp
/// screen and left the title column 50dp, which rendered the split badge one
/// letter per line and made a single row 512dp tall — taller than half the
/// viewport. A wrap raises no layout error, so no `expectNoLayoutErrors` sweep
/// could see it.

/// Minimum space between the transaction row's icon-plus-name half and its
/// amount. See the comment on the row's `title` for the arithmetic this feeds.
const double _amountGap = 12;

/// The width [FinanceTransactionRow] keeps back from the amount for the
/// icon-plus-name half, so neither half's box can collapse to 0dp.
///
/// Absolute rather than a fraction of the row, which is the whole reason this
/// row does not use `LabelValueRow` — see the comment on the row's `title`.
/// 48dp = the 24dp icon, the 12dp that follows it, and 12dp of name. It is a
/// floor on the *box*, not a promise the name is comfortable: at 320dp the name
/// still wraps one CJK glyph per line, exactly as it does on `main`.
const double _amountLabelFloor = 48;

class FinanceTransactionRow extends StatelessWidget {
  final FinanceTransaction transaction;
  final FinanceCategory? category;

  /// Key prefix for the split badge, so each list's guard is its own and
  /// "drop the mark from one screen" cannot survive the other's test.
  final String mirrorKeyPrefix;

  /// Key prefix for the instalment badge — the identical reason as
  /// [mirrorKeyPrefix] (tasks 4.2/4.4).
  final String installmentKeyPrefix;

  /// The plan behind [transaction], when it is one instalment period and the
  /// viewer owns that plan (`null` otherwise, including when [transaction]
  /// is not an instalment period at all).
  final InstallmentPlan? plan;

  final VoidCallback? onTap;

  const FinanceTransactionRow({
    super.key,
    required this.transaction,
    required this.category,
    required this.mirrorKeyPrefix,
    required this.installmentKeyPrefix,
    this.plan,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = category == null ? Icons.category : financeCategoryIcon(category!);
    final name = category?.name ?? transaction.categoryId;
    final color = transaction.type == FinanceType.expense
        ? theme.colorScheme.error
        : financeIncomeColor(theme.colorScheme);
    final note = transaction.note;
    final hasNote = note != null && note.isNotEmpty;
    final isMirror = transaction.splitExpenseId != null;
    final isInstallment = transaction.planId != null;
    return ListTile(
      onTap: onTap,
      // The amount rides in the title row rather than in `trailing`, for the
      // same reason the net-worth account rows do (see the comment on
      // `networth_tab.dart`'s `ListTile`): a `ListTile`'s trailing slot is laid
      // out unconstrained, so at a 2x text scale the amount consumed the whole
      // tile and the tile refused to lay out at all — "Trailing widget consumes
      // the entire tile width", an assertion rather than a RenderFlex overflow,
      // followed by a cascade of unlaid-out ancestors. Inside the row the
      // category name wraps instead.
      //
      // The category icon rides *inside the label* rather than in the tile's
      // `leading` slot, so the amount is measured against the whole tile width
      // instead of what a 40dp leading slot leaves of it.
      //
      // This is `LabelValueRow`'s shape — `Expanded` label, non-flex value that
      // takes its natural width, value capped so the label cannot be squeezed
      // to 0dp — but **not** `LabelValueRow` itself, and the reason is measured,
      // not stylistic. That row caps the value at a fixed 65% of the row, and
      // 65% is not enough here at 320dp:
      //
      //   320dp screen -> 280dp card -> 276dp inside the border -> 236dp of
      //   `ListTile` title. A seven-figure signed amount at `bodyLarge`/w700,
      //   textScale 1.0, is 165.0dp wide. `LabelValueRow` would allow it
      //   (236 - 12) * 0.65 = 145.6dp, so `-1,234,567` painted as `-1,234,5` /
      //   `67` — two lines, broken mid-digit-group, reading as two numbers, and
      //   raising no layout error at all.
      //
      // The cap this row needs at 320dp is 165/(236 - gap) >= 0.72 of the row,
      // and no gutter buys the difference: even flush against the card border
      // (276dp) the 65% cap gives 174.2dp only with a 0dp inset, and with the
      // usual 16dp it gives 153.4dp. So the fraction is the wrong shape of
      // limit — the amount's requirement is an absolute width, and a fraction
      // cannot guarantee an absolute one. `label_value_row.dart` is shared with
      // the net-worth and totals rows whose geometry was settled over several
      // rounds, so the cap is re-expressed here for this row only rather than
      // re-derived there.
      //
      // Hence [_amountLabelFloor]: the amount may take everything except a
      // floor reserved for the icon-plus-name half. At 320dp that leaves the
      // amount 236 - 12 - 48 = 176dp against the 165.0dp it needs (11dp of
      // headroom) and the label 48dp — where `main`, which laid the amount out
      // unconstrained in `trailing`, left the name a 15.0dp box and broke `餐飲`
      // one glyph per line. So this is no worse than `main` on the label side
      // and equal to it on the amount.
      //
      // The row still has exactly one flex child, which is what makes "what the
      // value is refused is what the label is given" hold — see
      // `label_value_row.dart`'s doc comment for why that matters.
      title: LayoutBuilder(
        builder: (context, constraints) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon),
                  const SizedBox(width: 12),
                  Flexible(child: Text(name)),
                ],
              ),
            ),
            const SizedBox(width: _amountGap),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: (constraints.maxWidth - _amountGap - _amountLabelFloor)
                    .clamp(0.0, double.infinity),
              ),
              child: Text(
                formatSignedMinorUnits(
                  transaction.amount,
                  transaction.currency,
                  transaction.type,
                ),
                // Only holds the continuation lines against the right edge once
                // the amount is forced to wrap (textScale 2.0, where 165.0dp
                // becomes 330dp and no cap can fit it on one line). While it
                // fits, the box is the glyphs and this is invisible.
                textAlign: TextAlign.end,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      // Both lists that show transactions use this row, each passing its own
      // key prefix: they show the same transactions, so a mark on only one of
      // them teaches the reader that the mark means nothing.
      subtitle: !isMirror && !isInstallment && !hasNote
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isMirror)
                  SplitMirrorBadge(
                    key: Key('$mirrorKeyPrefix-${transaction.id}'),
                  ),
                if (isInstallment)
                  InstallmentBadge(
                    key: Key('$installmentKeyPrefix-${transaction.id}'),
                    periodNo: transaction.installmentNo,
                    plan: plan,
                  ),
                if (hasNote) Text(note),
              ],
            ),
    );
  }
}
