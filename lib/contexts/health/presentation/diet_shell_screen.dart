import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/mascot.dart';
import '../../auth/application/sign_out.dart';
import '../../auth/domain/auth_repository.dart';
import '../application/get_logged_days.dart';
import '../domain/day_diet_log.dart';
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

/// The day-navigation chip label: "Today"/"Yesterday" for the two nearby
/// days, else `null` (no chip — the full date alone is shown).
/// Portion of the screen height the dictionary bottom sheet occupies (D1/D2
/// in design.md): "a large majority of the screen, with Today peeking out
/// behind the scrim" per the design mockup — not the near-fullscreen panel
/// `showModalBottomSheet(isScrollControlled: true)` produces on its own with
/// no height cap. See `_openDictionarySheet`.
const double _dictionarySheetHeightFactor = 0.9;

/// Corner radius for the dictionary sheet's rounded top corners (D1/D2 in
/// design.md), matching the rounded-corner language used elsewhere in the
/// design system. See `_openDictionarySheet`.
const Radius _dictionarySheetCornerRadius = Radius.circular(20);

String? _dayChipLabel(
  AppLocalizations loc,
  DateTime viewedDate,
  DateTime today,
) {
  final diff = _daysBetween(viewedDate, today);
  if (diff == 0) return loc.dietDayToday;
  if (diff == 1) return loc.dietDayYesterday;
  return null;
}

/// Whether [meal] represents a snack session (D1/D5 in design.md): any name
/// that isn't one of the three standard meals. A snack session's
/// `_currentMeal` holds its display name ("點心2", a rename like "下午茶", …)
/// rather than a fixed code, so this name-based test is how both the
/// logging bar's segment derivation and the snack-numbering recompute gate
/// recognize "currently in a snack session".
bool _isSnackMeal(String meal) =>
    meal != 'breakfast' && meal != 'lunch' && meal != 'dinner';

/// Maps a raw meal value to its localized label for the logging bar/snackbar
/// (mirrors `today_screen.dart`'s private `_mealLabel`); a snack's display
/// name is shown as-is.
String _mealDisplayLabel(AppLocalizations loc, String meal) {
  switch (meal) {
    case 'breakfast':
      return loc.dietMealBreakfast;
    case 'lunch':
      return loc.dietMealLunch;
    case 'dinner':
      return loc.dietMealDinner;
    default:
      return meal;
  }
}

/// The display name for what a [LogEntryController]/[ManualEntryController]
/// actually just saved (D3 in design.md): [meal]/[snackLabel] read from the
/// controller *after* a successful save, not the shell's session-level
/// `_currentMeal` — the quantity/manual card lets the user override the meal
/// (or the snack label) for a single entry without changing the session, so
/// the two can differ. A standard meal is localized; a snack shows its saved
/// label verbatim.
String _savedMealLabel(AppLocalizations loc, String meal, String snackLabel) {
  if (meal == snackMealValue) return snackLabel;
  return _mealDisplayLabel(loc, meal);
}

/// The next name in a day's snack series (D1/D5 in design.md), from [dayLog]'s
/// current meal group names: seeds a brand-new snack session (the shell's
/// add-snack affordance) and drives the dictionary sheet's own segment-select
/// recompute (switching from a non-snack segment into snack) — both read from
/// `todayController.dayLog` rather than a snack controller (there is none),
/// per D1 in design.md.
String _nextSnackNameForDay(AppLocalizations loc, DayDietLog? dayLog) {
  final mealNames = dayLog?.meals.map((meal) => meal.meal).toList() ?? const <String>[];
  return nextSnackName(mealNames, loc.dietSnackBaseName);
}

/// The full, always-shown date text for the day-navigation header, formatted
/// per the active locale: `M月d日 EEEE` for Chinese (e.g. "7月19日 星期六"),
/// `EEE, MMM d` otherwise (e.g. "Sat, Jul 19").
String _fullDateLabel(BuildContext context, DateTime viewedDate) {
  final languageTag = Localizations.localeOf(context).toLanguageTag();
  final pattern = languageTag.startsWith('zh') ? 'M月d日 EEEE' : 'EEE, MMM d';
  return DateFormat(pattern, languageTag).format(viewedDate);
}

/// Diet shell: bottom navigation across Today and Target; the food
/// dictionary is reached only via the add-food bottom sheet (D1/D2 in
/// design.md), not a tab. Owns the auth-token load (mirroring
/// `_AuthenticatedHome`) and passes it down to each section's controller.
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

  /// Opens the dictionary bottom sheet (D1/D2 in design.md), seeded to
  /// [initialMeal] (a standard meal, or the next snack name for the
  /// add-snack affordance — computed by the caller). Replaces the old
  /// tab-switch (`setState(_index = 1)`): the logging session's current meal
  /// no longer lives on the shell at all — see `_DictionarySheet`, which owns
  /// it from here on, seeded once by this call.
  ///
  /// Capped at [_dictionarySheetHeightFactor] of the screen height via
  /// [FractionallySizedBox]: `isScrollControlled: true` alone lets the sheet
  /// grow as tall as its child requests, and `_DictionarySheet`'s own
  /// `Scaffold` requests all the space it's given — with no cap that reads
  /// as a near-fullscreen panel, hiding Today (the scrim) behind it entirely.
  /// `showDragHandle`/`shape` add the grab handle and rounded top corners;
  /// `clipBehavior: Clip.antiAlias` makes that `shape` actually clip the
  /// sheet's content (the nested `Scaffold`s paint square corners otherwise —
  /// an opaque child can extend past `shape` unless clipped, per
  /// `BottomSheet.clipBehavior`'s own doc).
  void _openDictionarySheet(String initialMeal) {
    final idToken = _idToken;
    if (idToken == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: _dictionarySheetCornerRadius),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: _dictionarySheetHeightFactor,
        child: _DictionarySheet(
          dictionaryController: widget.dictionaryController,
          logEntryController: widget.logEntryController,
          manualEntryController: widget.manualEntryController,
          todayController: widget.todayController,
          idToken: idToken,
          day: _day,
          initialMeal: initialMeal,
          clock: widget.clock,
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
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _DayNavBar(
                  viewedDate: _viewedDate,
                  today: today,
                  // `DateUtils.addDaysToDate` does pure calendar-component
                  // arithmetic (year/month/day), not `Duration` math on an
                  // absolute instant, so it can't drift a day off across a
                  // DST transition the way
                  // `_viewedDate.add(Duration(days: 1))` could.
                  onPrevious: () =>
                      _setViewedDate(DateUtils.addDaysToDate(_viewedDate, -1)),
                  onNext: isToday
                      ? null
                      : () => _setViewedDate(
                          DateUtils.addDaysToDate(_viewedDate, 1),
                        ),
                  onOpenCalendar: _openCalendar,
                  onGoHome: () => Navigator.of(context).pop(),
                ),
              ),
              Expanded(
                child: TodayScreen(
                  controller: widget.todayController,
                  signOut: widget.signOut ?? SignOut(widget.authRepository),
                  onAddToMeal: _openDictionarySheet,
                  onAddSnack: () => _openDictionarySheet(
                    _nextSnackNameForDay(loc, widget.todayController.dayLog),
                  ),
                  onEditEntry: _openEditEntry,
                ),
              ),
            ],
          ),
        ),
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
            icon: const Icon(Icons.flag),
            label: loc.dietTabTarget,
          ),
        ],
      ),
    );
  }
}

/// Diet header shown above the Today section (D3 in design.md): a mascot
/// beside a title ("Today's Food" / "Food Log", depending on whether the
/// viewed day is today) and a day-navigation row (`‹ date ›`, where the date
/// itself is the calendar entry point). The date is always shown in full;
/// today/yesterday are called out with a small chip *alongside* the date
/// rather than replacing it. [onNext] is `null` to disable the "next day"
/// control when the viewed day is today. [onGoHome] wires the header's home
/// control (D5 in design.md), returning to the home "your spaces" screen the
/// diet module was pushed from.
class _DayNavBar extends StatelessWidget {
  final DateTime viewedDate;
  final DateTime today;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onOpenCalendar;
  final VoidCallback onGoHome;

  const _DayNavBar({
    required this.viewedDate,
    required this.today,
    required this.onPrevious,
    required this.onNext,
    required this.onOpenCalendar,
    required this.onGoHome,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final isToday = _daysBetween(viewedDate, today) == 0;
    final title = isToday ? loc.dietTodayTitle : loc.dietHistoryTitle;
    final chipLabel = _dayChipLabel(loc, viewedDate, today);
    final dateText = _fullDateLabel(context, viewedDate);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Mascot(size: 34),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    key: const Key('day-nav-previous'),
                    tooltip: loc.dietDayPrevTooltip,
                    onPressed: onPrevious,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Tooltip(
                      message: loc.dietCalendarOpenTooltip,
                      child: Semantics(
                        button: true,
                        child: InkWell(
                          key: const Key('day-nav-label'),
                          onTap: onOpenCalendar,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (chipLabel != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      chipLabel,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onPrimaryContainer,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  dateText,
                                  style: theme.textTheme.bodyMedium,
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.calendar_month,
                                  size: 16,
                                  color: theme.colorScheme.outline,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('day-nav-next'),
                    tooltip: loc.dietDayNextTooltip,
                    onPressed: onNext,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          key: const Key('today-home-button'),
          tooltip: loc.dietGoHomeTooltip,
          onPressed: onGoHome,
          icon: const Icon(Icons.home),
        ),
      ],
    );
  }
}

/// The four selectable segments on [_LoggingMealBar] (D1 in design.md). A
/// snack session's actual `_currentMeal` is its display name ("點心2", a
/// rename, …), not this enum — [_DictionarySheetState._selectedSegment]
/// derives [snack] whenever `_currentMeal` isn't one of the three standard
/// meals (see [_isSnackMeal]).
enum _LoggingMealSegment { breakfast, lunch, dinner, snack }

/// The continuous-logging session bar shown atop the dictionary sheet (D1 in
/// design.md): a "Logging to" title naming the current meal, a Done button,
/// a wrapping row of meal choice chips (breakfast/lunch/dinner/snack), and — only
/// while the snack segment is selected — a rename affordance for the
/// current snack session.
/// Purely presentational: [_DictionarySheetState] owns `_currentMeal`, the
/// segment-derivation, and the numbering recompute gate; this widget only
/// reports taps via its callbacks. Colors from theme, strings from ARB.
class _LoggingMealBar extends StatefulWidget {
  final _LoggingMealSegment selectedSegment;
  final String currentMealLabel;
  final ValueChanged<_LoggingMealSegment> onSegmentSelected;
  final ValueChanged<String> onRenameSnack;
  final VoidCallback onDone;

  const _LoggingMealBar({
    required this.selectedSegment,
    required this.currentMealLabel,
    required this.onSegmentSelected,
    required this.onRenameSnack,
    required this.onDone,
  });

  @override
  State<_LoggingMealBar> createState() => _LoggingMealBarState();
}

class _LoggingMealBarState extends State<_LoggingMealBar> {
  bool _renaming = false;
  late final TextEditingController _renameText;

  @override
  void initState() {
    super.initState();
    _renameText = TextEditingController(text: widget.currentMealLabel);
  }

  @override
  void didUpdateWidget(covariant _LoggingMealBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_renaming && oldWidget.currentMealLabel != widget.currentMealLabel) {
      _renameText.text = widget.currentMealLabel;
    }
  }

  @override
  void dispose() {
    _renameText.dispose();
    super.dispose();
  }

  void _confirmRename() {
    final value = _renameText.text.trim();
    setState(() => _renaming = false);
    if (value.isNotEmpty) widget.onRenameSnack(value);
  }

  /// Cancels the rename without saving: restores the field to the
  /// still-current name (so a stale edit isn't silently kept for next time)
  /// and closes the field. Never calls `onRenameSnack`, so `_currentMeal` is
  /// untouched — the previous behavior of submitting an emptied field to
  /// silently cancel is no longer the only way out.
  void _cancelRename() {
    setState(() {
      _renaming = false;
      _renameText.text = widget.currentMealLabel;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isSnackSelected = widget.selectedSegment == _LoggingMealSegment.snack;

    return Container(
      key: const Key('logging-meal-bar'),
      padding: const EdgeInsets.all(16),
      // Separates this bar's own meal chip row from the Dictionary screen's
      // "all/favorites" SegmentedButton immediately below it — the two
      // would otherwise visually run together (both are pill-grouped
      // segmented controls sitting right on top of each other).
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  loc.dietLoggingToMeal(widget.currentMealLabel),
                  key: const Key('logging-meal-bar-title'),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              TextButton(
                key: const Key('logging-meal-bar-done-button'),
                onPressed: widget.onDone,
                child: Text(loc.dietLoggingDoneButton),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                key: const Key('logging-meal-chip-breakfast'),
                label: Text(loc.dietMealBreakfast),
                selected: widget.selectedSegment == _LoggingMealSegment.breakfast,
                onSelected: (_) =>
                    widget.onSegmentSelected(_LoggingMealSegment.breakfast),
              ),
              ChoiceChip(
                key: const Key('logging-meal-chip-lunch'),
                label: Text(loc.dietMealLunch),
                selected: widget.selectedSegment == _LoggingMealSegment.lunch,
                onSelected: (_) =>
                    widget.onSegmentSelected(_LoggingMealSegment.lunch),
              ),
              ChoiceChip(
                key: const Key('logging-meal-chip-dinner'),
                label: Text(loc.dietMealDinner),
                selected: widget.selectedSegment == _LoggingMealSegment.dinner,
                onSelected: (_) =>
                    widget.onSegmentSelected(_LoggingMealSegment.dinner),
              ),
              ChoiceChip(
                key: const Key('logging-meal-chip-snack'),
                label: Text(loc.dietSnackBaseName),
                selected: isSnackSelected,
                onSelected: (_) =>
                    widget.onSegmentSelected(_LoggingMealSegment.snack),
              ),
              if (isSnackSelected && !_renaming)
                IconButton(
                  key: const Key('logging-meal-bar-rename-button'),
                  tooltip: loc.dietSnackRenameTooltip,
                  onPressed: () => setState(() => _renaming = true),
                  icon: const Icon(Icons.edit),
                ),
            ],
          ),
          if (isSnackSelected && _renaming) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('logging-meal-bar-rename-field'),
                    controller: _renameText,
                    decoration: InputDecoration(
                      hintText: loc.dietSnackRenameTooltip,
                    ),
                    onSubmitted: (_) => _confirmRename(),
                  ),
                ),
                IconButton(
                  key: const Key('logging-meal-bar-rename-confirm'),
                  tooltip: loc.dietSnackRenameConfirmTooltip,
                  onPressed: _confirmRename,
                  icon: const Icon(Icons.check),
                ),
                IconButton(
                  key: const Key('logging-meal-bar-rename-cancel'),
                  tooltip: loc.dietSnackRenameCancelTooltip,
                  onPressed: _cancelRename,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The dictionary bottom sheet (D1/D2/D3 in design.md): opened by the shell
/// (`_DietShellScreenState._openDictionarySheet`) in place of the old
/// tab-switch, stacked over Today. Owns the logging session's current meal —
/// moved here from the shell entirely, since a `showModalBottomSheet` builder
/// is a separate route that doesn't rebuild off the shell's `setState` — so
/// [_LoggingMealBar]'s segment-select/snack-rename, the recompute gate, and
/// [_nextSnackNameForDay] (fed by [todayController]'s `dayLog`, since there is
/// no snack controller) all operate on this sheet's own state.
///
/// Wraps its body in its own [ScaffoldMessenger] (not just a [Scaffold]:
/// under the single [ScaffoldMessenger] the app's `MaterialApp` already
/// provides, this sheet's Scaffold and the shell's Scaffold would both
/// register as sibling "root" Scaffolds — since a bottom sheet route lands as
/// a sibling overlay entry, not a descendant of the shell's Scaffold — so
/// [ScaffoldMessengerState.showSnackBar] would paint the "added" confirmation
/// into *both* simultaneously, including the shell's copy sitting invisibly
/// behind this modal sheet (D3 in design.md). A dedicated [ScaffoldMessenger]
/// scopes the snackbar to this sheet's own (visible) Scaffold only —
/// reached via [_DictionarySheetState._messengerKey], not
/// `ScaffoldMessenger.of(context)`: the *State's* own `context` is the
/// element `build()` is called *for*, i.e. above (not below) the
/// `ScaffoldMessenger` that `build()` returns, so an ancestor lookup from
/// there would skip past this sheet's own messenger and find the app's
/// outer one instead — silently recreating the exact bug this sheet exists
/// to avoid.
class _DictionarySheet extends StatefulWidget {
  final DictionaryController dictionaryController;
  final LogEntryController logEntryController;
  final ManualEntryController manualEntryController;
  final TodayController todayController;
  final String idToken;
  final String day;
  final String initialMeal;
  final DateTime Function() clock;

  const _DictionarySheet({
    required this.dictionaryController,
    required this.logEntryController,
    required this.manualEntryController,
    required this.todayController,
    required this.idToken,
    required this.day,
    required this.initialMeal,
    required this.clock,
  });

  @override
  State<_DictionarySheet> createState() => _DictionarySheetState();
}

class _DictionarySheetState extends State<_DictionarySheet> {
  late String _currentMeal = widget.initialMeal;

  /// Identifies this sheet's own [ScaffoldMessenger] (see [build]) so
  /// [_onEntrySaved] can reach its `ScaffoldMessengerState` directly. Not
  /// `ScaffoldMessenger.of(context)`: this `State`'s own `context` is the
  /// element *above* what `build()` returns, i.e. above (not below) the
  /// `ScaffoldMessenger` this sheet wraps itself in — so an ancestor lookup
  /// from here would skip right past it and hit the app's outer one instead,
  /// exactly the bug this sheet's own messenger exists to avoid (D3 in
  /// design.md).
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// The logging bar's selected segment, derived (not stored) from
  /// `_currentMeal` (D1 in design.md): the three standard meals select
  /// themselves; any other value (a snack's display name) selects the snack
  /// segment.
  _LoggingMealSegment _selectedSegment() {
    switch (_currentMeal) {
      case 'breakfast':
        return _LoggingMealSegment.breakfast;
      case 'lunch':
        return _LoggingMealSegment.lunch;
      case 'dinner':
        return _LoggingMealSegment.dinner;
      default:
        return _LoggingMealSegment.snack;
    }
  }

  /// Handles a tap on the logging bar's segmented control (D1/D5 in
  /// design.md). The snack-numbering recompute is gated: it only runs on a
  /// real non-snack -> snack transition (`_currentMeal` wasn't already a
  /// snack), so re-tapping the already-selected snack segment — e.g. a
  /// rebuild after a save reloads Today — doesn't advance the number or
  /// split the current batch into a new group.
  void _onSegmentSelected(_LoggingMealSegment segment) {
    switch (segment) {
      case _LoggingMealSegment.breakfast:
        setState(() => _currentMeal = 'breakfast');
      case _LoggingMealSegment.lunch:
        setState(() => _currentMeal = 'lunch');
      case _LoggingMealSegment.dinner:
        setState(() => _currentMeal = 'dinner');
      case _LoggingMealSegment.snack:
        if (_isSnackMeal(_currentMeal)) return;
        final loc = AppLocalizations.of(context)!;
        setState(
          () => _currentMeal = _nextSnackNameForDay(
            loc,
            widget.todayController.dayLog,
          ),
        );
    }
  }

  /// Renames the current snack session (D5 in design.md); still handed to
  /// the controllers as `meal: snackMealValue, snackLabel: <typed name>` via
  /// the same seam.
  void _onRenameSnack(String name) {
    setState(() => _currentMeal = name);
  }

  void _openLogEntry(FoodItem item) {
    final isSnack = _isSnackMeal(_currentMeal);
    widget.logEntryController.start(
      item,
      // D5 seam: a snack is always handed to the controller as
      // snackMealValue + the display name as snackLabel — never the bare
      // display name as `meal` — so the card's `isSnack` check stays true.
      meal: isSnack ? snackMealValue : _currentMeal,
      snackLabel: isSnack ? _currentMeal : '',
      clock: widget.clock,
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => LogEntryScreen(
        controller: widget.logEntryController,
        idToken: widget.idToken,
        day: widget.day,
        onSaved: () => _onEntrySaved(
          _savedMealLabel(
            AppLocalizations.of(context)!,
            widget.logEntryController.meal,
            widget.logEntryController.snackLabel,
          ),
        ),
      ),
    );
  }

  void _openManualEntry() {
    final isSnack = _isSnackMeal(_currentMeal);
    widget.manualEntryController.start(
      meal: isSnack ? snackMealValue : _currentMeal,
      snackLabel: isSnack ? _currentMeal : '',
      clock: widget.clock,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManualEntryScreen(
          controller: widget.manualEntryController,
          idToken: widget.idToken,
          day: widget.day,
          onSaved: () => _onEntrySaved(
            _savedMealLabel(
              AppLocalizations.of(context)!,
              widget.manualEntryController.meal,
              widget.manualEntryController.snackLabel,
            ),
          ),
        ),
      ),
    );
  }

  /// Mirrors the shell's former `_onEntrySaved` (D3 in design.md): reloads
  /// Today and shows a localized "Added to" snackbar naming [mealLabel] — the
  /// meal actually saved (see [_savedMealLabel]) — but through THIS sheet's
  /// own [ScaffoldMessenger] (see [build]), not the shell's, so it's visible
  /// above the sheet instead of painting invisibly behind it. Does NOT change
  /// `_currentMeal` — the next pick stays in the same meal/snack group. Any
  /// snackbar still showing from a previous save is dismissed first and the
  /// new one is kept brief, so rapid back-to-back logging shows the latest
  /// confirmation instead of queuing a backlog of 4s snackbars behind it.
  void _onEntrySaved(String mealLabel) {
    widget.todayController.load(widget.idToken, widget.day);
    final loc = AppLocalizations.of(context)!;
    final messenger = _messengerKey.currentState!;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1500),
        content: Text(loc.dietAddedToMealSnackbar(mealLabel)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _LoggingMealBar(
                selectedSegment: _selectedSegment(),
                currentMealLabel: _mealDisplayLabel(loc, _currentMeal),
                onSegmentSelected: _onSegmentSelected,
                onRenameSnack: _onRenameSnack,
                onDone: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: DictionaryScreen(
                  controller: widget.dictionaryController,
                  onSelectItem: _openLogEntry,
                  onManualEntry: _openManualEntry,
                ),
              ),
            ],
          ),
        ),
      ),
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
