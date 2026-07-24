import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/notifications/application/medication_reminders.dart';
import 'package:life_os/contexts/notifications/domain/medication_reminder.dart';
import 'package:life_os/contexts/notifications/presentation/medication_reminders_controller.dart';
import 'package:life_os/contexts/notifications/presentation/medication_reminders_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/l10n_test_app.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<String?> idToken() async => 'token-123';

  @override
  Stream<bool> get authStateChanges => const Stream.empty();

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {}
}

class _FakeMedicationReminderRepository
    implements MedicationReminderRepository {
  List<MedicationReminder> reminders;
  Object? listError;
  Object? mutateError;
  Object? timezoneError;

  _FakeMedicationReminderRepository({this.reminders = const []});

  @override
  Future<List<MedicationReminder>> list(String idToken) async {
    if (listError != null) throw listError!;
    return reminders;
  }

  @override
  Future<void> create(String idToken, MedicationReminderDraft draft) async {
    if (mutateError != null) throw mutateError!;
    reminders = [
      ...reminders,
      MedicationReminder(
        id: 'rem-new',
        label: draft.label,
        times: draft.times,
        daysOfWeek: draft.daysOfWeek,
        weekInterval: draft.weekInterval,
        anchorDate: draft.anchorDate,
        enabled: draft.enabled,
      ),
    ];
  }

  @override
  Future<void> update(
    String idToken,
    String id,
    MedicationReminderUpdate update,
  ) async {
    if (mutateError != null) throw mutateError!;
    reminders = [
      for (final r in reminders)
        if (r.id == id)
          MedicationReminder(
            id: r.id,
            label: update.label ?? r.label,
            times: update.times ?? r.times,
            daysOfWeek: update.daysOfWeek ?? r.daysOfWeek,
            weekInterval: update.weekInterval ?? r.weekInterval,
            anchorDate: update.anchorDate ?? r.anchorDate,
            enabled: update.enabled ?? r.enabled,
          )
        else
          r,
    ];
  }

  @override
  Future<void> delete(String idToken, String id) async {
    if (mutateError != null) throw mutateError!;
    reminders = reminders.where((r) => r.id != id).toList();
  }

  @override
  Future<void> setTimezone(String idToken, String timezone) async {
    if (timezoneError != null) throw timezoneError!;
  }
}

final _reminder = MedicationReminder(
  id: 'rem-1',
  label: 'Metformin',
  times: const ['08:00', '20:00'],
  daysOfWeek: const [1, 3, 5],
  weekInterval: 1,
  anchorDate: DateTime(2026, 7, 20),
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

Future<void> _pumpScreen(
  WidgetTester tester,
  MedicationRemindersController controller,
) async {
  await tester.pumpWidget(
    l10nTestApp(
      home: MedicationRemindersScreen(
        controller: controller,
        authRepository: _FakeAuthRepository(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('MedicationRemindersScreen', () {
    testWidgets('shows the empty-state guide when there are no reminders', (
      tester,
    ) async {
      final controller = await _controller();
      await _pumpScreen(tester, controller);

      expect(
        find.byKey(const Key('medication-reminders-empty-state')),
        findsOneWidget,
      );
    });

    testWidgets('lists each reminder with its label, times, and weekdays', (
      tester,
    ) async {
      final repository = _FakeMedicationReminderRepository(
        reminders: [_reminder],
      );
      final controller = await _controller(repository: repository);
      await _pumpScreen(tester, controller);

      expect(
        find.byKey(const Key('medication-reminder-row-rem-1')),
        findsOneWidget,
      );
      expect(find.text('Metformin'), findsOneWidget);
      expect(find.textContaining('08:00'), findsOneWidget);
      expect(find.textContaining('Mon'), findsOneWidget);
      expect(
        find.byKey(const Key('medication-reminders-empty-state')),
        findsNothing,
      );
    });

    testWidgets('toggling a reminder\'s switch updates its enabled state', (
      tester,
    ) async {
      final repository = _FakeMedicationReminderRepository(
        reminders: [_reminder],
      );
      final controller = await _controller(repository: repository);
      await _pumpScreen(tester, controller);

      await tester.tap(
        find.byKey(const Key('medication-reminder-switch-rem-1')),
      );
      await tester.pumpAndSettle();

      final switchWidget = tester.widget<Switch>(
        find.byKey(const Key('medication-reminder-switch-rem-1')),
      );
      expect(switchWidget.value, isFalse);
      expect(repository.reminders.single.enabled, isFalse);
    });

    testWidgets(
      'a failed enable-toggle reverts the switch and shows a SnackBar',
      (tester) async {
        final repository = _FakeMedicationReminderRepository(
          reminders: [_reminder],
        )..mutateError = const ReminderRequestFailed();
        final controller = await _controller(repository: repository);
        await _pumpScreen(tester, controller);

        await tester.tap(
          find.byKey(const Key('medication-reminder-switch-rem-1')),
        );
        await tester.pumpAndSettle();

        final switchWidget = tester.widget<Switch>(
          find.byKey(const Key('medication-reminder-switch-rem-1')),
        );
        expect(switchWidget.value, isTrue);
        expect(
          find.byKey(
            const Key('medication-reminders-toggle-failed-snackbar'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('medication-reminders-mutation-error')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'appends the cadence to the subtitle when weekInterval > 1, and omits '
      'it for a plain weekly reminder',
      (tester) async {
        final biweekly = MedicationReminder(
          id: 'rem-2',
          label: 'Vitamin D',
          times: const ['09:00'],
          daysOfWeek: const [2],
          weekInterval: 2,
          anchorDate: DateTime(2026, 7, 20),
          enabled: true,
        );
        final repository = _FakeMedicationReminderRepository(
          reminders: [_reminder, biweekly],
        );
        final controller = await _controller(repository: repository);
        await _pumpScreen(tester, controller);

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(
          find.textContaining(loc.medicationReminderCadenceSuffix(2)),
          findsOneWidget,
        );

        final weeklyRow = tester.widget<ListTile>(
          find.byKey(const Key('medication-reminder-row-rem-1')),
        );
        final weeklySubtitle = (weeklyRow.subtitle as Text).data!;
        expect(weeklySubtitle, isNot(contains('every')));
      },
    );

    testWidgets('the FAB opens the add form', (tester) async {
      final controller = await _controller();
      await _pumpScreen(tester, controller);

      await tester.tap(find.byKey(const Key('medication-reminders-add-fab')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('medication-reminder-label-field')),
        findsOneWidget,
      );
    });

    testWidgets('deleting a reminder requires confirmation', (tester) async {
      final repository = _FakeMedicationReminderRepository(
        reminders: [_reminder],
      );
      final controller = await _controller(repository: repository);
      await _pumpScreen(tester, controller);

      await tester.tap(
        find.byKey(const Key('medication-reminder-delete-rem-1')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('medication-reminder-delete-confirm')),
        findsOneWidget,
      );

      // Cancel leaves the reminder in place.
      await tester.tap(
        find.byKey(const Key('medication-reminder-delete-cancel')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('medication-reminder-row-rem-1')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('medication-reminder-delete-rem-1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('medication-reminder-delete-confirm')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('medication-reminder-row-rem-1')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('medication-reminders-empty-state')),
        findsOneWidget,
      );
    });

    testWidgets('a load reauth failure shows the full-screen reauth exit', (
      tester,
    ) async {
      final repository = _FakeMedicationReminderRepository()
        ..listError = const ReminderReauthRequired();
      final controller = await _controller(repository: repository);
      await _pumpScreen(tester, controller);

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.pleaseSignInAgain), findsOneWidget);
      expect(
        find.byKey(const Key('medication-reminders-add-fab')),
        findsNothing,
      );
    });

    testWidgets(
      'a load failure shows a retry button that reloads the list',
      (tester) async {
        final repository = _FakeMedicationReminderRepository()
          ..listError = const ReminderRequestFailed();
        final controller = await _controller(repository: repository);
        await _pumpScreen(tester, controller);

        expect(
          find.byKey(const Key('medication-reminders-load-error')),
          findsOneWidget,
        );

        repository.listError = null;
        repository.reminders = [_reminder];
        await tester.tap(
          find.byKey(const Key('medication-reminders-retry-button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('medication-reminder-row-rem-1')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows the default timezone and lets it be changed via the bottom '
      'sheet',
      (tester) async {
        final controller = await _controller();
        await _pumpScreen(tester, controller);

        expect(
          find.byKey(const Key('medication-reminders-timezone-value')),
          findsOneWidget,
        );
        expect(find.text('Asia/Taipei'), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('medication-reminders-timezone-edit')),
        );
        await tester.pumpAndSettle();

        // A modal bottom sheet, not an AlertDialog (repo convention: the
        // on-screen keyboard would cover an AlertDialog's Save button).
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(BottomSheet), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('medication-reminders-timezone-field')),
          'America/New_York',
        );
        await tester.tap(
          find.byKey(const Key('medication-reminders-timezone-save')),
        );
        await tester.pumpAndSettle();

        expect(find.text('America/New_York'), findsOneWidget);
      },
    );

    testWidgets(
      'an invalid timezone from the bottom sheet shows the localized error '
      'and leaves the timezone unchanged',
      (tester) async {
        final repository = _FakeMedicationReminderRepository()
          ..timezoneError = const ReminderRequestFailed();
        final controller = await _controller(repository: repository);
        await _pumpScreen(tester, controller);

        await tester.tap(
          find.byKey(const Key('medication-reminders-timezone-edit')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('medication-reminders-timezone-field')),
          'Not/AZone',
        );
        await tester.tap(
          find.byKey(const Key('medication-reminders-timezone-save')),
        );
        await tester.pumpAndSettle();

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.medicationReminderTimezoneError), findsOneWidget);
        expect(find.text('Asia/Taipei'), findsOneWidget);
      },
    );

    testWidgets(
      'submitting the add form with a valid draft shows the new reminder '
      'in the list',
      (tester) async {
        // The form's content can exceed the default 800x600 test surface,
        // pushing the submit button below the visible area (mirrors
        // medication_reminder_form_test.dart).
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final repository = _FakeMedicationReminderRepository();
        final controller = await _controller(repository: repository);
        await _pumpScreen(tester, controller);

        expect(
          find.byKey(const Key('medication-reminders-empty-state')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('medication-reminders-add-fab')),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('medication-reminder-label-field')),
          'Ibuprofen',
        );
        await tester.pump();

        // Add a time via the time picker's default OK button.
        await tester.tap(
          find.byKey(const Key('medication-reminder-add-time')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        // Select a weekday chip — everything required is now present.
        await tester.tap(
          find.byKey(const Key('medication-reminder-weekday-chip-1')),
        );
        await tester.pump();

        await tester.ensureVisible(
          find.byKey(const Key('medication-reminder-form-submit')),
        );
        await tester.tap(
          find.byKey(const Key('medication-reminder-form-submit')),
        );
        await tester.pumpAndSettle();

        // The form popped back to the list (create → reload → render).
        expect(
          find.byKey(const Key('medication-reminder-label-field')),
          findsNothing,
        );
        expect(find.text('Ibuprofen'), findsOneWidget);
        expect(
          find.byKey(const Key('medication-reminders-empty-state')),
          findsNothing,
        );
      },
    );
  });
}
