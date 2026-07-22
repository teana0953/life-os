import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:life_os/contexts/vitals/application/get_vitals_day.dart';
import 'package:life_os/contexts/vitals/application/save_vitals_day.dart';
import 'package:life_os/contexts/vitals/domain/vitals_day.dart';
import 'package:life_os/contexts/vitals/domain/vitals_exceptions.dart';
import 'package:life_os/contexts/vitals/domain/vitals_repository.dart';
import 'package:life_os/contexts/vitals/presentation/vitals_controller.dart';
import 'package:life_os/contexts/vitals/presentation/vitals_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';

/// A backend-like fake: keeps the last-saved record so save→reload round-trips
/// read back real state.
class FakeVitalsRepository implements VitalsRepository {
  VitalsDay stored;
  Object? getError;
  Object? saveError;

  VitalsDay? savedDay;

  FakeVitalsRepository({VitalsDay? stored})
    : stored =
          stored ??
          const VitalsDay(
            day: '2026-07-18',
            weightKg: null,
            bodyFatPct: null,
            bpReadings: [],
            glucoseReadings: [],
            spo2Readings: [],
          );

  @override
  Future<VitalsDay> getDay(String idToken, String day) async {
    if (getError != null) throw getError!;
    return stored;
  }

  @override
  Future<VitalsDay> save(String idToken, VitalsDay day) async {
    if (saveError != null) throw saveError!;
    savedDay = day;
    stored = day;
    return day;
  }
}

VitalsController _controller(FakeVitalsRepository repository) =>
    VitalsController(GetVitalsDay(repository), SaveVitalsDay(repository));

Future<VitalsController> _pumpScreen(
  WidgetTester tester, {
  required FakeVitalsRepository repository,
  bool load = true,
  Locale locale = const Locale('en'),
  String day = '2026-07-18',
  DateTime Function() clock = _defaultClock,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final controller = _controller(repository);
  if (load) await controller.load('token', day);
  await tester.pumpWidget(
    l10nTestApp(
      locale: locale,
      home: VitalsScreen(
        controller: controller,
        idToken: 'token',
        day: day,
        clock: clock,
      ),
    ),
  );
  if (load) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return controller;
}

DateTime _defaultClock() => DateTime(2026, 7, 18, 9);

void main() {
  final loc = lookupAppLocalizations(const Locale('en'));

  group('VitalsScreen', () {
    testWidgets('for today shows the today title and today\'s date', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        repository: FakeVitalsRepository(),
        day: '2026-07-18',
        clock: () => DateTime(2026, 7, 18, 9),
      );

      final expectedDate = DateFormat(
        'EEE, MMM d',
        'en',
      ).format(DateTime(2026, 7, 18));

      expect(find.text(loc.vitalsTitle), findsOneWidget);
      expect(find.text(loc.vitalsHistoryTitle), findsNothing);
      expect(find.textContaining(expectedDate), findsOneWidget);
    });

    testWidgets('for a past day shows the history title', (tester) async {
      await _pumpScreen(
        tester,
        repository: FakeVitalsRepository(),
        day: '2026-07-17',
        clock: () => DateTime(2026, 7, 18, 9),
      );

      expect(find.text(loc.vitalsHistoryTitle), findsOneWidget);
      expect(find.text(loc.vitalsTitle), findsNothing);
    });

    testWidgets('the weight field drives setWeight (empty maps to null)', (
      tester,
    ) async {
      final controller = await _pumpScreen(
        tester,
        repository: FakeVitalsRepository(),
      );

      await tester.enterText(
        find.byKey(const Key('vitals-weight-field')),
        '65.5',
      );
      expect(controller.weightKg, 65.5);

      await tester.enterText(find.byKey(const Key('vitals-weight-field')), '');
      // An emptied optional metric is null, NOT 0.
      expect(controller.weightKg, isNull);
    });

    testWidgets(
      'typing a decimal into weight character-by-character keeps the raw '
      'string (72. then 5 -> 72.5, not 72.05)',
      (tester) async {
        final controller = await _pumpScreen(
          tester,
          repository: FakeVitalsRepository(),
        );

        final weight = find.byKey(const Key('vitals-weight-field'));

        // Simulate real per-keystroke typing: after the user has typed "72."
        // the field must still show "72." (not a re-derived "72.0"), so the
        // next digit appends to what's actually on screen.
        await tester.enterText(weight, '72.');
        await tester.pump();
        final shown = tester.widget<TextField>(weight).controller!.text;
        await tester.enterText(weight, '$shown' '5');
        await tester.pump();

        expect(controller.weightKg, 72.5);
      },
    );

    testWidgets(
      'adding readings and saving upserts weight, a BP reading, and a glucose '
      'reading',
      (tester) async {
        final repository = FakeVitalsRepository();
        final controller = await _pumpScreen(tester, repository: repository);

        await tester.enterText(
          find.byKey(const Key('vitals-weight-field')),
          '65.5',
        );

        await tester.tap(find.byKey(const Key('vitals-bp-add')));
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('vitals-bp-systolic-0')),
          '120',
        );
        await tester.enterText(
          find.byKey(const Key('vitals-bp-diastolic-0')),
          '80',
        );

        await tester.tap(find.byKey(const Key('vitals-glucose-add')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('vitals-glucose-before-0')));
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('vitals-glucose-value-0')),
          '95',
        );

        expect(controller.hasUnsavedChanges, isTrue);
        await tester.tap(find.byKey(const Key('vitals-save-button')));
        await tester.pumpAndSettle();

        expect(repository.savedDay!.weightKg, 65.5);
        expect(
          repository.savedDay!.bpReadings.single,
          const BpReading(systolic: 120, diastolic: 80, pulse: null),
        );
        expect(
          repository.savedDay!.glucoseReadings.single,
          GlucoseReading(label: loc.vitalsGlucoseBeforeMeal, value: 95),
        );
      },
    );

    testWidgets('removing a reading drops it from the draft', (tester) async {
      final controller = await _pumpScreen(
        tester,
        repository: FakeVitalsRepository(
          stored: const VitalsDay(
            day: '2026-07-18',
            weightKg: null,
            bodyFatPct: null,
            bpReadings: [BpReading(systolic: 120, diastolic: 80, pulse: 70)],
            glucoseReadings: [],
            spo2Readings: [],
          ),
        ),
      );

      expect(controller.bpReadings, isNotEmpty);
      await tester.tap(find.byKey(const Key('vitals-bp-remove-0')));
      await tester.pump();

      expect(controller.bpReadings, isEmpty);
      expect(find.byKey(const Key('vitals-bp-systolic-0')), findsNothing);
    });

    testWidgets('Save is disabled until there are unsaved edits', (
      tester,
    ) async {
      await _pumpScreen(tester, repository: FakeVitalsRepository());

      expect(find.byKey(const Key('vitals-unsaved-indicator')), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('vitals-save-button')))
            .onPressed,
        isNull,
      );

      await tester.enterText(
        find.byKey(const Key('vitals-weight-field')),
        '60',
      );
      await tester.pump();

      expect(
        find.byKey(const Key('vitals-unsaved-indicator')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('vitals-save-button')))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('a save failure shows a snackbar and keeps the entered values', (
      tester,
    ) async {
      final repository = FakeVitalsRepository();
      final controller = await _pumpScreen(tester, repository: repository);

      await tester.enterText(
        find.byKey(const Key('vitals-weight-field')),
        '70',
      );
      await tester.pump();

      repository.saveError = const VitalsFetchFailure('boom');
      await tester.tap(find.byKey(const Key('vitals-save-button')));
      await tester.pumpAndSettle();

      expect(find.text(loc.vitalsSaveFailed), findsOneWidget);
      // The entered value survives the failed save.
      expect(controller.weightKg, 70);
    });

    testWidgets('renders an error state without crashing', (tester) async {
      await _pumpScreen(
        tester,
        repository: FakeVitalsRepository()
          ..getError = const VitalsFetchFailure('boom'),
      );

      expect(find.text(loc.errorVitalsLoadFailed), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a reauth state without crashing', (tester) async {
      await _pumpScreen(
        tester,
        repository: FakeVitalsRepository()
          ..getError = const VitalsReauthenticationRequired(),
      );

      expect(find.text(loc.pleaseSignInAgain), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows a loading indicator before the first load completes', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        repository: FakeVitalsRepository(),
        load: false,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
