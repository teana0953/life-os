import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../auth/application/sign_out.dart';
import '../domain/daily_target.dart';
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

/// Today section: the day's diet log grouped by meal in eaten order, and
/// per-category portion progress against the day's target.
class TodayScreen extends StatefulWidget {
  final TodayController controller;
  final SignOut signOut;

  /// Called when the user wants to log a new entry (e.g. from the FAB).
  /// The shell wires this to open the dictionary/quantity-card flow; the
  /// FAB is hidden when not provided.
  final VoidCallback? onAddEntry;

  const TodayScreen({
    super.key,
    required this.controller,
    required this.signOut,
    this.onAddEntry,
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
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _CategoryProgressRow(loc: loc, theme: theme, target: target),
            const SizedBox(height: 20),
            for (final meal in dayLog.meals) ...[
              Text(_mealLabel(loc, meal.meal), style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final entry in meal.entries)
                ListTile(
                  title: Text(entry.name ?? ''),
                  trailing: Text(entry.staple.toString()),
                ),
              const SizedBox(height: 16),
            ],
          ],
        );
    }
  }
}

class _CategoryProgressRow extends StatelessWidget {
  final AppLocalizations loc;
  final ThemeData theme;
  final DailyTargetWithRemaining target;

  const _CategoryProgressRow({
    required this.loc,
    required this.theme,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    final dietColors = theme.extension<DietCategoryColors>();
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _CategoryProgress(
          label: loc.dietCategoryStaple,
          logged: target.logged.staple,
          effective: target.effective.staple,
          color: dietColors?.staple,
          loc: loc,
          theme: theme,
        ),
        _CategoryProgress(
          label: loc.dietCategoryMeat,
          logged: target.logged.meat,
          effective: target.effective.meat,
          color: dietColors?.meat,
          loc: loc,
          theme: theme,
        ),
        _CategoryProgress(
          label: loc.dietCategoryFruit,
          logged: target.logged.fruit,
          effective: target.effective.fruit,
          color: dietColors?.fruit,
          loc: loc,
          theme: theme,
        ),
        _CategoryProgress(
          label: loc.dietCategoryVeg,
          logged: target.logged.veg,
          effective: target.effective.veg,
          color: dietColors?.veg,
          loc: loc,
          theme: theme,
        ),
      ],
    );
  }
}

class _CategoryProgress extends StatelessWidget {
  final String label;
  final double logged;
  final double effective;
  final Color? color;
  final AppLocalizations loc;
  final ThemeData theme;

  const _CategoryProgress({
    required this.label,
    required this.logged,
    required this.effective,
    required this.color,
    required this.loc,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            loc.dietProgressOfTarget(logged, effective),
            style: theme.textTheme.titleLarge,
          ),
        ],
      ),
    );
  }
}
