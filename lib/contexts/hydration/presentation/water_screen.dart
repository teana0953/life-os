import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/amount_entry_dialog.dart';
import '../../../shared/widgets/async_state_scaffold.dart';
import '../../../shared/widgets/fractional_progress_bar.dart';
import '../../../shared/widgets/last_loaded_label.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../../shared/widgets/tracker_day_nav.dart';
import 'water_controller.dart';

/// Water section: the day's total against its target with a progress bar,
/// quick-add / custom / correction controls, and a settable daily target.
/// The shell owns loading — this screen does not self-load.
class WaterScreen extends StatefulWidget {
  final WaterController controller;
  final String idToken;
  final String day;

  /// Returns the current time, used to resolve "today" so the heading and
  /// date reflect whether [day] is today or a past day. Defaults to
  /// [DateTime.now]; tests inject a fixed clock. Mirrors the diet shell.
  final DateTime Function() clock;

  const WaterScreen({
    super.key,
    required this.controller,
    required this.idToken,
    required this.day,
    this.clock = DateTime.now,
  });

  @override
  State<WaterScreen> createState() => _WaterScreenState();
}

class _WaterScreenState extends State<WaterScreen> with TrackerDayScreen {
  @override
  String get initialDay => widget.day;
  @override
  DateTime Function() get clock => widget.clock;
  @override
  Future<void> reloadDay(String day) =>
      widget.controller.load(widget.idToken, day);

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

  /// Awaits [action] (a controller mutation) then, if the controller ended in
  /// an error state, surfaces a transient save-failed snackbar. `needsReauth`
  /// routes to the reauth screen via [build] instead, so it is left alone.
  Future<void> _runMutation(Future<void> Function() action) async {
    await action();
    if (!mounted) return;
    if (widget.controller.status == WaterStatus.error) {
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.waterSaveFailed)));
    }
  }

  Future<void> _addCustomAmount() async {
    final loc = AppLocalizations.of(context)!;
    final amount = await showDialog<int>(
      context: context,
      builder: (_) => AmountEntryDialog<int>(
        title: loc.waterCustomAmountTitle,
        initialText: '',
        keyboardType: TextInputType.number,
        parse: int.tryParse,
        fieldKey: const Key('water-amount-field'),
        confirmKey: const Key('water-amount-confirm'),
      ),
    );
    if (amount != null && amount != 0) {
      await _runMutation(
        () => widget.controller.addWater(widget.idToken, viewedDay, amount),
      );
    }
  }

  Future<void> _setTarget() async {
    final loc = AppLocalizations.of(context)!;
    final current = widget.controller.day?.targetMl ?? 0;
    final target = await showDialog<int>(
      context: context,
      builder: (_) => AmountEntryDialog<int>(
        title: loc.waterSetTargetTitle,
        initialText: current == 0 ? '' : current.toString(),
        keyboardType: TextInputType.number,
        parse: int.tryParse,
        fieldKey: const Key('water-amount-field'),
        confirmKey: const Key('water-amount-confirm'),
      ),
    );
    if (target != null) {
      await _runMutation(
        () => widget.controller.setTarget(widget.idToken, viewedDay, target),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final loc = AppLocalizations.of(context)!;

    final busy =
        controller.status == WaterStatus.loading ||
        controller.status == WaterStatus.saving;

    // A back-able app bar (the pushed tracker keeps a back button in every
    // state); the day switcher lives in the body's shared header below.
    final appBar = AppBar(title: Text(loc.dietTabWater));

    // Full-screen spinner only on the very first load, when there is no data
    // to show yet. Once a day is loaded, mutations/reloads keep the content
    // on screen with a subtle busy indicator instead of blanking the tab.
    return AsyncStateScaffold(
      appBar: appBar,
      isLoading: busy && controller.day == null,
      isReauth: controller.status == WaterStatus.needsReauth,
      reauthMessage: loc.pleaseSignInAgain,
      builder: (context) {
        if (controller.day == null) {
          return Scaffold(
            appBar: appBar,
            body: Center(
              child: Text(
                loc.errorWaterLoadFailed,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final day = controller.day!;

        final goalMet = day.targetMl > 0 && day.totalMl >= day.targetMl;

        return Scaffold(
          appBar: appBar,
          body: SafeArea(
            child: Column(
              children: [
                // Subtle busy indicator during a mutation/reload — the content
                // below stays visible rather than blanking to a full spinner.
                SizedBox(
                  height: 3,
                  child: busy
                      ? const LinearProgressIndicator(
                          key: Key('water-busy'),
                          minHeight: 3,
                        )
                      : null,
                ),
                Expanded(
                  child: refreshable(
                    child: ListView(
                    // Always scrollable so a short day still accepts the
                    // overscroll pull that triggers a refresh.
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      dayNavHeader(
                        todayTitle: loc.waterTitle,
                        historyTitle: loc.waterHistoryTitle,
                      ),
                      LastLoadedLabel(lastLoadedAt: controller.lastLoadedAt),
                      const SizedBox(height: 16),
                      _WaterSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _WaterProgressBar(
                              key: const Key('water-progress'),
                              totalMl: day.totalMl,
                              targetMl: day.targetMl,
                              goalMet: goalMet,
                              goalMetLabel: loc.waterGoalMet,
                              label: loc.waterTotalOfTarget(
                                day.totalMl,
                                day.targetMl,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _WaterSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton(
                                    key: const Key('water-add-250'),
                                    onPressed: busy
                                        ? null
                                        : () => _runMutation(
                                            () => controller.addWater(
                                              widget.idToken,
                                              viewedDay,
                                              250,
                                            ),
                                          ),
                                    child: Text(loc.waterAdd250),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    key: const Key('water-add-500'),
                                    onPressed: busy
                                        ? null
                                        : () => _runMutation(
                                            () => controller.addWater(
                                              widget.idToken,
                                              viewedDay,
                                              500,
                                            ),
                                          ),
                                    child: Text(loc.waterAdd500),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    key: const Key('water-add-custom'),
                                    onPressed: busy ? null : _addCustomAmount,
                                    child: Text(loc.waterCustomAmount),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    key: const Key('water-correct-250'),
                                    onPressed: busy
                                        ? null
                                        : () => _runMutation(
                                            () => controller.correct(
                                              widget.idToken,
                                              viewedDay,
                                              -250,
                                            ),
                                          ),
                                    child: Text(loc.waterCorrect250),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _WaterSectionCard(
                        child: OutlinedButton(
                          key: const Key('water-set-target'),
                          onPressed: busy ? null : _setTarget,
                          child: Text(loc.waterSetTargetButton),
                        ),
                      ),
                    ],
                    ),
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

/// Rounded, outlined, ledge-shadowed card wrapper matching the diet sections.
class _WaterSectionCard extends StatelessWidget {
  final Widget child;

  const _WaterSectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return LedgeCard(padding: const EdgeInsets.all(16), child: child);
  }
}

/// The water intake progress bar: a rounded track filled to
/// `clamp(total / target, 0, 1)` — so exceeding the target shows a full bar
/// (goal met), never a negative or overflowing one — with the total/target
/// readout above it. A target of 0 or less renders an empty bar rather than
/// dividing by zero.
class _WaterProgressBar extends StatelessWidget {
  final int totalMl;
  final int targetMl;
  final String label;

  /// Whether the day's total has reached or exceeded its target — drives the
  /// distinct "goal met" fill color and the badge next to the readout.
  final bool goalMet;
  final String goalMetLabel;

  const _WaterProgressBar({
    super.key,
    required this.totalMl,
    required this.targetMl,
    required this.label,
    required this.goalMet,
    required this.goalMetLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = targetMl <= 0 ? 0.0 : (totalMl / targetMl).clamp(0.0, 1.0);
    // The theme exposes no dedicated "success" role in its ColorScheme; its
    // tertiary is the closest semantic accent, so goal-met reuses it rather
    // than the normal primary fill (never a hard-coded hex).
    final fillColor = goalMet
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Flexible(child: Text(label, style: theme.textTheme.bodyLarge)),
            if (goalMet) ...[
              const SizedBox(width: 8),
              _GoalMetBadge(label: goalMetLabel),
            ],
          ],
        ),
        const SizedBox(height: 6),
        FractionalProgressBar(fraction: fraction, fillColor: fillColor),
      ],
    );
  }
}

/// A small pill badge shown next to the intake readout once the day's target
/// is met — a themed check + label, colored from the ColorScheme's tertiary
/// (goal-met) accent.
class _GoalMetBadge extends StatelessWidget {
  final String label;

  const _GoalMetBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('water-goal-met-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 14, color: theme.colorScheme.onTertiary),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
