import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/generated/app_localizations.dart';

/// The sanity range the year row can step within. Not a business bound (each
/// call site decides that via [showMonthPicker]'s `firstMonth`/`lastMonth`) —
/// it only stops the year arrows from stepping without limit into years whose
/// formatted labels stop making sense.
const _sanityFirstYear = 1970;
const _sanityLastYear = 2100;

/// Opens the shared month picker on [initialMonth] and resolves to the first
/// day of the chosen month, or `null` when dismissed.
///
/// [firstMonth]/[lastMonth] are optional bounds; months outside them (and the
/// year steps that would only reach out-of-range months) render disabled
/// rather than silently ignoring the tap. Callers whose own next/previous
/// arrows are unbounded should leave them `null`, so a month the arrows can
/// step to is never unreachable by jumping.
Future<DateTime?> showMonthPicker(
  BuildContext context, {
  required DateTime initialMonth,
  DateTime? firstMonth,
  DateTime? lastMonth,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => MonthPickerDialog(
      initialMonth: initialMonth,
      firstMonth: firstMonth,
      lastMonth: lastMonth,
    ),
  );
}

/// A year row (`‹ 2026 ›`) over a 4×3 grid of months, so any year and month is
/// one interaction away instead of a run of next/previous month taps.
///
/// Only calendar fields are read off the [DateTime]s it is given, and the one
/// it returns is built from fields — no instant arithmetic — so it behaves the
/// same in every time zone.
class MonthPickerDialog extends StatefulWidget {
  final DateTime initialMonth;
  final DateTime? firstMonth;
  final DateTime? lastMonth;

  const MonthPickerDialog({
    super.key,
    required this.initialMonth,
    this.firstMonth,
    this.lastMonth,
  });

  @override
  State<MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<MonthPickerDialog> {
  late int _year = widget.initialMonth.year;

  /// Months as a single comparable ordinal, so a bound check is one integer
  /// comparison and never touches instants.
  static int _ordinal(int year, int month) => year * 12 + (month - 1);

  int get _firstOrdinal {
    final bound = widget.firstMonth;
    final sanity = _ordinal(_sanityFirstYear, 1);
    if (bound == null) return sanity;
    final requested = _ordinal(bound.year, bound.month);
    return requested > sanity ? requested : sanity;
  }

  int get _lastOrdinal {
    final bound = widget.lastMonth;
    final sanity = _ordinal(_sanityLastYear, 12);
    if (bound == null) return sanity;
    final requested = _ordinal(bound.year, bound.month);
    return requested < sanity ? requested : sanity;
  }

  bool _monthEnabled(int month) {
    final ordinal = _ordinal(_year, month);
    return ordinal >= _firstOrdinal && ordinal <= _lastOrdinal;
  }

  /// A year is reachable when any of its months is in range.
  bool _yearReachable(int year) =>
      _ordinal(year, 12) >= _firstOrdinal && _ordinal(year, 1) <= _lastOrdinal;

  void _stepYear(int delta) => setState(() => _year += delta);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final languageTag = Localizations.localeOf(context).toLanguageTag();
    // The *short* month names: `zh`'s full `MONTHS` are 「三月」 while its
    // `SHORTMONTHS` are 「3月」, and the rest of the app writes months the
    // short way.
    final monthFormat = DateFormat.MMM(languageTag);

    return AlertDialog(
      title: Text(loc.monthPickerTitle),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  key: const Key('month-picker-year-previous'),
                  tooltip: loc.monthPickerPreviousYearTooltip,
                  onPressed: _yearReachable(_year - 1)
                      ? () => _stepYear(-1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    _year.toString(),
                    key: const Key('month-picker-year-label'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const Key('month-picker-year-next'),
                  tooltip: loc.monthPickerNextYearTooltip,
                  onPressed: _yearReachable(_year + 1)
                      ? () => _stepYear(1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var row = 0; row < 3; row++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    for (var column = 0; column < 4; column++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _MonthCell(
                            month: row * 4 + column + 1,
                            label: monthFormat.format(
                              DateTime(_year, row * 4 + column + 1),
                            ),
                            selected:
                                _year == widget.initialMonth.year &&
                                row * 4 + column + 1 ==
                                    widget.initialMonth.month,
                            enabled: _monthEnabled(row * 4 + column + 1),
                            onPressed: () => Navigator.of(
                              context,
                            ).pop(DateTime(_year, row * 4 + column + 1, 1)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MonthCell extends StatelessWidget {
  final int month;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  const _MonthCell({
    required this.month,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final button = selected
        ? FilledButton(
            onPressed: enabled ? onPressed : null,
            child: Text(label),
          )
        : OutlinedButton(
            onPressed: enabled ? onPressed : null,
            child: Text(label),
          );
    // `selected` is carried in the semantics too, so the current month isn't
    // signalled by fill color alone.
    return Semantics(
      key: Key('month-picker-month-$month'),
      container: true,
      selected: selected,
      child: button,
    );
  }
}
