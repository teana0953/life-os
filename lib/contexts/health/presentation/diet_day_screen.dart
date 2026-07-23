import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/widgets/tracker_day_nav_header.dart';
import '../../auth/application/sign_out.dart';
import '../../auth/domain/auth_repository.dart';
import '../application/get_logged_days.dart';
import 'create_meal_controller.dart';
import 'daily_target_controller.dart';
import 'daily_target_screen.dart';
import 'dictionary_controller.dart';
import 'food_search_screen.dart';
import 'snack_naming.dart';
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

/// The next name in a day's snack series, from [dayLog]'s current meal
/// names: seeds a brand-new snack session (the Today "＋ new snack"
/// control).
String _nextSnackNameForDay(AppLocalizations loc, List<String> mealNames) {
  return nextSnackName(mealNames, loc.dietSnackBaseName);
}

/// Diet shell: bottom navigation across Today and Target; food is added by
/// pushing the full-screen [FoodSearchScreen] for a target meal — there is
/// no dictionary tab or bottom sheet. Owns the auth-token load (mirroring
/// `_AuthenticatedHome`) and passes it down to each section's controller.
class DietDayScreen extends StatefulWidget {
  final AuthRepository authRepository;

  /// The auth token, resolved by the health scaffold (which pre-loaded today).
  final String idToken;
  final TodayController todayController;
  final DictionaryController dictionaryController;
  final DailyTargetController dailyTargetController;
  final CreateMealController createMealController;
  final GetLoggedDays getLoggedDays;
  final SignOut? signOut;

  /// Returns the current time, used to resolve "today". Defaults to
  /// [DateTime.now]; tests inject a fixed clock.
  final DateTime Function() clock;

  const DietDayScreen({
    super.key,
    required this.authRepository,
    required this.idToken,
    required this.todayController,
    required this.dictionaryController,
    required this.dailyTargetController,
    required this.createMealController,
    required this.getLoggedDays,
    this.signOut,
    this.clock = DateTime.now,
  });

  @override
  State<DietDayScreen> createState() => _DietDayScreenState();
}

class _DietDayScreenState extends State<DietDayScreen> {
  late final String _idToken = widget.idToken;
  late DateTime _viewedDate = _dateOnly(widget.clock());
  late String _day = _dayString(_viewedDate);

  @override
  void initState() {
    super.initState();
    // The diet controllers are shared and the day-nav mutates them to a browsed
    // day; reload today's meals/target on mount so re-entering the screen always
    // starts on today rather than the last day browsed in a previous visit.
    _reloadCurrentDay();
  }

  Future<void> _reloadCurrentDay() async {
    await widget.todayController.load(_idToken, _day);
    await widget.dailyTargetController.load(_idToken, _day);
  }

  Future<void> _setViewedDate(DateTime date) async {
    setState(() {
      _viewedDate = date;
      _day = _dayString(date);
    });
    await _reloadCurrentDay();
  }

  /// Pushes the full-screen food search targeting [meal], resetting the
  /// shared [CreateMealController] for a fresh session; on a completed
  /// result (the tray was saved), reloads Today + the target for the
  /// current day.
  Future<void> _openFoodSearch(String meal) async {
    final idToken = _idToken;
    widget.createMealController.start(meal);
    widget.dictionaryController.clearSearch();
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(
          meal: meal,
          dictionaryController: widget.dictionaryController,
          createMealController: widget.createMealController,
          idToken: idToken,
          day: _day,
          signOut: widget.signOut ?? SignOut(widget.authRepository),
        ),
      ),
    );
    if (result == true) {
      await _reloadCurrentDay();
    }
  }

  void _openAddSnack() {
    final loc = AppLocalizations.of(context)!;
    final mealNames =
        widget.todayController.dayMealsLog?.meals.map((m) => m.meal).toList() ??
        const <String>[];
    _openFoodSearch(_nextSnackNameForDay(loc, mealNames));
  }

  Future<void> _openCalendar() async {
    final idToken = _idToken;
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
    final today = _dateOnly(widget.clock());
    final isToday = _viewedDate == today;

    return Scaffold(
      appBar: AppBar(
        // Generic tracker name (like water/vitals/…); the today-aware title
        // lives in the shared day header in the body below.
        title: Text(loc.healthRecordDiet),
        actions: [
          TextButton.icon(
            key: const Key('diet-open-target'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DailyTargetScreen(
                  controller: widget.dailyTargetController,
                  idToken: _idToken,
                  day: _day,
                  // Refresh Today's portion progress after the target changes.
                  onSaved: () => widget.todayController.load(_idToken, _day),
                ),
              ),
            ),
            icon: const Icon(Icons.flag_outlined),
            label: Text(loc.dietTabTarget),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: TrackerDayNavHeader(
                    viewedDate: _viewedDate,
                    today: today,
                    todayTitle: loc.dietTodayTitle,
                    historyTitle: loc.dietHistoryTitle,
                    // Pure calendar-component arithmetic (not Duration math on
                    // an instant) so it can't drift a day across a DST boundary.
                    onPrevious: () =>
                        _setViewedDate(DateUtils.addDaysToDate(_viewedDate, -1)),
                    onNext: isToday
                        ? null
                        : () => _setViewedDate(
                            DateUtils.addDaysToDate(_viewedDate, 1),
                          ),
                    onOpenCalendar: _openCalendar,
                  ),
                ),
                Expanded(
                  child: TodayScreen(
                    controller: widget.todayController,
                    signOut: widget.signOut ?? SignOut(widget.authRepository),
                    idToken: _idToken,
                    day: _day,
                    onAddToMeal: _openFoodSearch,
                    onAddSnack: _openAddSnack,
                    onAddToSnackGroup: _openFoodSearch,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


/// Month calendar dialog: dots mark days with at least one meal (via
/// [getLoggedDays]); dates after [today] are dimmed and non-selectable;
/// picking a day pops it back to the caller. A [getLoggedDays] failure
/// degrades to an unmarked (still usable) calendar rather than blocking
/// navigation.
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
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final leadingBlanks = firstOfMonth.weekday % 7; // DateTime.sunday == 7
    final cells = <int?>[
      for (var i = 0; i < leadingBlanks; i++) null,
      for (var day = 1; day <= daysInMonth; day++) day,
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return [for (var i = 0; i < cells.length; i += 7) cells.sublist(i, i + 7)];
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
                    monthYearLabel(context, _visibleMonth),
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

/// A single selectable day cell in [_DietCalendarDialog]'s grid: the day
/// number, dimmed and disabled when [date] is after [today]; a
/// primary-colored outline ring when [date] is today; a filled primary
/// circle with reversed (on-primary) text when [isSelected] (the day
/// currently being viewed); and a small dot when [isMarked] (the day has at
/// least one meal). The today ring and the selected fill can overlap (e.g.
/// viewing today shows both at once). Colors come from [Theme.of(context)]
/// only (no hard-coded `Color`/`Colors.*`).
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
