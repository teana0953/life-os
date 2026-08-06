import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/pick_time_24h.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/numeric_amount_field.dart';
import '../../auth/application/sign_out.dart';
import '../domain/meal_entry.dart';
import '../domain/portions.dart';
import 'amount_stepper.dart';
import 'category_progress_bar.dart';
import 'meal_label.dart';
import 'portion_pills.dart';
import 'today_controller.dart';
import '../../../shared/auth/id_token_provider.dart';
import '../../../shared/widgets/empty_state.dart';

DateTime _defaultToLocal(DateTime dt) => dt.toLocal();

String _formatAmount(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

/// The consumed-amount label shown on a dictionary item row (e.g. "1 碗" /
/// "80 公克"): when the item has a base measure, its quantity converted to
/// that measure; otherwise the quantity with its dictionary unit word.
String _consumedAmountLabel(MealItem item, AppLocalizations loc) {
  final baseAmount = item.baseAmount;
  // Guard on a non-empty measure unit (not just non-null) so an empty-string
  // unit falls back to 份 instead of rendering a blank unit ("9 "). Matches
  // measureLabelFor, which also treats '' as no unit.
  if (baseAmount != null && item.measureUnit?.isNotEmpty == true) {
    final measure = item.quantity * baseAmount;
    final label = measureLabelFor(item.measureUnit, loc) ?? '';
    return '${_formatAmount(measure)} $label';
  }
  return '${_formatAmount(item.quantity)} ${loc.dietPortionUnit}';
}

/// Combines a meal's current time (via [toLocalTime]) with a freshly-picked
/// [TimeOfDay] into the UTC [DateTime] to send — the default
/// [TodayScreen.pickMealTime]. Overridden in tests to bypass the real time
/// picker (and its device-timezone-dependent conversion) entirely.
Future<DateTime?> _defaultPickMealTime(
  BuildContext context,
  DateTime currentTime,
  DateTime Function(DateTime) toLocalTime,
) async {
  final local = toLocalTime(currentTime);
  final picked = await pickTime24h(
    context,
    initialTime: TimeOfDay(hour: local.hour, minute: local.minute),
  );
  if (picked == null) return null;
  final combined = DateTime(local.year, local.month, local.day, picked.hour, picked.minute);
  return combined.toUtc();
}

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
/// meal and snack. Items are editable in place: tapping one reveals an
/// inline amount control; each item and each meal can be deleted; a meal's
/// time can be changed.
class TodayScreen extends StatefulWidget {
  final TodayController controller;
  final SignOut signOut;

  /// The current user's ID token and the viewed day, needed to call the
  /// controller's mutation methods (edit/delete item, change meal time,
  /// delete meal).
  final IdTokenProvider idToken;
  final String day;

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

  /// Picks a new time for a meal, returning the UTC [DateTime] to send (or
  /// `null` if the user cancels). Defaults to a real [pickTime24h] combined
  /// with [toLocalTime]; tests inject a fake that returns a fixed time
  /// directly, bypassing the real picker UI and any device-timezone
  /// dependence.
  final Future<DateTime?> Function(
    BuildContext context,
    DateTime currentTime,
    DateTime Function(DateTime) toLocalTime,
  )
  pickMealTime;

  const TodayScreen({
    super.key,
    required this.controller,
    required this.signOut,
    required this.idToken,
    required this.day,
    this.onAddToMeal,
    this.onAddSnack,
    this.onAddToSnackGroup,
    this.toLocalTime = _defaultToLocal,
    this.pickMealTime = _defaultPickMealTime,
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

  Future<void> _changeMealTime(MealEntry meal) async {
    final newTime = await widget.pickMealTime(context, meal.time, widget.toLocalTime);
    if (newTime == null) return;
    await widget.controller.changeMealTime(await widget.idToken(), widget.day, meal.id, newTime);
  }

  Future<void> _confirmDeleteMeal(MealEntry meal, AppLocalizations loc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc.dietDeleteMealConfirmTitle),
        content: Text(loc.dietDeleteMealConfirmMessage),
        actions: [
          TextButton(
            key: const Key('delete-meal-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          TextButton(
            key: const Key('delete-meal-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: Text(loc.dietDeleteMealConfirmButton),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.controller.deleteMeal(await widget.idToken(), widget.day, meal.id);
    }
  }

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
        final message = switch (controller.error) {
          TodayError.fetchFailed => loc.errorDietLoadFailed,
          TodayError.notFound => loc.errorDietItemNotFound,
          _ => loc.errorSomethingWentWrong,
        };
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
                controller: controller,
                idToken: widget.idToken,
                day: widget.day,
                onChangeTime: () => _changeMealTime(meal),
                onDeleteMeal: () => _confirmDeleteMeal(meal, loc),
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
                controller: controller,
                idToken: widget.idToken,
                day: widget.day,
                onChangeTime: null,
                onDeleteMeal: null,
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
/// a meal — emoji + meal name + time + change-time/delete-meal controls +
/// total pill + editable item rows — or empty (a standard meal with no meal
/// logged that day yet) — emoji + name + a "not logged yet" line. [meal] is
/// `null` for an empty standard meal, in which case [mealName] names it
/// instead.
class _MealCard extends StatelessWidget {
  final MealEntry? meal;
  final String? mealName;
  final AppLocalizations loc;
  final ThemeData theme;
  final DateTime Function(DateTime) toLocalTime;
  final VoidCallback? onAdd;
  final bool isSnack;
  final TodayController controller;
  final IdTokenProvider idToken;
  final String day;
  final VoidCallback? onChangeTime;
  final VoidCallback? onDeleteMeal;

  const _MealCard({
    required this.meal,
    this.mealName,
    required this.loc,
    required this.theme,
    required this.toLocalTime,
    required this.onAdd,
    this.isSnack = false,
    required this.controller,
    required this.idToken,
    required this.day,
    required this.onChangeTime,
    required this.onDeleteMeal,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // The time itself is the change-time affordance (tapping it
              // opens the time picker) — no separate clock icon button, to
              // save width and keep the tap target directly tied to what it
              // changes.
              if (meal != null && onChangeTime != null && time != null)
                Tooltip(
                  message: loc.dietChangeTimeTooltip,
                  child: InkWell(
                    key: Key('change-meal-time-${meal.id}'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: onChangeTime,
                    // 48dp min tap target (was ~32dp) + a leading clock glyph
                    // so it reads as an editable control, not plain text.
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(time, style: theme.textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (meal != null && onDeleteMeal != null)
                IconButton(
                  key: Key('delete-meal-${meal.id}'),
                  tooltip: loc.dietDeleteMealTooltip,
                  onPressed: onDeleteMeal,
                  icon: const Icon(Icons.delete_outline),
                ),
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
              _EditableItemRow(
                key: ValueKey(item.id),
                item: item,
                loc: loc,
                controller: controller,
                idToken: idToken,
                day: day,
              )
          else if (meal == null)
            // Tier 2: one meal card's item list is empty while the rest of
            // the day is on screen. No key: located by its text (the only
            // converted site without one).
            EmptyStateNote(text: loc.dietMealEmptyLabel),
        ],
      ),
    );
  }
}

/// One meal item row: tapping it toggles an inline editor beneath it (an
/// [AmountStepper] for a dictionary item, or four portion fields for a
/// manual item), seeded with the item's current amount, plus a delete
/// control. Local state only holds the in-progress edit; the controller
/// stays the source of truth (a save reloads the day from the backend).
class _EditableItemRow extends StatefulWidget {
  final MealItem item;
  final AppLocalizations loc;
  final TodayController controller;
  final IdTokenProvider idToken;
  final String day;

  const _EditableItemRow({
    super.key,
    required this.item,
    required this.loc,
    required this.controller,
    required this.idToken,
    required this.day,
  });

  @override
  State<_EditableItemRow> createState() => _EditableItemRowState();
}

class _EditableItemRowState extends State<_EditableItemRow> {
  bool _expanded = false;
  late double _amount = widget.item.quantity;
  bool _measureMode = false;

  late final _staple = TextEditingController(text: _portionFieldText(widget.item.staple));
  late final _meat = TextEditingController(text: _portionFieldText(widget.item.meat));
  late final _fruit = TextEditingController(text: _portionFieldText(widget.item.fruit));
  late final _veg = TextEditingController(text: _portionFieldText(widget.item.veg));

  static String _portionFieldText(double value) => value == 0 ? '' : _formatAmount(value);

  double _parsePortion(TextEditingController controller) =>
      double.tryParse(controller.text) ?? 0;

  @override
  void dispose() {
    _staple.dispose();
    _meat.dispose();
    _fruit.dispose();
    _veg.dispose();
    super.dispose();
  }

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

  void _onMeasureModeChanged(bool measureMode) {
    setState(() {
      _measureMode = measureMode;
      // A fresh amount in the new mode — the original entry mode isn't
      // recoverable from the stored item (D3 in design.md). Measure mode
      // seeds the item's baseAmount (so it starts at ~1 unit's worth rather
      // than a near-zero measure that would be sent as `measure: 0` and
      // rejected by the backend), mirroring CreateMealController.toggleMeasure.
      _amount = measureMode ? (widget.item.baseAmount ?? widget.item.quantity) : widget.item.quantity;
    });
  }

  /// Whether the current amount can be saved: manual items always can (their
  /// four portion fields default to 0 legitimately); a dictionary item's
  /// quantity/measure must be > 0 — the backend rejects `quantity: 0` /
  /// `measure: 0`.
  bool get _canSave => widget.item.isManual || _amount > 0;

  Future<void> _save() async {
    final item = widget.item;
    if (item.isManual) {
      await widget.controller.editItem(
        await widget.idToken(),
        widget.day,
        item.id,
        portions: Portions(
          staple: _parsePortion(_staple),
          meat: _parsePortion(_meat),
          fruit: _parsePortion(_fruit),
          veg: _parsePortion(_veg),
        ),
      );
    } else if (!_canSave) {
      return;
    } else if (_measureMode) {
      await widget.controller.editItem(await widget.idToken(), widget.day, item.id, measure: _amount);
    } else {
      await widget.controller.editItem(await widget.idToken(), widget.day, item.id, quantity: _amount);
    }
    if (mounted) setState(() => _expanded = false);
  }

  Future<void> _delete() async {
    return widget.controller.deleteItem(await widget.idToken(), widget.day, widget.item.id);
  }

  Widget _portionField(Key key, TextEditingController controller, String label) {
    return NumericAmountField(fieldKey: key, controller: controller, label: label);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final loc = widget.loc;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Collapsed row: name + consumed amount + a chevron on the top line,
        // and the portion pills on their own full-width line below. Tapping
        // the whole thing expands the editor. The pills MUST NOT share the
        // top row's width: squeezed into a narrow Flexible slot, a single
        // pill gets compressed below its intrinsic width and its label wraps,
        // rounding the pill into a blob (the reported overflow). Giving the
        // pills a full line lets their Wrap lay them out at natural size.
        InkWell(
          key: Key('meal-item-${item.id}'),
          onTap: _toggleExpanded,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        item.name?.isNotEmpty == true ? item.name! : loc.dietUnnamedItemLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!item.isManual) ...[
                      const SizedBox(width: 8),
                      Text(
                        _consumedAmountLabel(item, loc),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    // Chevron affordance so the row reads as tap-to-expand
                    // (it went from read-only to interactive; without a hint
                    // it looks static). Flips up while the editor is open.
                    const SizedBox(width: 4),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                if (item.consumed.staple != 0 ||
                    item.consumed.meat != 0 ||
                    item.consumed.fruit != 0 ||
                    item.consumed.veg != 0) ...[
                  const SizedBox(height: 6),
                  PortionPills(
                    staple: item.consumed.staple,
                    meat: item.consumed.meat,
                    fruit: item.consumed.fruit,
                    veg: item.consumed.veg,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            key: Key('item-editor-${item.id}'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (item.isManual)
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _portionField(Key('edit-staple-${item.id}'), _staple, loc.dietCategoryStaple),
                      _portionField(Key('edit-meat-${item.id}'), _meat, loc.dietCategoryMeat),
                      _portionField(Key('edit-fruit-${item.id}'), _fruit, loc.dietCategoryFruit),
                      _portionField(Key('edit-veg-${item.id}'), _veg, loc.dietCategoryVeg),
                    ],
                  )
                else
                  AmountStepper(
                    value: _amount,
                    onChanged: (v) => setState(() => _amount = v),
                    unitLabel: loc.dietPortionUnit,
                    allowMeasure: item.baseAmount != null && item.measureUnit?.isNotEmpty == true,
                    measureMode: _measureMode,
                    measureLabel: measureLabelFor(item.measureUnit, loc),
                    onModeChanged: _onMeasureModeChanged,
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      key: Key('delete-item-${item.id}'),
                      tooltip: loc.dietDeleteItemTooltip,
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline),
                    ),
                    const Spacer(),
                    FilledButton(
                      key: Key('save-item-${item.id}'),
                      onPressed: _canSave ? _save : null,
                      child: Text(loc.dietSaveEditButton),
                    ),
                  ],
                ),
              ],
            ),
          ),
        Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ],
    );
  }
}
