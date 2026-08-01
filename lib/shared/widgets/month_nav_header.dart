import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

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
      overflow: TextOverflow.ellipsis,
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
          // shrink. Between them the label ellipsizes instead of overflowing
          // on a 320dp phone — the `▾` + its padding cost ~48dp that this
          // centred row had no other way to give back.
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
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: label),
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
