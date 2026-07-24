import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/notifications/application/medication_reminders.dart';
import 'package:life_os/contexts/notifications/domain/medication_reminder.dart';
import 'package:life_os/contexts/notifications/presentation/medication_reminder_form.dart';
import 'package:life_os/contexts/notifications/presentation/medication_reminders_controller.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/l10n_test_app.dart';

class _FakeMedicationReminderRepository
    implements MedicationReminderRepository {
  List<MedicationReminder> reminders;
  Object? mutateError;
  MedicationReminderDraft? lastDraft;
  String? lastUpdateId;
  MedicationReminderUpdate? lastUpdate;

  _FakeMedicationReminderRepository({this.reminders = const []});

  @override
  Future<List<MedicationReminder>> list(String idToken) async => reminders;

  @override
  Future<void> create(String idToken, MedicationReminderDraft draft) async {
    lastDraft = draft;
    if (mutateError != null) throw mutateError!;
  }

  @override
  Future<void> update(
    String idToken,
    String id,
    MedicationReminderUpdate update,
  ) async {
    lastUpdateId = id;
    lastUpdate = update;
    if (mutateError != null) throw mutateError!;
  }

  @override
  Future<void> delete(String idToken, String id) async {}

  @override
  Future<void> setTimezone(String idToken, String timezone) async {}
}

final _reminder = MedicationReminder(
  id: 'rem-1',
  label: 'Metformin',
  times: const ['08:00'],
  daysOfWeek: const [1, 3],
  weekInterval: 2,
  anchorDate: DateTime(2026, 7, 6),
  enabled: true,
);

Future<MedicationRemindersController> _controller({
  _FakeMedicationReminderRepository? repository,
}) async {
  final repo = repository ?? _FakeMedicationReminderRepository();
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return MedicationRemindersController(
    ListMedicationReminders(repo),
    CreateMedicationReminder(repo),
    UpdateMedicationReminder(repo),
    DeleteMedicationReminder(repo),
    SetReminderTimezone(repo),
    prefs,
  );
}

Future<void> _pumpForm(
  WidgetTester tester,
  MedicationRemindersController controller, {
  MedicationReminder? existing,
}) async {
  // The form's content can exceed the default 800x600 test surface, pushing
  // the submit button below the visible area — a taller surface keeps it
  // reachable without scrolling gymnastics (mirrors other long-form tests
  // in this repo, e.g. settings_screen_test.dart).
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    l10nTestApp(
      home: MedicationReminderForm(
        controller: controller,
        idToken: 'token-123',
        existing: existing,
        clock: () => DateTime(2026, 7, 22),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('MedicationReminderForm', () {
    testWidgets('add mode: submit is disabled until valid, then creates', (
      tester,
    ) async {
      final repository = _FakeMedicationReminderRepository();
      final controller = await _controller(repository: repository);
      await _pumpForm(tester, controller);

      // Empty label, no times, no weekdays: submit disabled.
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('medication-reminder-form-submit')),
            )
            .onPressed,
        isNull,
      );

      await tester.enterText(
        find.byKey(const Key('medication-reminder-label-field')),
        'Metformin',
      );
      await tester.pump();
      // Label alone still isn't enough (no time, no weekday).
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('medication-reminder-form-submit')),
            )
            .onPressed,
        isNull,
      );

      // Add a time via the time picker.
      await tester.tap(find.byKey(const Key('medication-reminder-add-time')));
      await tester.pumpAndSettle();
      // The Material time picker's OK button.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('medication-reminder-form-submit')),
            )
            .onPressed,
        isNull,
      );

      // Select a weekday chip — now everything required is present.
      await tester.tap(
        find.byKey(const Key('medication-reminder-weekday-chip-1')),
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('medication-reminder-form-submit')),
            )
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.byKey(const Key('medication-reminder-form-submit')));
      await tester.pumpAndSettle();

      expect(repository.lastDraft, isNotNull);
      expect(repository.lastDraft!.label, 'Metformin');
      expect(repository.lastDraft!.daysOfWeek, [1]);
      expect(repository.lastDraft!.times, hasLength(1));
    });

    testWidgets(
      'shows an inline hint while Save is disabled, hides it once complete, '
      'and creates on submit',
      (tester) async {
        final repository = _FakeMedicationReminderRepository();
        final controller = await _controller(repository: repository);
        await _pumpForm(tester, controller);

        expect(
          find.byKey(const Key('medication-reminder-incomplete-hint')),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(const Key('medication-reminder-label-field')),
          'Metformin',
        );
        await tester.pump();
        expect(
          find.byKey(const Key('medication-reminder-incomplete-hint')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('medication-reminder-add-time')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('medication-reminder-incomplete-hint')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('medication-reminder-weekday-chip-1')),
        );
        await tester.pump();

        expect(
          find.byKey(const Key('medication-reminder-incomplete-hint')),
          findsNothing,
        );

        await tester.tap(
          find.byKey(const Key('medication-reminder-form-submit')),
        );
        await tester.pumpAndSettle();

        expect(repository.lastDraft, isNotNull);
        expect(repository.lastDraft!.label, 'Metformin');
      },
    );

    testWidgets('removing the only time disables submit again', (
      tester,
    ) async {
      final controller = await _controller();
      await _pumpForm(tester, controller, existing: _reminder);

      // Pre-filled from `existing`: submit should already be enabled.
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('medication-reminder-form-submit')),
            )
            .onPressed,
        isNotNull,
      );

      await tester.tap(
        find.byKey(const Key('medication-reminder-remove-time-0')),
      );
      await tester.pump();

      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('medication-reminder-form-submit')),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('edit mode: submitting calls update with the reminder\'s id', (
      tester,
    ) async {
      final repository = _FakeMedicationReminderRepository(
        reminders: [_reminder],
      );
      final controller = await _controller(repository: repository);
      await _pumpForm(tester, controller, existing: _reminder);

      await tester.enterText(
        find.byKey(const Key('medication-reminder-label-field')),
        'Metformin XR',
      );
      await tester.tap(find.byKey(const Key('medication-reminder-form-submit')));
      await tester.pumpAndSettle();

      expect(repository.lastUpdateId, 'rem-1');
      expect(repository.lastUpdate!.label, 'Metformin XR');
    });

    testWidgets(
      'a mutation failure keeps the form open and shows an inline error',
      (tester) async {
        final repository = _FakeMedicationReminderRepository(
          reminders: [_reminder],
        )..mutateError = const ReminderRequestFailed();
        final controller = await _controller(repository: repository);
        await _pumpForm(tester, controller, existing: _reminder);

        await tester.ensureVisible(
          find.byKey(const Key('medication-reminder-form-submit')),
        );
        await tester.tap(find.byKey(const Key('medication-reminder-form-submit')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('medication-reminder-form-error')),
          findsOneWidget,
        );
        // Still on the form (didn't pop).
        expect(
          find.byKey(const Key('medication-reminder-label-field')),
          findsOneWidget,
        );
      },
    );

    testWidgets('the week-interval stepper adjusts and floors at 1', (
      tester,
    ) async {
      final controller = await _controller();
      await _pumpForm(tester, controller, existing: _reminder);

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(
        find.text(loc.medicationReminderWeekIntervalValue(2)),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('medication-reminder-week-interval-decrement')),
      );
      await tester.pump();
      expect(
        find.text(loc.medicationReminderWeekIntervalValue(1)),
        findsOneWidget,
      );

      final decrementButton = tester.widget<IconButton>(
        find.byKey(const Key('medication-reminder-week-interval-decrement')),
      );
      expect(decrementButton.onPressed, isNull);
    });

    testWidgets(
      'hides the anchor date picker while weekInterval == 1, and shows it '
      'once the interval is raised above 1',
      (tester) async {
        final controller = await _controller();
        await _pumpForm(tester, controller);

        // Add mode defaults to weekInterval == 1: no anchor date picker.
        expect(
          find.byKey(const Key('medication-reminder-anchor-date')),
          findsNothing,
        );

        await tester.tap(
          find.byKey(const Key('medication-reminder-week-interval-increment')),
        );
        await tester.pump();

        expect(
          find.byKey(const Key('medication-reminder-anchor-date')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'edit mode with an existing weekInterval > 1 shows the anchor date '
      'picker',
      (tester) async {
        final controller = await _controller();
        await _pumpForm(tester, controller, existing: _reminder);

        expect(
          find.byKey(const Key('medication-reminder-anchor-date')),
          findsOneWidget,
        );
      },
    );

    testWidgets('toggling a weekday chip off removes it from the selection', (
      tester,
    ) async {
      final controller = await _controller();
      await _pumpForm(tester, controller, existing: _reminder);

      final mondayChip = tester.widget<FilterChip>(
        find.byKey(const Key('medication-reminder-weekday-chip-1')),
      );
      expect(mondayChip.selected, isTrue);

      await tester.tap(
        find.byKey(const Key('medication-reminder-weekday-chip-1')),
      );
      await tester.pump();

      final updatedChip = tester.widget<FilterChip>(
        find.byKey(const Key('medication-reminder-weekday-chip-1')),
      );
      expect(updatedChip.selected, isFalse);
    });
  });
}
