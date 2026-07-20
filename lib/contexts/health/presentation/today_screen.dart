import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../auth/application/sign_out.dart';
import '../domain/day_diet_log.dart';
import '../domain/food_entry.dart';
import 'category_progress_bar.dart';
import 'log_entry_controller.dart' show snackMealValue;
import 'portion_pills.dart';
import 'today_controller.dart';

/// Maps a raw meal value to its localized label; falls back to the raw
/// value itself for custom snack labels. A bare, unnamed snack group
/// (`snackMealValue`, i.e. `'snack'`) gets the localized snack word rather
/// than falling through to the raw internal value (D1 in design.md) — named
/// snacks already carry their display name as the group `meal` and hit the
/// `default` branch unchanged.
String _mealLabel(AppLocalizations loc, String meal) {
  switch (meal) {
    case 'breakfast':
      return loc.dietMealBreakfast;
    case 'lunch':
      return loc.dietMealLunch;
    case 'dinner':
      return loc.dietMealDinner;
    case snackMealValue:
      return loc.dietSnackBaseName;
    default:
      return meal;
  }
}

/// Maps a raw meal value to its emoji (D2 in design.md); falls back to 🍎
/// for custom snack labels.
String _mealEmoji(String meal) {
  switch (meal) {
    case 'breakfast':
      return '🌅';
    case 'lunch':
      return '🍱';
    case 'dinner':
      return '🌙';
    default:
      return '🍎';
  }
}

/// The group's earliest eaten-at time — the `min` of every entry's
/// `eatenAt`, not `entries.first` (per-entry order within a group isn't
/// guaranteed by the domain).
DateTime _earliestEatenAt(List<FoodEntry> entries) =>
    entries.map((e) => e.eatenAt).reduce((a, b) => a.isBefore(b) ? a : b);

DateTime _defaultToLocal(DateTime dt) => dt.toLocal();

/// The three standard meals; empty ones are shown, after the logged
/// timeline, as fixed cards in this order (D1 in design.md).
const _standardMeals = ['breakfast', 'lunch', 'dinner'];

/// Whether [meal] is one of the three standard meals; anything else is a
/// snack group (D1 in design.md).
bool _isStandardMeal(String meal) => _standardMeals.contains(meal);

/// Tie-break rank for the interleaved timeline sort (D1 in design.md):
/// breakfast < lunch < dinner < any snack group, used only when two groups
/// share the exact same earliest-eaten-at time.
int _standardMealRank(String meal) {
  final index = _standardMeals.indexOf(meal);
  return index == -1 ? _standardMeals.length : index;
}

/// Sorts meal groups (standard + snack alike) by earliest eaten-at time
/// ascending, so a snack logged between two meals is interleaved between
/// them (D1 in design.md). Ties (identical eaten-at) break deterministically
/// by [_standardMealRank] then by name, so tests can assert an exact order.
int _compareGroupsByEatenAt(MealGroup a, MealGroup b) {
  final timeCompare = _earliestEatenAt(
    a.entries,
  ).compareTo(_earliestEatenAt(b.entries));
  if (timeCompare != 0) return timeCompare;
  final rankCompare = _standardMealRank(a.meal).compareTo(_standardMealRank(b.meal));
  if (rankCompare != 0) return rankCompare;
  return a.meal.compareTo(b.meal);
}

/// Today section: the day's diet log grouped by meal in eaten order, and
/// per-category portion progress against the day's target.
class TodayScreen extends StatefulWidget {
  final TodayController controller;
  final SignOut signOut;

  /// Called when the user taps a meal card's add control, naming the meal
  /// (a standard meal code, e.g. `'lunch'`) to log into. The shell wires
  /// this to seed the logging session and switch to the Dictionary tab.
  final void Function(String meal)? onAddToMeal;

  /// Called when the user taps the snack area's add control, to start a
  /// new snack-logging session. The shell wires this to seed the next
  /// snack name and switch to the Dictionary tab.
  final VoidCallback? onAddSnack;

  /// Called when the user taps a snack group card's own "add to this
  /// snack" control, naming that group's exact snack name so the shell can
  /// seed the logging session to continue it (not start a new group),
  /// distinct from [onAddSnack] (D2 in design.md).
  final void Function(String snackName)? onAddToSnackGroup;

  /// Called when the user taps a logged entry, so the shell can open the
  /// edit-entry sheet prefilled with it. Entries are not tappable when not
  /// provided.
  final void Function(FoodEntry entry)? onEditEntry;

  /// Converts a meal group's (UTC) earliest `eatenAt` to local time before
  /// formatting as `HH:mm`. Defaults to `DateTime.toLocal`; injectable so
  /// tests can verify the conversion deterministically regardless of the
  /// host machine's timezone.
  final DateTime Function(DateTime) toLocalTime;

  const TodayScreen({
    super.key,
    required this.controller,
    required this.signOut,
    this.onAddToMeal,
    this.onAddSnack,
    this.onAddToSnackGroup,
    this.onEditEntry,
    this.toLocalTime = _defaultToLocal,
  });

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(child: _buildBody(context, controller, loc, theme)),
    );
  }

  Widget _buildBody(
    BuildContext context,
    TodayController controller,
    AppLocalizations loc,
    ThemeData theme,
  ) {
    switch (controller.status) {
      case TodayStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case TodayStatus.error:
        final message = controller.error == TodayError.fetchFailed
            ? loc.errorDietLoadFailed
            : loc.errorSomethingWentWrong;
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                key: const Key('today-error-message'),
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('today-sign-out-button'),
                onPressed: widget.signOut.call,
                child: Text(loc.signOut),
              ),
            ],
          ),
        );
      case TodayStatus.needsReauth:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loc.pleaseSignInAgain, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('today-sign-in-again-button'),
                onPressed: widget.signOut.call,
                child: Text(loc.signInAgain),
              ),
            ],
          ),
        );
      case TodayStatus.loaded:
        final dayLog = controller.dayLog!;
        final target = controller.target!;
        final dietColors = theme.extension<DietCategoryColors>();
        // The interleaved timeline (D1 in design.md): every group that has
        // entries — standard meals and snacks alike — sorted together by
        // earliest eaten-at, so a snack logged between two meals renders
        // between their cards. Groups with no entries can't be timestamped
        // (there's no eaten-at to sort by), so the three standard meals with
        // no logged group are rendered afterward instead, in fixed
        // breakfast->lunch->dinner order.
        final loggedGroups = dayLog.meals.where((m) => m.entries.isNotEmpty).toList()
          ..sort(_compareGroupsByEatenAt);
        final loggedStandardMeals = loggedGroups
            .where((m) => _isStandardMeal(m.meal))
            .map((m) => m.meal)
            .toSet();
        final emptyStandardMeals = _standardMeals
            .where((meal) => !loggedStandardMeals.contains(meal))
            .toList();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            CategoryProgressBar(
              label: loc.dietCategoryStaple,
              logged: target.logged.staple,
              effective: target.effective.staple,
              color: dietColors?.staple,
            ),
            const SizedBox(height: 12),
            CategoryProgressBar(
              label: loc.dietCategoryMeat,
              logged: target.logged.meat,
              effective: target.effective.meat,
              color: dietColors?.meat,
            ),
            const SizedBox(height: 12),
            CategoryProgressBar(
              label: loc.dietCategoryFruit,
              logged: target.logged.fruit,
              effective: target.effective.fruit,
              color: dietColors?.fruit,
            ),
            const SizedBox(height: 12),
            CategoryProgressBar(
              label: loc.dietCategoryVeg,
              logged: target.logged.veg,
              effective: target.effective.veg,
              color: dietColors?.veg,
            ),
            const SizedBox(height: 20),
            for (final group in loggedGroups) ...[
              _MealCard(
                mealName: group.meal,
                group: group,
                loc: loc,
                theme: theme,
                toLocalTime: widget.toLocalTime,
                onEditEntry: widget.onEditEntry,
                isSnackGroup: !_isStandardMeal(group.meal),
                onAdd: _isStandardMeal(group.meal)
                    ? (widget.onAddToMeal == null
                          ? null
                          : () => widget.onAddToMeal!(group.meal))
                    : (widget.onAddToSnackGroup == null
                          ? null
                          : () => widget.onAddToSnackGroup!(group.meal)),
              ),
              const SizedBox(height: 16),
            ],
            for (final meal in emptyStandardMeals) ...[
              _MealCard(
                mealName: meal,
                group: null,
                loc: loc,
                theme: theme,
                toLocalTime: widget.toLocalTime,
                onEditEntry: widget.onEditEntry,
                onAdd: widget.onAddToMeal == null
                    ? null
                    : () => widget.onAddToMeal!(meal),
              ),
              const SizedBox(height: 16),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: Semantics(
                label: loc.dietAddToMealA11yLabel(loc.dietSnackBaseName),
                button: true,
                container: true,
                excludeSemantics: true,
                onTap: widget.onAddSnack,
                child: TextButton.icon(
                  key: const Key('add-snack'),
                  onPressed: widget.onAddSnack,
                  icon: const Icon(Icons.add),
                  label: Text(loc.dietAddSnackButton),
                ),
              ),
            ),
          ],
        );
    }
  }
}

/// Renders one meal card in both states (D1 in design.md): with entries —
/// today's original look, emoji + earliest eaten-at time + editable rows +
/// pills — or empty — emoji + name + a "not logged yet" line. [group] is
/// `null` for an empty standard meal; the earliest-eaten-at time is only
/// ever computed when [group] has entries, so an empty group never reaches
/// `_earliestEatenAt` (which would otherwise crash on `reduce` over an
/// empty list).
class _MealCard extends StatelessWidget {
  final String mealName;
  final MealGroup? group;
  final AppLocalizations loc;
  final ThemeData theme;
  final DateTime Function(DateTime) toLocalTime;
  final void Function(FoodEntry entry)? onEditEntry;
  final VoidCallback? onAdd;

  /// Whether this card renders a snack group rather than a standard meal
  /// (D2 in design.md): only changes the add control's key
  /// (`add-to-snack-<name>` instead of `add-to-meal-<name>`), so the shell's
  /// snack-group "continue this snack" control is distinguishable from a
  /// standard meal card's add control.
  final bool isSnackGroup;

  const _MealCard({
    required this.mealName,
    required this.group,
    required this.loc,
    required this.theme,
    required this.toLocalTime,
    required this.onEditEntry,
    required this.onAdd,
    this.isSnackGroup = false,
  });

  @override
  Widget build(BuildContext context) {
    final entries = group?.entries ?? const <FoodEntry>[];
    final hasEntries = entries.isNotEmpty;
    final time = hasEntries
        ? DateFormat(
            'HH:mm',
          ).format(toLocalTime(_earliestEatenAt(entries)))
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline, width: 2),
        boxShadow: ledgeShadow(theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(_mealEmoji(mealName), style: theme.textTheme.titleLarge),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _mealLabel(loc, mealName),
                  style: theme.textTheme.titleLarge,
                ),
              ),
              if (time != null) Text(time, style: theme.textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 8),
          if (hasEntries)
            for (final entry in entries)
              ListTile(
                title: Text(
                  entry.name?.isNotEmpty == true
                      ? entry.name!
                      : loc.dietManualEntryFallbackName,
                ),
                trailing: PortionPills(
                  staple: entry.staple,
                  meat: entry.meat,
                  fruit: entry.fruit,
                  veg: entry.veg,
                ),
                onTap: onEditEntry == null ? null : () => onEditEntry!(entry),
              )
          else
            Text(
              loc.dietMealEmptyLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (onAdd != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Semantics(
                label: loc.dietAddToMealA11yLabel(_mealLabel(loc, mealName)),
                button: true,
                container: true,
                excludeSemantics: true,
                onTap: onAdd,
                child: TextButton.icon(
                  key: Key(
                    isSnackGroup
                        ? 'add-to-snack-$mealName'
                        : 'add-to-meal-$mealName',
                  ),
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: Text(loc.dietAddToMeal),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
