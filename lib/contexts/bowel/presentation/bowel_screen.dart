import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/async_state_scaffold.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../../shared/widgets/tracker_day_header.dart';
import '../../../shared/widgets/tracker_day_nav.dart';
import 'bowel_controller.dart';

/// Bowel section: a small form recording the day's bowel-movement count, an
/// optional normal/abnormal flag, and a note, saved together with an explicit
/// Save. The shell owns loading — this screen does not self-load.
class BowelScreen extends StatefulWidget {
  final BowelController controller;
  final String idToken;
  final String day;

  /// Returns the current time, used to resolve "today" for the header title.
  /// Defaults to [DateTime.now]; tests inject a fixed clock. Mirrors water.
  final DateTime Function() clock;

  const BowelScreen({
    super.key,
    required this.controller,
    required this.idToken,
    required this.day,
    this.clock = DateTime.now,
  });

  @override
  State<BowelScreen> createState() => _BowelScreenState();
}

class _BowelScreenState extends State<BowelScreen> with TrackerDayScreen {
  late final TextEditingController _noteController = TextEditingController(
    text: widget.controller.note,
  );

  @override
  String get initialDay => widget.day;
  @override
  DateTime Function() get clock => widget.clock;
  @override
  void reloadDay(String day) => widget.controller.load(widget.idToken, day);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _noteController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    // Keep the note field in sync when the draft is (re)populated by a load or
    // save — but not while the user is typing, which already drives the same
    // value (so no cursor-jumping mid-edit).
    if (_noteController.text != widget.controller.note) {
      _noteController.text = widget.controller.note;
    }
    setState(() {});
  }

  /// Awaits [save] then, if the controller ended in an error state, surfaces a
  /// transient save-failed snackbar over the still-rendered form. `needsReauth`
  /// routes via [build] instead, so it is left alone.
  Future<void> _save() async {
    await widget.controller.save(widget.idToken, viewedDay);
    if (!mounted) return;
    if (widget.controller.status == BowelStatus.error) {
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.bowelSaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final loc = AppLocalizations.of(context)!;

    final busy =
        controller.status == BowelStatus.loading ||
        controller.status == BowelStatus.saving;

    // Shared across the loading/reauth (AsyncStateScaffold) and loaded/error
    // Scaffolds so the pushed full-screen tracker keeps a back button + day nav
    // in every state (only one Scaffold is built per pass, so reusing the
    // instance is safe).
    final appBar = dayAppBar(loc.dietTabBowel);

    return AsyncStateScaffold(
      isLoading: busy && controller.day == null,
      isReauth: controller.status == BowelStatus.needsReauth,
      reauthMessage: loc.pleaseSignInAgain,
      appBar: appBar,
      builder: (context) {
        if (controller.day == null) {
          return Scaffold(
            appBar: appBar,
            body: Center(
              child: Text(
                loc.errorBowelLoadFailed,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return Scaffold(
          appBar: appBar,
          body: SafeArea(
            child: Column(
              children: [
                SizedBox(
                  height: 3,
                  child: busy
                      ? const LinearProgressIndicator(
                          key: Key('bowel-busy'),
                          minHeight: 3,
                        )
                      : null,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      LedgeCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TrackerDayHeader(
                              day: viewedDay,
                              clock: widget.clock,
                              todayTitle: loc.bowelTitle,
                              historyTitle: loc.bowelHistoryTitle,
                            ),
                            const SizedBox(height: 16),
                            _CountStepper(
                              label: loc.bowelCountLabel,
                              count: controller.count,
                              onChanged: busy ? null : controller.setCount,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              loc.bowelNormalityLabel,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 8),
                            SegmentedButton<bool>(
                              key: const Key('bowel-normal-segment'),
                              emptySelectionAllowed: true,
                              segments: [
                                ButtonSegment(
                                  value: true,
                                  label: Text(loc.bowelNormalLabel),
                                ),
                                ButtonSegment(
                                  value: false,
                                  label: Text(loc.bowelAbnormalLabel),
                                ),
                              ],
                              selected: controller.isNormal == null
                                  ? const <bool>{}
                                  : {controller.isNormal!},
                              onSelectionChanged: busy
                                  ? null
                                  : (selection) => controller.setIsNormal(
                                      selection.isEmpty
                                          ? null
                                          : selection.first,
                                    ),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              key: const Key('bowel-note-field'),
                              controller: _noteController,
                              enabled: !busy,
                              minLines: 3,
                              maxLines: 5,
                              decoration: InputDecoration(
                                labelText: loc.bowelNoteLabel,
                              ),
                              onChanged: controller.setNote,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (controller.hasUnsavedChanges)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            loc.bowelUnsavedChanges,
                            key: const Key('bowel-unsaved-indicator'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      FilledButton(
                        key: const Key('bowel-save-button'),
                        onPressed: (busy || !controller.hasUnsavedChanges)
                            ? null
                            : _save,
                        child: Text(loc.bowelSaveButton),
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

/// A −/＋ stepper around the current [count], flooring at 0 (the decrement is
/// disabled at 0). Colors/styles come from [Theme]. [onChanged] is `null` while
/// the screen is busy, disabling the controls.
class _CountStepper extends StatelessWidget {
  final String label;
  final int count;
  final ValueChanged<int>? onChanged;

  const _CountStepper({
    required this.label,
    required this.count,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canDecrement = onChanged != null && count > 0;
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
        IconButton(
          key: const Key('bowel-count-decrement'),
          onPressed: canDecrement ? () => onChanged!(count - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        Text(
          '$count',
          key: const Key('bowel-count-value'),
          style: theme.textTheme.titleLarge,
        ),
        IconButton(
          key: const Key('bowel-count-increment'),
          onPressed: onChanged != null ? () => onChanged!(count + 1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
