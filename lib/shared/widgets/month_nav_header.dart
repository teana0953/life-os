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

  const MonthNavHeader({
    super.key,
    required this.monthLabel,
    required this.keyPrefix,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          key: Key('$keyPrefix-previous'),
          tooltip: loc.monthNavPreviousTooltip,
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrevious,
        ),
        Text(
          monthLabel,
          key: Key('$keyPrefix-label'),
          style: Theme.of(context).textTheme.titleLarge,
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
