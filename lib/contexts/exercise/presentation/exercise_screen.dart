import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/async_state_scaffold.dart';
import '../../../shared/widgets/last_loaded_label.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../../shared/widgets/numeric_amount_field.dart';
import '../../../shared/widgets/tracker_busy_bar.dart';
import '../../../shared/widgets/tracker_day_nav.dart';
import '../domain/exercise_day.dart';
import 'exercise_controller.dart';

/// Exercise section: the viewed day's entries and their total duration, with an
/// immediate append (an activity picker + whole-minutes duration + optional
/// note) and per-entry removal. Each append/remove persists to the backend and
/// re-reads the day (via the controller). The shell owns loading — this screen
/// does not self-load.
class ExerciseScreen extends StatefulWidget {
  final ExerciseController controller;
  final String idToken;
  final String day;

  /// Returns the current time, used to resolve "today" for the header title.
  /// Defaults to [DateTime.now]; tests inject a fixed clock. Mirrors water.
  final DateTime Function() clock;

  const ExerciseScreen({
    super.key,
    required this.controller,
    required this.idToken,
    required this.day,
    this.clock = DateTime.now,
  });

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> with TrackerDayScreen {
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
    if (widget.controller.status == ExerciseStatus.error) {
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.exerciseSaveFailed)));
    }
  }

  /// Deletes [entry], then — on success — surfaces a SnackBar with an Undo
  /// action that re-adds it (a fresh POST; the backend assigns a new id/
  /// createdAt, which is acceptable). A failed/needs-reauth delete falls through
  /// to `_runMutation`'s own handling (error SnackBar / reauth screen) and shows
  /// no undo prompt.
  Future<void> _removeEntry(ExerciseEntry entry) async {
    // Pin the day at delete time so a later Undo re-adds to the day the entry
    // was removed from — not whichever day the user has since browsed to.
    final day = viewedDay;
    await _runMutation(
      () => widget.controller.deleteEntry(widget.idToken, day, entry.id),
    );
    if (!mounted) return;
    if (widget.controller.status != ExerciseStatus.loaded) return;
    final loc = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loc.exerciseEntryRemoved),
        action: SnackBarAction(
          label: loc.exerciseUndo,
          onPressed: () => _runMutation(
            () => widget.controller.addEntry(
              widget.idToken,
              day,
              activityId: entry.activityId,
              durationMinutes: entry.durationMinutes,
              note: entry.note,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAddDialog() async {
    // A modal bottom sheet (not an AlertDialog): with `isScrollControlled` and a
    // bottom `viewInsets` padding, the sheet lifts above the on-screen keyboard
    // so the duration/note fields stay visible while typing — an AlertDialog
    // centred behind the keyboard hid them.
    final result = await showModalBottomSheet<_NewEntry>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _AddExerciseSheet(activities: widget.controller.activities),
    );
    if (result == null) return;
    await _runMutation(
      () => widget.controller.addEntry(
        widget.idToken,
        viewedDay,
        activityId: result.activityId,
        durationMinutes: result.durationMinutes,
        note: result.note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final loc = AppLocalizations.of(context)!;

    final busy =
        controller.status == ExerciseStatus.loading ||
        controller.status == ExerciseStatus.saving;

    // Shared across the loading/reauth (AsyncStateScaffold) and loaded/error
    // Scaffolds so the pushed full-screen tracker keeps a back button in every
    // state; the day switcher lives in the body's shared header below.
    final appBar = AppBar(title: Text(loc.dietTabExercise));

    return AsyncStateScaffold(
      isLoading: busy && controller.day == null,
      isReauth: controller.status == ExerciseStatus.needsReauth,
      reauthMessage: loc.pleaseSignInAgain,
      appBar: appBar,
      builder: (context) {
        if (controller.day == null) {
          return Scaffold(
            appBar: appBar,
            body: Center(
              child: Text(
                loc.errorExerciseLoadFailed,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final day = controller.day!;

        return Scaffold(
          appBar: appBar,
          body: SafeArea(
            child: Column(
              children: [
                TrackerBusyBar(
                  busy: busy,
                  indicatorKey: const Key('exercise-busy'),
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
                        todayTitle: loc.exerciseTitle,
                        historyTitle: loc.exerciseHistoryTitle,
                      ),
                      LastLoadedLabel(lastLoadedAt: controller.lastLoadedAt),
                      const SizedBox(height: 16),
                      LedgeCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              loc.exerciseTotalMinutes(day.totalMinutes),
                              key: const Key('exercise-total'),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (day.entries.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            loc.exerciseEmptyLabel,
                            key: const Key('exercise-empty'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        )
                      else
                        for (var index = 0; index < day.entries.length; index++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _EntryRow(
                              index: index,
                              entry: day.entries[index],
                              enabled: !busy,
                              onRemove: () =>
                                  _removeEntry(day.entries[index]),
                            ),
                          ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        key: const Key('exercise-add-button'),
                        onPressed: busy ? null : _openAddDialog,
                        icon: const Icon(Icons.add),
                        label: Text(loc.exerciseAddButton),
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

/// One exercise entry row inside a [LedgeCard]: the activity name (backend
/// data, not localized), its duration, an optional note, and a trailing remove
/// control. Colors/styles derive from [Theme].
class _EntryRow extends StatelessWidget {
  final int index;
  final ExerciseEntry entry;
  final bool enabled;
  final VoidCallback onRemove;

  const _EntryRow({
    required this.index,
    required this.entry,
    required this.enabled,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    return LedgeCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.activityName ?? entry.activityId,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  loc.exerciseEntryDuration(entry.durationMinutes),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (entry.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(entry.note, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
          IconButton(
            key: Key('exercise-remove-$index'),
            tooltip: loc.exerciseRemoveEntry,
            onPressed: enabled ? onRemove : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
        ],
      ),
    );
  }
}

/// The dialog's result: a chosen activity, a positive whole-minute duration,
/// and an optional note.
class _NewEntry {
  final String activityId;
  final int durationMinutes;
  final String note;

  const _NewEntry(this.activityId, this.durationMinutes, this.note);
}

/// The add-entry dialog: an activity picker (the library grouped aerobic /
/// anaerobic), a whole-minutes duration field (empty-zero convention via
/// [NumericAmountField]), and an optional note. The confirm control is disabled
/// until an activity is chosen and the duration is a positive whole number.
class _AddExerciseSheet extends StatefulWidget {
  final List<ExerciseActivity> activities;

  const _AddExerciseSheet({required this.activities});

  @override
  State<_AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends State<_AddExerciseSheet> {
  String? _activityId;
  final _durationController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Re-evaluate whether confirm can submit as the duration is typed
    // ([NumericAmountField] owns the field and exposes no onChanged).
    _durationController.addListener(_onDurationChanged);
  }

  void _onDurationChanged() => setState(() {});

  @override
  void dispose() {
    _durationController.removeListener(_onDurationChanged);
    _durationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// The typed duration parsed to a positive whole number of minutes, or `null`
  /// when empty / non-integer / not positive (which keeps confirm disabled).
  int? get _minutes {
    final value = int.tryParse(_durationController.text.trim());
    if (value == null || value <= 0) return null;
    return value;
  }

  bool get _canSubmit => _activityId != null && _minutes != null;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final aerobic = widget.activities
        .where((a) => a.category == 'aerobic')
        .toList();
    final anaerobic = widget.activities
        .where((a) => a.category == 'anaerobic')
        .toList();

    final theme = Theme.of(context);
    return Padding(
      // Lift the sheet's content above the on-screen keyboard so the duration
      // and note fields stay visible while the user types.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.exerciseAddDialogTitle,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(loc.exerciseActivityLabel, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              _ActivityGroup(
                title: loc.exerciseCategoryAerobic,
                activities: aerobic,
                selectedId: _activityId,
                onSelected: (id) => setState(() => _activityId = id),
              ),
              const SizedBox(height: 8),
              _ActivityGroup(
                title: loc.exerciseCategoryAnaerobic,
                activities: anaerobic,
                selectedId: _activityId,
                onSelected: (id) => setState(() => _activityId = id),
              ),
              const SizedBox(height: 16),
              NumericAmountField(
                fieldKey: const Key('exercise-duration-field'),
                controller: _durationController,
                label: loc.exerciseDurationLabel,
                // Exercise minutes are whole numbers only — an integer keyboard
                // avoids letting the user type a decimal the confirm silently
                // rejects.
                allowDecimal: false,
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('exercise-note-field'),
                controller: _noteController,
                decoration: InputDecoration(labelText: loc.exerciseNoteLabel),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('exercise-add-confirm'),
                  onPressed: _canSubmit
                      ? () => Navigator.of(context).pop(
                          _NewEntry(_activityId!, _minutes!, _noteController.text.trim()),
                        )
                      : null,
                  child: Text(loc.exerciseAddConfirmButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One category group in the activity picker: a small heading and a wrap of
/// choice chips (activity names — backend data, not localized). The duration
/// field's rebuild-on-keystroke keeps the selection via [selectedId].
class _ActivityGroup extends StatelessWidget {
  final String title;
  final List<ExerciseActivity> activities;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  const _ActivityGroup({
    required this.title,
    required this.activities,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final activity in activities)
              ChoiceChip(
                key: Key('exercise-activity-${activity.id}'),
                label: Text(activity.name),
                selected: selectedId == activity.id,
                onSelected: (_) => onSelected(activity.id),
              ),
          ],
        ),
      ],
    );
  }
}
