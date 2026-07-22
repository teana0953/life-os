import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../domain/weight_goal.dart';
import 'weight_goal_controller.dart';

/// Formats a weight/BMI figure: whole numbers show without a decimal (51.0 →
/// "51"), otherwise one decimal place (19.1 → "19.1"). `null` shows nothing —
/// the caller substitutes the "—" placeholder.
String? _fmt(double? value) {
  if (value == null) return null;
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

/// The dashboard's goal card: driven by [WeightGoalController]. When a profile
/// is set it shows target / current / remaining weight, an achievement ring,
/// and BMI; when neither height nor target has been set it shows a "set your
/// goal" prompt. Tapping the card (or the prompt's button) opens the edit
/// bottom sheet. Loading and error states render inside the card; `needsReauth`
/// is left to the [DashboardScreen] layer. Colors come from [Theme] only.
class GoalCard extends StatefulWidget {
  final WeightGoalController controller;
  final String idToken;

  const GoalCard({super.key, required this.controller, required this.idToken});

  @override
  State<GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<GoalCard> {
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

  Future<void> _openEditSheet() async {
    final profile = widget.controller.profile;
    final result = await showModalBottomSheet<_GoalEdit>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _GoalEditSheet(
        initialHeightCm: profile?.heightCm,
        initialTargetWeightKg: profile?.targetWeightKg,
      ),
    );
    if (result == null) return;
    await widget.controller.saveProfile(
      widget.idToken,
      heightCm: result.heightCm,
      targetWeightKg: result.targetWeightKg,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final loc = AppLocalizations.of(context)!;
    final goal = controller.goal;
    final saving = controller.status == WeightGoalStatus.saving;

    // The first fetch — or a save with no already-set card to keep — gets a
    // card-sized spinner. A save of an already-set goal keeps its card content
    // (below) with a lightweight inline indicator instead, so the card doesn't
    // collapse to a spinner and regrow.
    if (controller.status == WeightGoalStatus.loading ||
        (saving && (goal == null || !goal.isProfileSet))) {
      return const LedgeCard(
        padding: EdgeInsets.all(24),
        child: Center(
          child: SizedBox(
            height: 48,
            width: 48,
            child: CircularProgressIndicator(key: Key('goal-card-loading')),
          ),
        ),
      );
    }

    // A load/reload failure → an error message inside the card. This must not
    // hinge on `goal == null`: a reload that fails after a successful first
    // load would otherwise silently keep showing the stale card.
    if (controller.status == WeightGoalStatus.error) {
      final theme = Theme.of(context);
      return LedgeCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              loc.errorWeightGoalLoadFailed,
              key: const Key('goal-card-error'),
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('goal-card-retry'),
              onPressed: () => controller.load(widget.idToken),
              child: Text(loc.retry),
            ),
          ],
        ),
      );
    }

    if (goal == null || !goal.isProfileSet) {
      return _UnsetGoalCard(onSetGoal: _openEditSheet);
    }
    return _SetGoalCard(goal: goal, onEdit: _openEditSheet, saving: saving);
  }
}

/// The goal card when a profile is set: an achievement ring, the target /
/// current / remaining weight figures, and BMI. Tapping anywhere opens the edit
/// sheet. While [saving] a partial update, the card keeps its content and shows
/// a thin inline progress bar at the top rather than collapsing to a spinner.
class _SetGoalCard extends StatelessWidget {
  final WeightGoal goal;
  final VoidCallback onEdit;
  final bool saving;

  const _SetGoalCard({
    required this.goal,
    required this.onEdit,
    this.saving = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    return LedgeCard(
      child: InkWell(
        key: const Key('goal-card'),
        borderRadius: BorderRadius.circular(20),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (saving)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(
                    key: Key('goal-card-saving'),
                    minHeight: 2,
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      loc.goalCardTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  // A hint that tapping the card opens the edit sheet.
                  Icon(
                    Icons.edit,
                    key: const Key('goal-card-edit-icon'),
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _AchievementRing(
                    rate: goal.achievementRate,
                    label: loc.goalAchievementLabel,
                    noDataLabel: loc.goalNoData,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _GoalStat(
                          label: loc.goalTargetLabel,
                          value: _fmt(goal.targetWeightKg),
                        ),
                        const SizedBox(height: 6),
                        _GoalStat(
                          label: loc.goalCurrentLabel,
                          value: _fmt(goal.currentWeightKg),
                        ),
                        const SizedBox(height: 6),
                        _GoalStat(
                          label: loc.goalRemainingLabel,
                          value: _fmt(goal.remainingKg),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    '${loc.goalBmiLabel}  ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    _fmt(goal.bmi) ?? loc.goalPlaceholder,
                    key: const Key('goal-bmi'),
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One target/current/remaining stat row: a label and its value (with the kg
/// unit), or the "—" placeholder when the value is null.
class _GoalStat extends StatelessWidget {
  final String label;
  final String? value;

  const _GoalStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (value == null)
          Text(loc.goalPlaceholder, style: theme.textTheme.titleMedium)
        else ...[
          Text(value!, style: theme.textTheme.titleMedium),
          Text(' ${loc.goalKgUnit}', style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

/// The achievement ring: a determinate circular progress at the achievement
/// rate, with a "達成率" [label] beneath so the percentage reads as achievement.
/// A null rate shows an empty ring (value 0) and no percentage — never a false
/// number. Exposes a single Semantics node (the label followed by the rate
/// percentage, or a spoken "no data" phrase when null — not the visual "—"
/// glyph, which reads as meaningless punctuation) for screen readers.
class _AchievementRing extends StatelessWidget {
  final int? rate;
  final String label;
  final String noDataLabel;

  const _AchievementRing({
    required this.rate,
    required this.label,
    required this.noDataLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = rate == null ? 0.0 : (rate! / 100).clamp(0.0, 1.0);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '$label ${rate == null ? noDataLabel : '$rate%'}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    key: const Key('goal-ring'),
                    value: value,
                    strokeWidth: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                if (rate != null)
                  Text(
                    '$rate%',
                    key: const Key('goal-achievement'),
                    style: theme.textTheme.titleMedium,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            key: const Key('goal-achievement-label'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The goal card when neither height nor target weight has been set: a prompt
/// and a button that opens the edit sheet (rather than a wall of "—").
class _UnsetGoalCard extends StatelessWidget {
  final VoidCallback onSetGoal;

  const _UnsetGoalCard({required this.onSetGoal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    return LedgeCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(loc.goalCardTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(
            loc.goalUnsetPrompt,
            key: const Key('goal-unset-prompt'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('goal-set-button'),
            onPressed: onSetGoal,
            child: Text(loc.goalSetButton),
          ),
        ],
      ),
    );
  }
}

/// The edit sheet's result: the entered (positive) height and/or target weight.
/// A field left empty is `null` (an untouched field → a partial update).
class _GoalEdit {
  final double? heightCm;
  final double? targetWeightKg;

  const _GoalEdit({this.heightCm, this.targetWeightKg});
}

/// The goal edit sheet: height (cm) and target-weight (kg) number fields
/// (empty-zero convention, pre-filled from the current profile). A modal bottom
/// sheet — not an AlertDialog — with a `viewInsets` bottom padding, so the
/// on-screen keyboard doesn't hide the fields on mobile (the exercise #54
/// lesson). Save is disabled while any entered value is non-positive, or while
/// both fields are empty.
class _GoalEditSheet extends StatefulWidget {
  final double? initialHeightCm;
  final double? initialTargetWeightKg;

  const _GoalEditSheet({this.initialHeightCm, this.initialTargetWeightKg});

  @override
  State<_GoalEditSheet> createState() => _GoalEditSheetState();
}

class _GoalEditSheetState extends State<_GoalEditSheet> {
  late final TextEditingController _heightController = TextEditingController(
    text: _seed(widget.initialHeightCm),
  );
  late final TextEditingController _targetController = TextEditingController(
    text: _seed(widget.initialTargetWeightKg),
  );

  // Empty-zero convention: null / 0 seeds an empty field (a hintText '0' shows).
  String _seed(double? value) {
    if (value == null || value == 0) return '';
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toString();
  }

  @override
  void initState() {
    super.initState();
    _heightController.addListener(_onChanged);
    _targetController.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _heightController.removeListener(_onChanged);
    _targetController.removeListener(_onChanged);
    _heightController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  /// Parses [text] into (valid, value): an empty field is valid with a null
  /// value (untouched); a positive number is valid with that value; anything
  /// else (non-numeric, zero, negative) is invalid.
  (bool, double?) _parse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return (true, null);
    final value = double.tryParse(trimmed);
    if (value == null || value <= 0) return (false, null);
    return (true, value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    final (heightValid, heightValue) = _parse(_heightController.text);
    final (targetValid, targetValue) = _parse(_targetController.text);
    final canSave =
        heightValid &&
        targetValid &&
        (heightValue != null || targetValue != null);

    return Padding(
      // Lift the sheet above the on-screen keyboard so the fields stay visible.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(loc.goalEditTitle, style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                key: const Key('goal-height-field'),
                controller: _heightController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: loc.goalHeightLabel,
                  hintText: '0',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('goal-target-field'),
                controller: _targetController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: loc.goalTargetWeightLabel,
                  hintText: '0',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('goal-save-button'),
                onPressed: canSave
                    ? () => Navigator.of(context).pop(
                        _GoalEdit(
                          heightCm: heightValue,
                          targetWeightKg: targetValue,
                        ),
                      )
                    : null,
                child: Text(loc.goalSaveButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
