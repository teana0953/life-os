import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/notifications/application/medication_reminders.dart';
import 'package:life_os/contexts/notifications/domain/medication_reminder.dart';
import 'package:life_os/contexts/notifications/presentation/medication_reminders_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeMedicationReminderRepository
    implements MedicationReminderRepository {
  List<MedicationReminder> reminders;
  Object? listError;
  Object? mutateError;
  Object? timezoneError;
  Completer<void>? mutateCompleter;
  int createCalls = 0;
  int deleteCalls = 0;
  MedicationReminderUpdate? lastUpdate;
  String? lastUpdateId;
  String? lastTimezone;

  _FakeMedicationReminderRepository({this.reminders = const []});

  @override
  Future<List<MedicationReminder>> list(String idToken) async {
    if (listError != null) throw listError!;
    return reminders;
  }

  @override
  Future<void> create(String idToken, MedicationReminderDraft draft) async {
    createCalls++;
    if (mutateCompleter != null) return mutateCompleter!.future;
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
    if (mutateCompleter != null) return mutateCompleter!.future;
    if (mutateError != null) throw mutateError!;
  }

  @override
  Future<void> delete(String idToken, String id) async {
    deleteCalls++;
    if (mutateCompleter != null) return mutateCompleter!.future;
    if (mutateError != null) throw mutateError!;
  }

  @override
  Future<void> setTimezone(String idToken, String timezone) async {
    lastTimezone = timezone;
    if (timezoneError != null) throw timezoneError!;
  }
}

Future<MedicationRemindersController> _controller({
  _FakeMedicationReminderRepository? repository,
  Map<String, Object> prefsValues = const {},
}) async {
  final repo = repository ?? _FakeMedicationReminderRepository();
  SharedPreferences.setMockInitialValues(prefsValues);
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

final _reminder = MedicationReminder(
  id: 'rem-1',
  label: 'Metformin',
  times: const ['08:00'],
  daysOfWeek: const [1, 3, 5],
  weekInterval: 1,
  anchorDate: DateTime(2026, 7, 20),
  enabled: true,
);

void main() {
  group('MedicationRemindersController.load', () {
    test('populates reminders and sets loaded on success', () async {
      final repository = _FakeMedicationReminderRepository(
        reminders: [_reminder],
      );
      final controller = await _controller(repository: repository);

      await controller.load('token-123');

      expect(controller.status, MedicationRemindersStatus.loaded);
      expect(controller.reminders, [_reminder]);
    });

    test('an empty list still resolves to loaded (empty state)', () async {
      final controller = await _controller();

      await controller.load('token-123');

      expect(controller.status, MedicationRemindersStatus.loaded);
      expect(controller.reminders, isEmpty);
    });

    test('a ReminderReauthRequired routes to reauth', () async {
      final repository = _FakeMedicationReminderRepository()
        ..listError = const ReminderReauthRequired();
      final controller = await _controller(repository: repository);

      await controller.load('token-123');

      expect(controller.status, MedicationRemindersStatus.reauth);
    });

    test('a ReminderRequestFailed routes to error and holds it', () async {
      final repository = _FakeMedicationReminderRepository()
        ..listError = const ReminderRequestFailed();
      final controller = await _controller(repository: repository);

      await controller.load('token-123');

      expect(controller.status, MedicationRemindersStatus.error);
      expect(controller.error, isA<ReminderRequestFailed>());
    });

    test('clears a stale mutationError so an old banner does not linger', () async {
      final repository = _FakeMedicationReminderRepository(
        reminders: [_reminder],
      )..mutateError = const ReminderRequestFailed();
      final controller = await _controller(repository: repository);
      await controller.load('token-123');
      await controller.delete('token-123', 'rem-1');
      expect(controller.mutationError, isNotNull);

      repository.mutateError = null;
      await controller.load('token-123');

      expect(controller.mutationError, isNull);
    });
  });

  group('MedicationRemindersController mutations', () {
    test('create calls the repository then reloads the list', () async {
      final repository = _FakeMedicationReminderRepository(
        reminders: [_reminder],
      );
      final controller = await _controller(repository: repository);
      await controller.load('token-123');

      await controller.create(
        'token-123',
        MedicationReminderDraft(
          label: 'Ibuprofen',
          times: const ['09:00'],
          daysOfWeek: const [0],
          weekInterval: 1,
          anchorDate: DateTime(2026, 7, 21),
          enabled: true,
        ),
      );

      expect(repository.createCalls, 1);
      expect(controller.reminders, [_reminder]);
      expect(controller.status, MedicationRemindersStatus.loaded);
    });

    test('delete calls the repository then reloads the list', () async {
      final repository = _FakeMedicationReminderRepository(
        reminders: [_reminder],
      );
      final controller = await _controller(repository: repository);
      await controller.load('token-123');

      await controller.delete('token-123', 'rem-1');

      expect(repository.deleteCalls, 1);
    });

    test('toggleEnabled sends a partial {enabled}-only update (design D3)', () async {
      final repository = _FakeMedicationReminderRepository(
        reminders: [_reminder],
      );
      final controller = await _controller(repository: repository);
      await controller.load('token-123');

      await controller.toggleEnabled('token-123', 'rem-1', false);

      expect(repository.lastUpdateId, 'rem-1');
      expect(repository.lastUpdate!.enabled, false);
      expect(repository.lastUpdate!.label, isNull);
      expect(repository.lastUpdate!.times, isNull);
    });

    test(
      'a mutation failure surfaces the typed error and keeps the existing '
      'list',
      () async {
        final repository = _FakeMedicationReminderRepository(
          reminders: [_reminder],
        )..mutateError = const ReminderRequestFailed();
        final controller = await _controller(repository: repository);
        await controller.load('token-123');

        await controller.delete('token-123', 'rem-1');

        expect(controller.mutationError, isA<ReminderRequestFailed>());
        expect(controller.reminders, [_reminder]);
        expect(controller.status, MedicationRemindersStatus.loaded);
      },
    );

    test('a mutation ReminderReauthRequired routes status to reauth', () async {
      final repository = _FakeMedicationReminderRepository(
        reminders: [_reminder],
      )..mutateError = const ReminderReauthRequired();
      final controller = await _controller(repository: repository);
      await controller.load('token-123');

      await controller.delete('token-123', 'rem-1');

      expect(controller.status, MedicationRemindersStatus.reauth);
    });

    test(
      'a mutation that succeeds but whose reload fails pops as a success '
      '(no mutationError) while surfacing the reload failure as the '
      'load-level error state',
      () async {
        final repository = _FakeMedicationReminderRepository(
          reminders: [_reminder],
        );
        final controller = await _controller(repository: repository);
        await controller.load('token-123');

        // The delete itself succeeds, but the list starts throwing right
        // before the reload that `_mutate` triggers afterwards.
        repository.listError = const ReminderRequestFailed();

        await controller.delete('token-123', 'rem-1');

        expect(repository.deleteCalls, 1);
        expect(controller.mutationError, isNull);
        expect(controller.status, MedicationRemindersStatus.error);
        expect(controller.error, isA<ReminderRequestFailed>());
      },
    );

    test(
      'a mutation that succeeds but whose reload hits a reauth routes '
      'status to reauth without setting mutationError',
      () async {
        final repository = _FakeMedicationReminderRepository(
          reminders: [_reminder],
        );
        final controller = await _controller(repository: repository);
        await controller.load('token-123');

        repository.listError = const ReminderReauthRequired();

        await controller.delete('token-123', 'rem-1');

        expect(repository.deleteCalls, 1);
        expect(controller.mutationError, isNull);
        expect(controller.status, MedicationRemindersStatus.reauth);
      },
    );

    test('re-entrancy: a second mutation call is ignored while one is in flight', () async {
      final repository = _FakeMedicationReminderRepository(
        reminders: [_reminder],
      );
      final controller = await _controller(repository: repository);
      await controller.load('token-123');

      final completer = Completer<void>();
      repository.mutateCompleter = completer;
      final first = controller.delete('token-123', 'rem-1');
      expect(controller.mutating, isTrue);
      final second = controller.delete('token-123', 'rem-1');

      completer.complete();
      await Future.wait([first, second]);

      expect(repository.deleteCalls, 1);
      expect(controller.mutating, isFalse);
    });
  });

  group('MedicationRemindersController.setTimezone', () {
    test('defaults to Asia/Taipei when nothing was persisted', () async {
      final controller = await _controller();

      expect(controller.timezone, 'Asia/Taipei');
    });

    test('starts from a persisted value', () async {
      final controller = await _controller(
        prefsValues: {'medication_reminder_timezone': 'America/New_York'},
      );

      expect(controller.timezone, 'America/New_York');
    });

    test('a successful set updates and persists the timezone', () async {
      final repository = _FakeMedicationReminderRepository();
      final controller = await _controller(repository: repository);

      await controller.setTimezone('token-123', 'America/New_York');

      expect(controller.timezone, 'America/New_York');
      expect(repository.lastTimezone, 'America/New_York');
      expect(controller.timezoneError, isNull);
    });

    test('a failure surfaces the typed error and leaves timezone unchanged', () async {
      final repository = _FakeMedicationReminderRepository()
        ..timezoneError = const ReminderRequestFailed();
      final controller = await _controller(repository: repository);

      await controller.setTimezone('token-123', 'Not/AZone');

      expect(controller.timezoneError, isA<ReminderRequestFailed>());
      expect(controller.timezone, 'Asia/Taipei');
    });

    test('a reauth failure routes status to reauth', () async {
      final repository = _FakeMedicationReminderRepository()
        ..timezoneError = const ReminderReauthRequired();
      final controller = await _controller(repository: repository);

      await controller.setTimezone('token-123', 'America/New_York');

      expect(controller.status, MedicationRemindersStatus.reauth);
    });
  });
}
