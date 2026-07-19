import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../auth/application/sign_out.dart';
import '../domain/day_diet_log.dart';
import '../domain/food_entry.dart';
import 'category_progress_bar.dart';
import 'portion_pills.dart';
import 'today_controller.dart';

/// Maps a raw meal value to its localized label; falls back to the raw
/// value itself for custom snack labels.
String _mealLabel(AppLocalizations loc, String meal) {
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

/// Today section: the day's diet log grouped by meal in eaten order, and
/// per-category portion progress against the day's target.
class TodayScreen extends StatefulWidget {
  final TodayController controller;
  final SignOut signOut;

  /// Called when the user wants to log a new entry (e.g. from the FAB).
  /// The shell wires this to open the dictionary/quantity-card flow; the
  /// FAB is hidden when not provided.
  final VoidCallback? onAddEntry;

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
    this.onAddEntry,
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
      floatingActionButton: controller.status == TodayStatus.loaded &&
              widget.onAddEntry != null
          ? FloatingActionButton(
              key: const Key('today-add-entry-fab'),
              onPressed: widget.onAddEntry,
              child: const Icon(Icons.add),
            )
          : null,
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
            if (dayLog.meals.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  loc.dietDayEmpty,
                  key: const Key('today-empty-state'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final meal in dayLog.meals) ...[
                _MealCard(
                  meal: meal,
                  loc: loc,
                  theme: theme,
                  toLocalTime: widget.toLocalTime,
                  onEditEntry: widget.onEditEntry,
                ),
                const SizedBox(height: 16),
              ],
          ],
        );
    }
  }
}

class _MealCard extends StatelessWidget {
  final MealGroup meal;
  final AppLocalizations loc;
  final ThemeData theme;
  final DateTime Function(DateTime) toLocalTime;
  final void Function(FoodEntry entry)? onEditEntry;

  const _MealCard({
    required this.meal,
    required this.loc,
    required this.theme,
    required this.toLocalTime,
    required this.onEditEntry,
  });

  @override
  Widget build(BuildContext context) {
    final time = DateFormat(
      'HH:mm',
    ).format(toLocalTime(_earliestEatenAt(meal.entries)));

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
              Text(_mealEmoji(meal.meal), style: theme.textTheme.titleLarge),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _mealLabel(loc, meal.meal),
                  style: theme.textTheme.titleLarge,
                ),
              ),
              Text(time, style: theme.textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 8),
          for (final entry in meal.entries)
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
            ),
        ],
      ),
    );
  }
}
