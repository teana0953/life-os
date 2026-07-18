import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import 'daily_target_controller.dart';
import 'portion_stepper.dart';

/// Target section: edit the day's per-category base portion targets and
/// view the remaining portions against what has been logged.
class DailyTargetScreen extends StatefulWidget {
  final DailyTargetController controller;
  final String idToken;
  final String day;

  /// Called after the target is saved successfully, so a caller can refresh
  /// views that depend on the target (e.g. reload Today's portion progress).
  final VoidCallback? onSaved;

  const DailyTargetScreen({
    super.key,
    required this.controller,
    required this.idToken,
    required this.day,
    this.onSaved,
  });

  @override
  State<DailyTargetScreen> createState() => _DailyTargetScreenState();
}

class _DailyTargetScreenState extends State<DailyTargetScreen> {
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

    if (controller.status == DailyTargetStatus.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (controller.status == DailyTargetStatus.needsReauth) {
      return Scaffold(
        body: Center(
          child: Text(loc.pleaseSignInAgain, textAlign: TextAlign.center),
        ),
      );
    }
    if (controller.target == null) {
      return Scaffold(
        body: Center(
          child: Text(loc.errorDietLoadFailed, textAlign: TextAlign.center),
        ),
      );
    }

    final target = controller.target!;
    final dietColors = theme.extension<DietCategoryColors>();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(loc.dietSetTargetTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            PortionStepper(
              label: loc.dietCategoryStaple,
              value: controller.draftBaseStaple,
              onChanged: controller.setDraftBaseStaple,
              color: dietColors?.staple,
              decrementKey: const Key('daily-target-staple-decrement'),
              incrementKey: const Key('daily-target-staple-increment'),
            ),
            const SizedBox(height: 12),
            PortionStepper(
              label: loc.dietCategoryMeat,
              value: controller.draftBaseMeat,
              onChanged: controller.setDraftBaseMeat,
              color: dietColors?.meat,
              decrementKey: const Key('daily-target-meat-decrement'),
              incrementKey: const Key('daily-target-meat-increment'),
            ),
            const SizedBox(height: 12),
            PortionStepper(
              label: loc.dietCategoryFruit,
              value: controller.draftBaseFruit,
              onChanged: controller.setDraftBaseFruit,
              color: dietColors?.fruit,
              decrementKey: const Key('daily-target-fruit-decrement'),
              incrementKey: const Key('daily-target-fruit-increment'),
            ),
            const SizedBox(height: 12),
            PortionStepper(
              label: loc.dietCategoryVeg,
              value: controller.draftBaseVeg,
              onChanged: controller.setDraftBaseVeg,
              color: dietColors?.veg,
              decrementKey: const Key('daily-target-veg-decrement'),
              incrementKey: const Key('daily-target-veg-increment'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('save-target-button'),
              onPressed: controller.status == DailyTargetStatus.saving
                  ? null
                  : () async {
                      final saved = await controller.save(
                        widget.idToken,
                        widget.day,
                      );
                      if (saved) widget.onSaved?.call();
                    },
              child: Text(loc.dietSaveTargetButton),
            ),
            const SizedBox(height: 24),
            _RemainingRow(label: loc.dietCategoryStaple, remaining: target.remaining.staple, loc: loc),
            _RemainingRow(label: loc.dietCategoryMeat, remaining: target.remaining.meat, loc: loc),
            _RemainingRow(label: loc.dietCategoryFruit, remaining: target.remaining.fruit, loc: loc),
            _RemainingRow(label: loc.dietCategoryVeg, remaining: target.remaining.veg, loc: loc),
          ],
        ),
      ),
    );
  }
}

class _RemainingRow extends StatelessWidget {
  final String label;
  final double remaining;
  final AppLocalizations loc;

  const _RemainingRow({
    required this.label,
    required this.remaining,
    required this.loc,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(loc.dietRemainingOfCategory(remaining)),
        ],
      ),
    );
  }
}
