import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../auth/application/sign_out.dart';
import '../domain/meal_entry.dart';
import '../domain/portions.dart';
import 'category_progress_bar.dart';
import 'meal_label.dart';
import 'portion_pills.dart';
import 'today_controller.dart';

DateTime _defaultToLocal(DateTime dt) => dt.toLocal();

/// Sums a meal's item `consumed` portions into the meal card's total pill.
Portions _mealTotal(MealEntry meal) {
  var staple = 0.0, meat = 0.0, fruit = 0.0, veg = 0.0;
  for (final item in meal.items) {
    staple += item.consumed.staple;
    meat += item.consumed.meat;
    fruit += item.consumed.fruit;
    veg += item.consumed.veg;
  }
  return Portions(staple: staple, meat: meat, fruit: fruit, veg: veg);
}

/// Sorts meals (standard + snack alike) by `time` ascending, so a snack
/// eaten between two meals is interleaved between their cards. Ties break
/// deterministically by [standardMealRank] then by name, so tests can
/// assert an exact order.
int _compareMealsByTime(MealEntry a, MealEntry b) {
  final timeCompare = a.time.compareTo(b.time);
  if (timeCompare != 0) return timeCompare;
  final rankCompare = standardMealRank(a.meal).compareTo(standardMealRank(b.meal));
  if (rankCompare != 0) return rankCompare;
  return a.meal.compareTo(b.meal);
}

/// Today section: reads the day's meals from the meals API and shows a
/// per-category progress summary plus a single eaten-at timeline of every
/// meal and snack. Items are read-only this PR (no in-place edit/delete —
/// PR③).
class TodayScreen extends StatefulWidget {
  final TodayController controller;
  final SignOut signOut;

  /// Called when the user taps a standard meal card's add control, naming
  /// the meal (e.g. `'lunch'`) to search/add into.
  final void Function(String meal)? onAddToMeal;

  /// Called when the user taps the bottom "＋ new snack" control, to start a
  /// new snack session (seeded by the shell to the next snack name).
  final VoidCallback? onAddSnack;

  /// Called when the user taps a snack card's own add control, naming that
  /// snack's exact name so the shell can continue it (not start a new one),
  /// distinct from [onAddSnack].
  final void Function(String snackName)? onAddToSnackGroup;

  /// Converts a meal's (UTC) `time` to local before formatting as `HH:mm`.
  /// Defaults to [DateTime.toLocal]; injectable so tests can verify the
  /// conversion deterministically regardless of the host machine's
  /// timezone.
  final DateTime Function(DateTime) toLocalTime;

  const TodayScreen({
    super.key,
    required this.controller,
    required this.signOut,
    this.onAddToMeal,
    this.onAddSnack,
    this.onAddToSnackGroup,
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
        final dayMealsLog = controller.dayMealsLog!;
        final target = controller.target!;
        final dietColors = theme.extension<DietCategoryColors>();

        // The interleaved timeline: every meal (standard + snack alike),
        // sorted together by `time`. The standard meals with no meal that
        // day have no `time` to sort by, so they render afterward instead,
        // as empty cards in fixed breakfast->lunch->dinner order.
        final timeline = [...dayMealsLog.meals]..sort(_compareMealsByTime);
        final loggedStandardMeals = timeline
            .where((m) => isStandardMeal(m.meal))
            .map((m) => m.meal)
            .toSet();
        final emptyStandardMeals = standardMeals
            .where((meal) => !loggedStandardMeals.contains(meal))
            .toList();

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            CategoryProgressBar(
              key: const Key('today-progress-staple'),
              label: loc.dietCategoryStaple,
              logged: dayMealsLog.totals.staple,
              effective: target.effective.staple,
              color: dietColors?.staple,
            ),
            const SizedBox(height: 12),
            CategoryProgressBar(
              key: const Key('today-progress-meat'),
              label: loc.dietCategoryMeat,
              logged: dayMealsLog.totals.meat,
              effective: target.effective.meat,
              color: dietColors?.meat,
            ),
            const SizedBox(height: 12),
            CategoryProgressBar(
              key: const Key('today-progress-fruit'),
              label: loc.dietCategoryFruit,
              logged: dayMealsLog.totals.fruit,
              effective: target.effective.fruit,
              color: dietColors?.fruit,
            ),
            const SizedBox(height: 12),
            CategoryProgressBar(
              key: const Key('today-progress-veg'),
              label: loc.dietCategoryVeg,
              logged: dayMealsLog.totals.veg,
              effective: target.effective.veg,
              color: dietColors?.veg,
            ),
            const SizedBox(height: 20),
            for (final meal in timeline) ...[
              _MealCard(
                meal: meal,
                loc: loc,
                theme: theme,
                toLocalTime: widget.toLocalTime,
                isSnack: !isStandardMeal(meal.meal),
                onAdd: isStandardMeal(meal.meal)
                    ? (widget.onAddToMeal == null
                          ? null
                          : () => widget.onAddToMeal!(meal.meal))
                    : (widget.onAddToSnackGroup == null
                          ? null
                          : () => widget.onAddToSnackGroup!(meal.meal)),
              ),
              const SizedBox(height: 16),
            ],
            for (final meal in emptyStandardMeals) ...[
              _MealCard(
                meal: null,
                mealName: meal,
                loc: loc,
                theme: theme,
                toLocalTime: widget.toLocalTime,
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

/// Renders one meal card (a standard meal or a snack), in both states: with
/// a meal — emoji + meal name + time + total pill + read-only item rows —
/// or empty (a standard meal with no meal logged that day yet) — emoji +
/// name + a "not logged yet" line. [meal] is `null` for an empty standard
/// meal, in which case [mealName] names it instead.
class _MealCard extends StatelessWidget {
  final MealEntry? meal;
  final String? mealName;
  final AppLocalizations loc;
  final ThemeData theme;
  final DateTime Function(DateTime) toLocalTime;
  final VoidCallback? onAdd;
  final bool isSnack;

  const _MealCard({
    required this.meal,
    this.mealName,
    required this.loc,
    required this.theme,
    required this.toLocalTime,
    required this.onAdd,
    this.isSnack = false,
  });

  @override
  Widget build(BuildContext context) {
    final meal = this.meal;
    final name = meal?.meal ?? mealName!;
    final time = meal == null
        ? null
        : DateFormat('HH:mm').format(toLocalTime(meal.time));
    final total = meal == null ? null : _mealTotal(meal);

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
              Text(mealEmoji(name), style: theme.textTheme.titleLarge),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mealDisplayLabel(loc, name),
                  style: theme.textTheme.titleLarge,
                ),
              ),
              if (time != null) Text(time, style: theme.textTheme.bodyMedium),
              if (onAdd != null)
                Semantics(
                  label: loc.dietAddToMealA11yLabel(mealDisplayLabel(loc, name)),
                  button: true,
                  container: true,
                  excludeSemantics: true,
                  onTap: onAdd,
                  child: IconButton(
                    key: Key(isSnack ? 'add-to-snack-$name' : 'add-to-meal-$name'),
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ),
            ],
          ),
          if (total != null) ...[
            const SizedBox(height: 4),
            Row(
              key: Key('meal-total-$name'),
              children: [
                Text(loc.dietMealTotalLabel, style: theme.textTheme.bodySmall),
                const SizedBox(width: 8),
                Expanded(
                  child: PortionPills(
                    staple: total.staple,
                    meat: total.meat,
                    fruit: total.fruit,
                    veg: total.veg,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          if (meal != null && meal.items.isNotEmpty)
            for (final item in meal.items)
              ListTile(
                title: Text(
                  item.name?.isNotEmpty == true
                      ? item.name!
                      : loc.dietUnnamedItemLabel,
                ),
                trailing: PortionPills(
                  staple: item.consumed.staple,
                  meat: item.consumed.meat,
                  fruit: item.consumed.fruit,
                  veg: item.consumed.veg,
                ),
              )
          else if (meal == null)
            Text(
              loc.dietMealEmptyLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
