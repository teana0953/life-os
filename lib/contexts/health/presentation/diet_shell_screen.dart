import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/sign_out.dart';
import '../../auth/domain/auth_repository.dart';
import '../application/get_logged_days.dart';
import '../domain/food_entry.dart';
import '../domain/food_item.dart';
import 'daily_target_controller.dart';
import 'daily_target_screen.dart';
import 'dictionary_controller.dart';
import 'dictionary_screen.dart';
import 'edit_entry_controller.dart';
import 'edit_entry_screen.dart';
import 'log_entry_controller.dart';
import 'log_entry_screen.dart';
import 'manual_entry_controller.dart';
import 'manual_entry_screen.dart';
import 'today_controller.dart';
import 'today_screen.dart';

String _dayString(DateTime time) {
  final y = time.year.toString().padLeft(4, '0');
  final m = time.month.toString().padLeft(2, '0');
  final d = time.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String _monthString(DateTime time) {
  final y = time.year.toString().padLeft(4, '0');
  final m = time.month.toString().padLeft(2, '0');
  return '$y-$m';
}

/// Strips the time-of-day, keeping only the calendar date (in whatever
/// "zone" [time] is already expressed in — callers are responsible for
/// passing a value that already represents the intended wall-clock day).
DateTime _dateOnly(DateTime time) => DateTime(time.year, time.month, time.day);

/// The number of calendar days from [from] to [to] (both already
/// date-only). Anchored in UTC rather than computed via
/// `to.difference(from).inDays` on local `DateTime`s: two local midnights
/// straddling a DST transition aren't always exactly 24h apart, which would
/// truncate `.inDays` to the wrong count. UTC has no DST, so this always
/// reflects the true calendar-day gap.
int _daysBetween(DateTime from, DateTime to) {
  final fromUtc = DateTime.utc(from.year, from.month, from.day);
  final toUtc = DateTime.utc(to.year, to.month, to.day);
  return toUtc.difference(fromUtc).inDays;
}

/// The day-navigation header label: "Today"/"Yesterday" for the two nearby
/// days, else a formatted date.
String _dayLabel(AppLocalizations loc, DateTime viewedDate, DateTime today) {
  final diff = _daysBetween(viewedDate, today);
  if (diff == 0) return loc.dietDayToday;
  if (diff == 1) return loc.dietDayYesterday;
  return DateFormat.yMMMd().format(viewedDate);
}

/// Diet shell: bottom navigation across Today, Dictionary, and Target.
/// Owns the auth-token load (mirroring `_AuthenticatedHome`) and passes it
/// down to each section's controller.
class DietShellScreen extends StatefulWidget {
  final AuthRepository authRepository;
  final TodayController todayController;
  final DictionaryController dictionaryController;
  final DailyTargetController dailyTargetController;
  final LogEntryController logEntryController;
  final ManualEntryController manualEntryController;
  final EditEntryController editEntryController;
  final GetLoggedDays getLoggedDays;
  final SignOut? signOut;

  /// Returns the current time, used to resolve "today" and to default the
  /// log-entry eaten-at time. Defaults to [DateTime.now]; tests inject a
  /// fixed clock.
  final DateTime Function() clock;

  const DietShellScreen({
    super.key,
    required this.authRepository,
    required this.todayController,
    required this.dictionaryController,
    required this.dailyTargetController,
    required this.logEntryController,
    required this.manualEntryController,
    required this.editEntryController,
    required this.getLoggedDays,
    this.signOut,
    this.clock = DateTime.now,
  });

  @override
  State<DietShellScreen> createState() => _DietShellScreenState();
}

class _DietShellScreenState extends State<DietShellScreen> {
  int _index = 0;
  String? _idToken;
  late DateTime _viewedDate = _dateOnly(widget.clock());
  late String _day = _dayString(_viewedDate);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = await widget.authRepository.idToken() ?? '';
    setState(() => _idToken = token);
    await widget.todayController.load(token, _day);
    await widget.dictionaryController.load(token);
    await widget.dailyTargetController.load(token, _day);
  }

  Future<void> _reloadCurrentDay() async {
    final token = _idToken;
    if (token == null) return;
    await widget.todayController.load(token, _day);
    await widget.dailyTargetController.load(token, _day);
  }

  Future<void> _setViewedDate(DateTime date) async {
    setState(() {
      _viewedDate = date;
      _day = _dayString(date);
    });
    await _reloadCurrentDay();
  }

  void _openLogEntry(FoodItem item) {
    final idToken = _idToken;
    if (idToken == null) return;
    widget.logEntryController.start(item, clock: widget.clock);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LogEntryScreen(
          controller: widget.logEntryController,
          idToken: idToken,
          day: _day,
          onSaved: () => widget.todayController.load(idToken, _day),
        ),
      ),
    );
  }

  void _openManualEntry() {
    final idToken = _idToken;
    if (idToken == null) return;
    widget.manualEntryController.start(clock: widget.clock);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManualEntryScreen(
          controller: widget.manualEntryController,
          idToken: idToken,
          day: _day,
          onSaved: () => widget.todayController.load(idToken, _day),
        ),
      ),
    );
  }

  void _openEditEntry(FoodEntry entry) {
    final idToken = _idToken;
    if (idToken == null) return;
    widget.editEntryController.start(entry);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditEntryScreen(
        controller: widget.editEntryController,
        idToken: idToken,
        onSaved: _reloadCurrentDay,
        onDeleted: _reloadCurrentDay,
      ),
    );
  }

  Future<void> _openCalendar() async {
    final idToken = _idToken;
    if (idToken == null) return;
    final today = _dateOnly(widget.clock());
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => _DietCalendarDialog(
        initialMonth: _viewedDate,
        today: today,
        idToken: idToken,
        getLoggedDays: widget.getLoggedDays,
      ),
    );
    if (picked != null) {
      await _setViewedDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final idToken = _idToken;
    final today = _dateOnly(widget.clock());
    final isToday = _viewedDate == today;

    final screens = [
      Column(
        children: [
          _DayNavBar(
            label: _dayLabel(loc, _viewedDate, today),
            // `DateUtils.addDaysToDate` does pure calendar-component
            // arithmetic (year/month/day), not `Duration` math on an
            // absolute instant, so it can't drift a day off across a DST
            // transition the way `_viewedDate.add(Duration(days: 1))` could.
            onPrevious: () =>
                _setViewedDate(DateUtils.addDaysToDate(_viewedDate, -1)),
            onNext: isToday
                ? null
                : () => _setViewedDate(DateUtils.addDaysToDate(_viewedDate, 1)),
            onOpenCalendar: _openCalendar,
          ),
          Expanded(
            child: TodayScreen(
              controller: widget.todayController,
              signOut: widget.signOut ?? SignOut(widget.authRepository),
              onAddEntry: () => setState(() => _index = 1),
              onEditEntry: _openEditEntry,
            ),
          ),
        ],
      ),
      DictionaryScreen(
        controller: widget.dictionaryController,
        onSelectItem: _openLogEntry,
        onManualEntry: _openManualEntry,
      ),
      idToken == null
          ? const Center(child: CircularProgressIndicator())
          : DailyTargetScreen(
              controller: widget.dailyTargetController,
              idToken: idToken,
              day: _day,
              // Refresh Today's portion progress after the target changes,
              // so switching back to Today reflects the new target.
              onSaved: () => widget.todayController.load(idToken, _day),
            ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.today),
            label: loc.dietTabToday,
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book),
            label: loc.dietTabDictionary,
          ),
          NavigationDestination(
            icon: const Icon(Icons.flag),
            label: loc.dietTabTarget,
          ),
        ],
      ),
    );
  }
}

/// Day-navigation header shown above the Today section (D3 in design.md):
/// `‹ label ›` plus a calendar entry point. [onNext] is `null` to disable
/// the "next day" control when the viewed day is today.
class _DayNavBar extends StatelessWidget {
  final String label;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onOpenCalendar;

  const _DayNavBar({
    required this.label,
    required this.onPrevious,
    required this.onNext,
    required this.onOpenCalendar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    return Row(
      children: [
        IconButton(
          key: const Key('day-nav-previous'),
          tooltip: loc.dietDayPrevTooltip,
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            label,
            key: const Key('day-nav-label'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
        ),
        IconButton(
          key: const Key('day-nav-next'),
          tooltip: loc.dietDayNextTooltip,
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
        IconButton(
          key: const Key('day-nav-calendar'),
          tooltip: loc.dietCalendarOpenTooltip,
          onPressed: onOpenCalendar,
          icon: const Icon(Icons.calendar_month),
        ),
      ],
    );
  }
}

/// Month calendar dialog (D4 in design.md): dots mark days with at least
/// one entry (via [getLoggedDays]); dates after [today] are dimmed and
/// non-selectable; picking a day pops it back to the caller. A
/// [getLoggedDays] failure degrades to an unmarked (still usable) calendar
/// rather than blocking navigation.
class _DietCalendarDialog extends StatefulWidget {
  final DateTime initialMonth;
  final DateTime today;
  final String idToken;
  final GetLoggedDays getLoggedDays;

  const _DietCalendarDialog({
    required this.initialMonth,
    required this.today,
    required this.idToken,
    required this.getLoggedDays,
  });

  @override
  State<_DietCalendarDialog> createState() => _DietCalendarDialogState();
}

class _DietCalendarDialogState extends State<_DietCalendarDialog> {
  late DateTime _visibleMonth = DateTime(
    widget.initialMonth.year,
    widget.initialMonth.month,
  );
  Set<String> _loggedDays = {};

  @override
  void initState() {
    super.initState();
    _loadLoggedDays();
  }

  Future<void> _loadLoggedDays() async {
    final month = _monthString(_visibleMonth);
    Set<String> days;
    try {
      days = (await widget.getLoggedDays(widget.idToken, month)).toSet();
    } catch (_) {
      days = {};
    }
    if (!mounted) return;
    setState(() => _loggedDays = days);
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
    _loadLoggedDays();
  }

  /// The visible month's day cells, grouped into weeks (`null` for the
  /// leading/trailing blanks), Sunday-first.
  List<List<int?>> _weeks() {
    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday % 7; // DateTime.sunday == 7
    final cells = <int?>[
      for (var i = 0; i < leadingBlanks; i++) null,
      for (var day = 1; day <= daysInMonth; day++) day,
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return [
      for (var i = 0; i < cells.length; i += 7) cells.sublist(i, i + 7),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(loc.dietCalendarTitle)),
          IconButton(
            key: const Key('calendar-close-button'),
            tooltip: loc.dietCalendarCloseTooltip,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  key: const Key('calendar-prev-month'),
                  tooltip: loc.dietCalendarPrevMonth,
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    DateFormat.yMMM().format(_visibleMonth),
                    key: const Key('calendar-month-label'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                IconButton(
                  key: const Key('calendar-next-month'),
                  tooltip: loc.dietCalendarNextMonth,
                  onPressed: () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Weekday header, Sunday-first to match the grid below (which is
            // always Sunday-first regardless of locale). `narrowWeekdays` is
            // itself Sunday-first for every locale (index 0 == Sunday); only
            // `firstDayOfWeekIndex`, which this grid intentionally ignores,
            // varies by locale.
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Center(
                      child: Text(
                        MaterialLocalizations.of(context).narrowWeekdays[i],
                        key: Key('calendar-weekday-$i'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (final week in _weeks())
              Row(
                children: [
                  for (final day in week)
                    Expanded(
                      child: day == null
                          ? const SizedBox(height: 40)
                          : _DayCell(
                              date: DateTime(
                                _visibleMonth.year,
                                _visibleMonth.month,
                                day,
                              ),
                              today: widget.today,
                              // `initialMonth` is the day the calendar was
                              // opened on (the currently-viewed day, D4 in
                              // design.md) — doubles as "the selected day" to
                              // highlight, not just the month anchor.
                              isSelected:
                                  DateTime(
                                    _visibleMonth.year,
                                    _visibleMonth.month,
                                    day,
                                  ) ==
                                  widget.initialMonth,
                              isMarked: _loggedDays.contains(
                                _dayString(
                                  DateTime(
                                    _visibleMonth.year,
                                    _visibleMonth.month,
                                    day,
                                  ),
                                ),
                              ),
                            ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// A single selectable day cell in [_DietCalendarDialog]'s grid (D4 in
/// design.md): the day number, dimmed and disabled when [date] is after
/// [today]; a primary-colored outline ring when [date] is today; a filled
/// primary circle with reversed (on-primary) text when [isSelected] (the
/// day currently being viewed); and a small dot when [isMarked] (the day has
/// at least one logged entry). The today ring and the selected fill can
/// overlap (e.g. viewing today shows both at once). Colors come from
/// [Theme.of(context)] only (no hard-coded `Color`/`Colors.*`).
class _DayCell extends StatelessWidget {
  final DateTime date;
  final DateTime today;
  final bool isSelected;
  final bool isMarked;

  const _DayCell({
    required this.date,
    required this.today,
    required this.isSelected,
    required this.isMarked,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayString = _dayString(date);
    final isFuture = date.isAfter(today);
    final isToday = date == today;

    final Color textColor;
    if (isSelected) {
      textColor = theme.colorScheme.onPrimary;
    } else if (isFuture) {
      textColor = theme.colorScheme.onSurfaceVariant;
    } else {
      textColor = theme.colorScheme.onSurface;
    }

    return InkWell(
      key: Key('calendar-day-$dayString'),
      onTap: isFuture ? null : () => Navigator.of(context).pop(date),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: Key('calendar-day-marker-$dayString'),
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? theme.colorScheme.primary : null,
                border: isToday
                    ? Border.all(color: theme.colorScheme.primary, width: 2)
                    : null,
              ),
              child: Text(
                '${date.day}',
                style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              width: 6,
              height: 6,
              child: isMarked
                  ? DecoratedBox(
                      key: Key('calendar-day-dot-$dayString'),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
