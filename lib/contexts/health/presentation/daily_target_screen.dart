import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/async_state_scaffold.dart';
import '../../../shared/widgets/ledge_card.dart';
import 'category_progress_bar.dart';
import 'daily_target_controller.dart';
import 'portion_stepper.dart';
import '../../../shared/auth/id_token_provider.dart';

/// Target section: edit the day's per-category base portion targets and
/// view the remaining portions against what has been logged.
class DailyTargetScreen extends StatefulWidget {
  final DailyTargetController controller;
  final IdTokenProvider idToken;
  final String day;

  /// Called after the target is saved successfully, so a caller can refresh
  /// views that depend on the target (e.g. reload Today's portion progress).
  final VoidCallback? onSaved;

  /// Invoked when the user taps the reauth state's sign-in-again control
  /// (see [AsyncStateScaffold]).
  final VoidCallback onSignInAgain;

  const DailyTargetScreen({
    super.key,
    required this.controller,
    required this.idToken,
    required this.day,
    this.onSaved,
    required this.onSignInAgain,
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

  /// True from the moment a save starts until it settles. Set
  /// **synchronously**, before the `await widget.idToken()`: the controller
  /// only flips to `saving` once the token has resolved, so without this flag
  /// the Save button stays enabled and silent for the whole token round trip
  /// and a second tap starts a second write.
  bool _saving = false;

  /// Saves the draft target and, on success, tells the caller. Re-entrant
  /// calls (a second tap while one is in flight) are dropped.
  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final saved = await widget.controller.save(
        await widget.idToken(),
        widget.day,
      );
      if (saved) widget.onSaved?.call();
    } finally {
      _saving = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AsyncStateScaffold(
      isLoading: controller.status == DailyTargetStatus.loading,
      isReauth: controller.status == DailyTargetStatus.needsReauth,
      reauthMessage: loc.pleaseSignInAgain,
      onSignInAgain: widget.onSignInAgain,
      builder: (context) {
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
                _TargetSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        loc.dietSetTargetTitle,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      PortionStepper(
                        label: loc.dietCategoryStaple,
                        value: controller.draftBaseStaple,
                        onChanged: controller.setDraftBaseStaple,
                        color: dietColors?.staple,
                        leadingIcon: _CategoryIconChip(
                          letter: loc.dietCategoryIconStaple,
                          color: dietColors?.staple,
                        ),
                        decrementKey: const Key(
                          'daily-target-staple-decrement',
                        ),
                        incrementKey: const Key(
                          'daily-target-staple-increment',
                        ),
                        valueKey: const Key('daily-target-staple-value'),
                      ),
                      const SizedBox(height: 12),
                      PortionStepper(
                        label: loc.dietCategoryMeat,
                        value: controller.draftBaseMeat,
                        onChanged: controller.setDraftBaseMeat,
                        color: dietColors?.meat,
                        leadingIcon: _CategoryIconChip(
                          letter: loc.dietCategoryIconMeat,
                          color: dietColors?.meat,
                        ),
                        decrementKey: const Key('daily-target-meat-decrement'),
                        incrementKey: const Key('daily-target-meat-increment'),
                        valueKey: const Key('daily-target-meat-value'),
                      ),
                      const SizedBox(height: 12),
                      PortionStepper(
                        label: loc.dietCategoryFruit,
                        value: controller.draftBaseFruit,
                        onChanged: controller.setDraftBaseFruit,
                        color: dietColors?.fruit,
                        leadingIcon: _CategoryIconChip(
                          letter: loc.dietCategoryIconFruit,
                          color: dietColors?.fruit,
                        ),
                        decrementKey: const Key('daily-target-fruit-decrement'),
                        incrementKey: const Key('daily-target-fruit-increment'),
                        valueKey: const Key('daily-target-fruit-value'),
                      ),
                      const SizedBox(height: 12),
                      PortionStepper(
                        label: loc.dietCategoryVeg,
                        value: controller.draftBaseVeg,
                        onChanged: controller.setDraftBaseVeg,
                        color: dietColors?.veg,
                        leadingIcon: _CategoryIconChip(
                          letter: loc.dietCategoryIconVeg,
                          color: dietColors?.veg,
                        ),
                        decrementKey: const Key('daily-target-veg-decrement'),
                        incrementKey: const Key('daily-target-veg-increment'),
                        valueKey: const Key('daily-target-veg-value'),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        loc.dietBonusNote,
                        key: const Key('daily-target-bonus-note'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        key: const Key('save-target-button'),
                        onPressed:
                            _saving ||
                                controller.status == DailyTargetStatus.saving
                            ? null
                            : _save,
                        child: Text(loc.dietSaveTargetButton),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _TargetSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CategoryProgressBar(
                        key: const Key('daily-target-staple-progress'),
                        label: loc.dietCategoryStaple,
                        logged: target.logged.staple,
                        effective: target.effective.staple,
                        color: dietColors?.staple,
                        trailingLabel: loc.dietRemainingOfCategory(
                          target.remaining.staple,
                        ),
                      ),
                      const SizedBox(height: 12),
                      CategoryProgressBar(
                        key: const Key('daily-target-meat-progress'),
                        label: loc.dietCategoryMeat,
                        logged: target.logged.meat,
                        effective: target.effective.meat,
                        color: dietColors?.meat,
                        trailingLabel: loc.dietRemainingOfCategory(
                          target.remaining.meat,
                        ),
                      ),
                      const SizedBox(height: 12),
                      CategoryProgressBar(
                        key: const Key('daily-target-fruit-progress'),
                        label: loc.dietCategoryFruit,
                        logged: target.logged.fruit,
                        effective: target.effective.fruit,
                        color: dietColors?.fruit,
                        trailingLabel: loc.dietRemainingOfCategory(
                          target.remaining.fruit,
                        ),
                      ),
                      const SizedBox(height: 12),
                      CategoryProgressBar(
                        key: const Key('daily-target-veg-progress'),
                        label: loc.dietCategoryVeg,
                        logged: target.logged.veg,
                        effective: target.effective.veg,
                        color: dietColors?.veg,
                        trailingLabel: loc.dietRemainingOfCategory(
                          target.remaining.veg,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Rounded, outlined, ledge-shadowed card wrapper shared by the target and
/// today/remaining sections (D3 in design.md).
class _TargetSectionCard extends StatelessWidget {
  final Widget child;

  const _TargetSectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return LedgeCard(padding: const EdgeInsets.all(16), child: child);
  }
}

/// A small rounded category-color chip labeled with the category's initial
/// (derived from its localized name, e.g. "S" for Staple/"主" for 主食),
/// used as a [PortionStepper.leadingIcon].
class _CategoryIconChip extends StatelessWidget {
  final String letter;
  final Color? color;

  const _CategoryIconChip({required this.letter, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: theme.colorScheme.outline, width: 2),
      ),
      child: Text(letter, style: theme.textTheme.bodyMedium),
    );
  }
}
