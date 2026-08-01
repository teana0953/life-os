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

/// The row height of a year in the year list, and the unit the list's initial
/// scroll offset is computed in.
const _yearRowExtent = 48.0;

/// A year row (`‹ 2026 ▾ ›`) over a 4×3 grid of months, so any year and month
/// is one interaction away instead of a run of next/previous month taps. The
/// year label itself opens a scrollable list of years, so a jump of several
/// years isn't a run of year-arrow taps either.
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
  /// The month the dialog opens on, pulled inside the bounds when the caller's
  /// [MonthPickerDialog.initialMonth] falls outside them. Without the clamp an
  /// out-of-range initial month is a dead end: all twelve cells and both year
  /// arrows render disabled and the only way out is cancelling.
  late final DateTime _openOn = _clamp(widget.initialMonth);

  late int _year = _openOn.year;

  /// Whether the year list has replaced the month grid.
  bool _pickingYear = false;
  ScrollController? _yearScroll;

  @override
  void dispose() {
    _yearScroll?.dispose();
    super.dispose();
  }

  /// Months as a single comparable ordinal, so a bound check is one integer
  /// comparison and never touches instants.
  static int _ordinal(int year, int month) => year * 12 + (month - 1);

  DateTime _clamp(DateTime month) {
    final ordinal = _ordinal(
      month.year,
      month.month,
    ).clamp(_firstOrdinal, _lastOrdinal);
    return DateTime(ordinal ~/ 12, ordinal % 12 + 1);
  }

  int get _firstYear => _firstOrdinal ~/ 12;
  int get _lastYear => _lastOrdinal ~/ 12;

  void _openYearList() {
    // Open with the current year a couple of rows down rather than at the top
    // of a 131-row list, so the user lands where they already are.
    final offset = ((_year - _firstYear) * _yearRowExtent - _yearRowExtent * 2)
        .clamp(0.0, double.infinity);
    _yearScroll?.dispose();
    _yearScroll = ScrollController(initialScrollOffset: offset);
    setState(() => _pickingYear = true);
  }

  void _selectYear(int year) => setState(() {
    _year = year;
    _pickingYear = false;
  });

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
      // Tightened from the Material defaults (40/24 inset, 24 content): they
      // squeeze the four columns to 40dp at a 320dp viewport — under the 48dp
      // touch minimum, with every label wrapping.
      insetPadding: const EdgeInsets.all(16),
      contentPadding: const EdgeInsets.all(16),
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
                  child: Tooltip(
                    message: loc.monthPickerYearTooltip,
                    // The key stays on the `Text`; the tappable wrapper and the
                    // caret go around it.
                    child: Semantics(
                      button: true,
                      child: InkWell(
                        onTap: _pickingYear
                            ? () => setState(() => _pickingYear = false)
                            : _openYearList,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _year.toString(),
                                key: const Key('month-picker-year-label'),
                                style: theme.textTheme.titleMedium,
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
            if (_pickingYear) _yearList() else ..._monthGrid(monthFormat),
          ],
        ),
      ),
    );
  }

  Widget _yearList() {
    return SizedBox(
      height: _yearRowExtent * 5,
      child: ListView.builder(
        controller: _yearScroll,
        itemExtent: _yearRowExtent,
        // Only the years the bounds can actually reach, so the list never
        // offers a year whose every month is disabled.
        itemCount: _lastYear - _firstYear + 1,
        itemBuilder: (context, index) {
          final year = _firstYear + index;
          return _YearCell(
            year: year,
            selected: year == _year,
            onPressed: () => _selectYear(year),
          );
        },
      ),
    );
  }

  List<Widget> _monthGrid(DateFormat monthFormat) => [
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
                        _year == _openOn.year &&
                        row * 4 + column + 1 == _openOn.month,
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
  ];
}

/// One year in the year list. Like [_MonthCell], `selected` is carried in the
/// semantics as well as the fill, folded into the button's own node.
class _YearCell extends StatelessWidget {
  final int year;
  final bool selected;
  final VoidCallback onPressed;

  const _YearCell({
    required this.year,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final button = selected
        ? FilledButton(onPressed: onPressed, child: Text('$year'))
        : TextButton(onPressed: onPressed, child: Text('$year'));
    return MergeSemantics(
      child: Semantics(
        key: Key('month-picker-year-$year'),
        container: true,
        selected: selected,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: SizedBox(width: double.infinity, child: button),
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
    // The default button padding (24 horizontal) leaves a 320dp-wide dialog
    // ~8dp for the label and wraps every cell; the explicit minimum height
    // keeps the cell at the 48dp touch minimum once that padding is gone.
    final style = ButtonStyle(
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 4),
      ),
      minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    final text = Text(label, maxLines: 1);
    final button = selected
        ? FilledButton(
            style: style,
            onPressed: enabled ? onPressed : null,
            child: text,
          )
        : OutlinedButton(
            style: style,
            onPressed: enabled ? onPressed : null,
            child: text,
          );
    // `selected` is carried in the semantics too, so the current month isn't
    // signalled by fill color alone. `MergeSemantics` folds it into the
    // button's own node: left unmerged, `selected` sits on an unlabelled
    // parent and a screen reader announces only "Jul, button".
    return MergeSemantics(
      child: Semantics(
        key: Key('month-picker-month-$month'),
        container: true,
        selected: selected,
        child: button,
      ),
    );
  }
}
