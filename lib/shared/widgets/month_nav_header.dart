import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import 'shrink_to_fit_text.dart';

/// The shared `‹ 2026-07 ›` month switcher row, used by the finance ledger
/// 總覽 tab and the 淨值 tab.
///
/// Deliberately a **dumb presentation widget**: it takes an already-formatted
/// [monthLabel] plus [onPrevious]/[onNext] callbacks, so month arithmetic
/// (which lives in the finance context's `finance_month.dart`) stays with the
/// caller and `shared/widgets` never depends on `contexts/finance/domain`.
///
/// [keyPrefix] namespaces the three widget keys
/// (`<keyPrefix>-previous`/`-label`/`-next`) so two instances — e.g. the
/// ledger's `finance-month` and the net worth tab's `networth-month` — carry
/// distinct test keys and can coexist without collision.
class MonthNavHeader extends StatelessWidget {
  final String monthLabel;
  final String keyPrefix;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  /// Optional: makes the month label tappable — call sites use it to open the
  /// month picker so a distant month is one step away. Left out, the label
  /// stays a plain, non-interactive `Text` exactly as before.
  final VoidCallback? onPickMonth;

  const MonthNavHeader({
    super.key,
    required this.monthLabel,
    required this.keyPrefix,
    required this.onPrevious,
    required this.onNext,
    this.onPickMonth,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    // The key stays on the `Text` (the tappable wrapper goes *outside* it):
    // call sites' tests read the label through `tester.widget<Text>(byKey(…))`.
    final label = Text(
      monthLabel,
      key: Key('$keyPrefix-label'),
      style: Theme.of(context).textTheme.titleLarge,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          key: Key('$keyPrefix-previous'),
          tooltip: loc.monthNavPreviousTooltip,
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrevious,
        ),
        if (onPickMonth == null)
          label
        else
          // `button: true` matches the diet and menstrual month titles: a
          // bare `InkWell` is only `tap`, which screen readers don't announce
          // as a button. The `▾` and the tooltip are the visible clue that the
          // label opens anything — without one nobody finds the picker.
          // `Flexible` on both the entry and the label inside it: a `Row`
          // lays a non-flexible child out with an *unbounded* main-axis
          // constraint, so without the outer one the inner one can never
          // shrink. The inner `ShrinkToFitText` then **scales** the label
          // down rather than ellipsizing it — but only down to 12px, so a
          // future layout change can't shrink it into illegibility the way an
          // unbounded `FittedBox` would: inside the health card's 20dp page
          // padding a 320dp phone leaves the label ~140dp while `2026年7月`
          // wants 154dp, and an ellipsis ate exactly the month digits
          // (`202…`). Shrunken-but-complete beats truncated-and-silent; at
          // ≥320dp of row width nothing scales at all. The entry's own
          // horizontal padding is 4 (not 12) to hand those dp back to the
          // label — the `▾` already costs ~20dp this centred row can't spare.
          Flexible(
            child: Tooltip(
              message: loc.monthPickerOpenTooltip,
              child: Semantics(
                button: true,
                child: InkWell(
                  onTap: onPickMonth,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: ShrinkToFitText(
                            text: monthLabel,
                            textKey: Key('$keyPrefix-label'),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        IconButton(
          key: Key('$keyPrefix-next'),
          tooltip: loc.monthNavNextTooltip,
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
        ),
      ],
    );
  }
}
