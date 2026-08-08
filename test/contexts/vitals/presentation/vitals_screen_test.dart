import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:life_os/contexts/vitals/application/get_vitals_day.dart';
import 'package:life_os/contexts/vitals/application/save_vitals_day.dart';
import 'package:life_os/contexts/vitals/domain/vitals_day.dart';
import 'package:life_os/contexts/vitals/domain/vitals_exceptions.dart';
import 'package:life_os/contexts/vitals/domain/vitals_repository.dart';
import 'package:life_os/contexts/vitals/domain/vitals_series.dart';
import 'package:life_os/contexts/vitals/presentation/vitals_controller.dart';
import 'package:life_os/contexts/vitals/presentation/vitals_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/widgets/last_loaded_label.dart';

import '../../../support/l10n_test_app.dart';

/// A backend-like fake: keeps the last-saved record so save→reload round-trips
/// read back real state.
class FakeVitalsRepository implements VitalsRepository {
  @override
  Future<VitalsRange> getRange(
    String idToken,
    DateTime from,
    DateTime to,
  ) async => VitalsRange(
    from: from,
    to: to,
    series: const VitalsSeries(
      weight: [],
      bodyFat: [],
      waist: [],
      systolic: [],
      diastolic: [],
      pulse: [],
      glucose: [],
      spo2: [],
    ),
  );

  VitalsDay stored;
  Object? getError;
  Object? saveError;

  VitalsDay? savedDay;
  int getDayCallCount = 0;

  /// Every weight [save] was called with, in order — saving the same draft
  /// twice leaves the same state, so only the call list can tell one save from
  /// two.
  final List<num?> saveCalls = [];

  FakeVitalsRepository({VitalsDay? stored})
    : stored =
          stored ??
          const VitalsDay(
            day: '2026-07-18',
            weightKg: null,
            bodyFatPct: null,
            waistCm: null,
            bpReadings: [],
            glucoseReadings: [],
            spo2Readings: [],
          );

  @override
  Future<VitalsDay> getDay(String idToken, String day) async {
    getDayCallCount++;
    if (getError != null) throw getError!;
    return stored;
  }

  @override
  Future<VitalsDay> save(String idToken, VitalsDay day) async {
    saveCalls.add(day.weightKg);
    if (saveError != null) throw saveError!;
    savedDay = day;
    stored = day;
    return day;
  }
}

/// A pinned clock so a newly added reading's default time is deterministic.
TimeOfDay _pinnedClock() => const TimeOfDay(hour: 9, minute: 0);

VitalsController _controller(FakeVitalsRepository repository) =>
    VitalsController(
      GetVitalsDay(repository),
      SaveVitalsDay(repository),
      clock: _pinnedClock,
    );

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
        idToken: () async => 'token',
        day: day,
        clock: clock,
        onSignInAgain: () {},
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

/// Drives an already-open [TimePickerDialog] through its manual
/// keyboard-entry mode: switches from the dial to the two-field text input
/// (the [Icons.keyboard_outlined] toggle), types [hour]/[minute] into the
/// dialog's two `TextField`s, and confirms with OK. Typing an hour like
/// `'21'` is itself part of the proof this recipe exists for: a 12-hour
/// input field would reject it outright, so a regression to a 12-hour
/// picker fails here, not just on the AM/PM-visibility check.
Future<void> _pickViaKeyboardEntry(
  WidgetTester tester, {
  required String hour,
  required String minute,
}) async {
  expect(find.byType(TimePickerDialog), findsOneWidget);

  await tester.tap(find.byIcon(Icons.keyboard_outlined));
  await tester.pumpAndSettle();

  final fields = find.descendant(
    of: find.byType(TimePickerDialog),
    matching: find.byType(TextField),
  );
  await tester.enterText(fields.at(0), hour);
  await tester.enterText(fields.at(1), minute);
  await tester.tap(find.widgetWithText(TextButton, 'OK'));
  await tester.pumpAndSettle();
}

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

    testWidgets('the waist field drives setWaist, and reaches the save payload', (
      tester,
    ) async {
      // Both halves: a field wired to the wrong setter still shows what you
      // typed, and a controller field missing from the save payload still
      // shows the right number until the next reload.
      final repository = FakeVitalsRepository();
      final controller = await _pumpScreen(tester, repository: repository);

      await tester.enterText(find.byKey(const Key('vitals-waist-field')), '78.5');
      expect(controller.waistCm, 78.5);
      // Not the neighbouring scalars — one field wired to the wrong setter is
      // the failure a single-field assertion cannot see.
      expect(controller.weightKg, isNull);
      expect(controller.bodyFatPct, isNull);

      // Scroll first: the form is one field taller now, and a tap on an
      // off-screen target only prints a warning — the failure then lands on
      // the assertion below, looking like a wiring bug.
      await tester.ensureVisible(find.byKey(const Key('vitals-save-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('vitals-save-button')));
      await tester.pumpAndSettle();
      expect(repository.savedDay?.waistCm, 78.5);

      await tester.enterText(find.byKey(const Key('vitals-waist-field')), '');
      // An emptied optional metric is null, NOT 0.
      expect(controller.waistCm, isNull);
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
        await tester.tap(
          find.byKey(const Key('vitals-glucose-context-fasting-0')),
        );
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
          const BpReading(
            systolic: 120,
            diastolic: 80,
            pulse: null,
            time: '09:00',
          ),
        );
        expect(
          repository.savedDay!.glucoseReadings.single,
          const GlucoseReading(
            label: '',
            value: 95,
            mealContext: GlucoseMealContext.fasting,
            time: '09:00',
          ),
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
            waistCm: null,
            bpReadings: [
              BpReading(systolic: 120, diastolic: 80, pulse: 70, time: '08:30'),
            ],
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

    testWidgets('each reading row shows a time control with its HH:mm', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        repository: FakeVitalsRepository(
          stored: const VitalsDay(
            day: '2026-07-18',
            weightKg: null,
            bodyFatPct: null,
            waistCm: null,
            bpReadings: [
              BpReading(systolic: 120, diastolic: 80, pulse: 70, time: '08:30'),
            ],
            glucoseReadings: [
              GlucoseReading(label: '餐前', value: 95, mealContext: null, time: '07:45'),
            ],
            spo2Readings: [Spo2Reading(spo2: 98, pulse: 70, time: '10:00')],
          ),
        ),
      );

      expect(find.byKey(const Key('vitals-bp-time-0')), findsOneWidget);
      expect(find.byKey(const Key('vitals-glucose-time-0')), findsOneWidget);
      expect(find.byKey(const Key('vitals-spo2-time-0')), findsOneWidget);
      expect(find.text('08:30'), findsOneWidget);
      expect(find.text('07:45'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);
    });

    testWidgets('a freshly added reading shows a non-empty current time', (
      tester,
    ) async {
      await _pumpScreen(tester, repository: FakeVitalsRepository());

      await tester.tap(find.byKey(const Key('vitals-bp-add')));
      await tester.pump();

      // The pinned clock (_pinnedClock -> 09:00) makes the default
      // deterministic; the row's time control shows it.
      expect(
        find.descendant(
          of: find.byKey(const Key('vitals-bp-time-0')),
          matching: find.text('09:00'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping a reading\'s time control opens the time picker', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        repository: FakeVitalsRepository(
          stored: const VitalsDay(
            day: '2026-07-18',
            weightKg: null,
            bodyFatPct: null,
            waistCm: null,
            bpReadings: [
              BpReading(systolic: 120, diastolic: 80, pulse: 70, time: '08:30'),
            ],
            glucoseReadings: [],
            spo2Readings: [],
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('vitals-bp-time-0')));
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      "the BP reading's time control is always 24-hour, whatever the "
      "locale — the chip shows the stored HH:mm verbatim, so a 12-hour "
      "picker would have an English-locale user choose '9:30 PM' and then "
      "read it back as '21:30'",
      (tester) async {
        await _pumpScreen(
          tester,
          repository: FakeVitalsRepository(
            stored: const VitalsDay(
              day: '2026-07-18',
              weightKg: null,
              bodyFatPct: null,
              waistCm: null,
              bpReadings: [
                BpReading(systolic: 120, diastolic: 80, pulse: 70, time: '21:30'),
              ],
              glucoseReadings: [],
              spo2Readings: [],
            ),
          ),
          locale: const Locale('en'),
        );

        await tester.tap(find.byKey(const Key('vitals-bp-time-0')));
        await tester.pumpAndSettle();

        expect(find.byType(TimePickerDialog), findsOneWidget);
        // The day-period (AM/PM) control only exists in the 12-hour layout.
        expect(find.text('AM'), findsNothing);
        expect(find.text('PM'), findsNothing);
      },
    );

    testWidgets(
      "the glucose reading's time control is always 24-hour, whatever the "
      "locale — the chip shows the stored HH:mm verbatim, so a 12-hour "
      "picker would have an English-locale user choose '9:30 PM' and then "
      "read it back as '21:30'",
      (tester) async {
        await _pumpScreen(
          tester,
          repository: FakeVitalsRepository(
            stored: const VitalsDay(
              day: '2026-07-18',
              weightKg: null,
              bodyFatPct: null,
              waistCm: null,
              bpReadings: [],
              glucoseReadings: [
                GlucoseReading(label: '餐前', value: 95, mealContext: null, time: '21:30'),
              ],
              spo2Readings: [],
            ),
          ),
          locale: const Locale('en'),
        );

        await tester.tap(find.byKey(const Key('vitals-glucose-time-0')));
        await tester.pumpAndSettle();

        expect(find.byType(TimePickerDialog), findsOneWidget);
        expect(find.text('AM'), findsNothing);
        expect(find.text('PM'), findsNothing);
      },
    );

    testWidgets(
      "the SpO2 reading's time control is always 24-hour, whatever the "
      "locale — the chip shows the stored HH:mm verbatim, so a 12-hour "
      "picker would have an English-locale user choose '9:30 PM' and then "
      "read it back as '21:30'",
      (tester) async {
        await _pumpScreen(
          tester,
          repository: FakeVitalsRepository(
            stored: const VitalsDay(
              day: '2026-07-18',
              weightKg: null,
              bodyFatPct: null,
              waistCm: null,
              bpReadings: [],
              glucoseReadings: [],
              spo2Readings: [Spo2Reading(spo2: 98, pulse: 70, time: '21:30')],
            ),
          ),
          locale: const Locale('en'),
        );

        await tester.tap(find.byKey(const Key('vitals-spo2-time-0')));
        await tester.pumpAndSettle();

        expect(find.byType(TimePickerDialog), findsOneWidget);
        expect(find.text('AM'), findsNothing);
        expect(find.text('PM'), findsNothing);
      },
    );

    testWidgets(
      "picking 21:30 for the BP reading via keyboard entry round-trips "
      "21:30 onto the chip — not 09:30 — proving the picked value survives "
      "the trip back to the screen unmangled, not just that the dialog was "
      "24-hour",
      (tester) async {
        await _pumpScreen(
          tester,
          repository: FakeVitalsRepository(
            stored: const VitalsDay(
              day: '2026-07-18',
              weightKg: null,
              bodyFatPct: null,
              waistCm: null,
              bpReadings: [
                BpReading(systolic: 120, diastolic: 80, pulse: 70, time: '09:00'),
              ],
              glucoseReadings: [],
              spo2Readings: [],
            ),
          ),
          locale: const Locale('en'),
        );

        await tester.tap(find.byKey(const Key('vitals-bp-time-0')));
        await tester.pumpAndSettle();
        await _pickViaKeyboardEntry(tester, hour: '21', minute: '30');

        expect(find.text('21:30'), findsOneWidget);
        // The seeded value must be gone — a pick that never reached the chip
        // would leave it on screen.
        expect(find.text('09:00'), findsNothing);
      },
    );

    testWidgets(
      "picking 21:30 for the glucose reading via keyboard entry round-trips "
      "21:30 onto the chip — not 09:30 — proving the picked value survives "
      "the trip back to the screen unmangled, not just that the dialog was "
      "24-hour",
      (tester) async {
        await _pumpScreen(
          tester,
          repository: FakeVitalsRepository(
            stored: const VitalsDay(
              day: '2026-07-18',
              weightKg: null,
              bodyFatPct: null,
              waistCm: null,
              bpReadings: [],
              glucoseReadings: [
                GlucoseReading(label: '餐前', value: 95, mealContext: null, time: '09:00'),
              ],
              spo2Readings: [],
            ),
          ),
          locale: const Locale('en'),
        );

        await tester.tap(find.byKey(const Key('vitals-glucose-time-0')));
        await tester.pumpAndSettle();
        await _pickViaKeyboardEntry(tester, hour: '21', minute: '30');

        expect(find.text('21:30'), findsOneWidget);
        // The seeded value must be gone — a pick that never reached the chip
        // would leave it on screen.
        expect(find.text('09:00'), findsNothing);
      },
    );

    testWidgets(
      "picking 9:05 for the SpO2 reading via keyboard entry round-trips "
      "'09:05' onto the chip — both components zero-padded, proving the "
      "picked value survives the trip back to the screen unmangled. 9:05 "
      "rather than 21:30 on purpose: 21:30 is padding-insensitive, so with "
      "it alone a broken _zeroPad (which writes the backend's strict ASCII "
      "HH:mm) goes unnoticed by the whole suite",
      (tester) async {
        await _pumpScreen(
          tester,
          repository: FakeVitalsRepository(
            stored: const VitalsDay(
              day: '2026-07-18',
              weightKg: null,
              bodyFatPct: null,
              waistCm: null,
              bpReadings: [],
              glucoseReadings: [],
              spo2Readings: [Spo2Reading(spo2: 98, pulse: 70, time: '21:30')],
            ),
          ),
          locale: const Locale('en'),
        );

        await tester.tap(find.byKey(const Key('vitals-spo2-time-0')));
        await tester.pumpAndSettle();
        // Unlike the 21:30 round trips, a 9:05 pick is accepted by a 12-hour
        // dialog too, so this test needs its own 24-hour check to keep
        // reddening on a lost `alwaysUse24HourFormat`.
        expect(find.text('AM'), findsNothing);
        expect(find.text('PM'), findsNothing);
        await _pickViaKeyboardEntry(tester, hour: '9', minute: '5');

        expect(find.text('09:05'), findsOneWidget);
        // The seeded value must be gone — a pick that never reached the chip
        // would leave it on screen.
        expect(find.text('21:30'), findsNothing);
      },
    );

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

    for (final width in const [320.0, 360.0]) {
      for (final locale in testSupportedLocales) {
        testWidgets(
          'BP/glucose/spo2 rows do not overflow at ${width.toInt()}dp '
          '(${locale.toLanguageTag()})',
          (tester) async {
            await tester.binding.setSurfaceSize(Size(width, 1600));
            addTearDown(() => tester.binding.setSurfaceSize(null));

            final controller = _controller(
              FakeVitalsRepository(
                stored: const VitalsDay(
                  day: '2026-07-18',
                  weightKg: 65.5,
                  bodyFatPct: 20,
                  waistCm: null,
                  bpReadings: [
                    BpReading(
                      systolic: 120,
                      diastolic: 80,
                      pulse: 70,
                      time: '08:30',
                    ),
                  ],
                  glucoseReadings: [
                    GlucoseReading(label: '餐前', value: 95, mealContext: null, time: '07:45'),
                  ],
                  spo2Readings: [
                    Spo2Reading(spo2: 98, pulse: 70, time: '10:00'),
                  ],
                ),
              ),
            );
            await controller.load('token', '2026-07-18');
            await tester.pumpWidget(
              l10nTestApp(
                locale: locale,
                home: VitalsScreen(
                  controller: controller,
                  idToken: () async => 'token',
                  day: '2026-07-18',
                  clock: _defaultClock,
                  onSignInAgain: () {},
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            // The scroll body is a Column, whose cross-axis default is CENTRE —
            // the full-width sizing children used to get from the sliver comes
            // from an explicit `stretch`. Drop it and this button silently
            // shrinks to its content, with no overflow to give it away.
            expect(
              tester.getSize(find.byKey(const Key('vitals-save-button'))).width,
              width - 40, // the scroll body's 20dp padding on each side
            );
          },
        );
      }
    }
  });

  group('VitalsScreen pull-to-refresh', () {
    testWidgets('the scroll body is always scrollable so a short day pulls', (
      tester,
    ) async {
      await _pumpScreen(tester, repository: FakeVitalsRepository());

      expect(find.byType(RefreshIndicator), findsOneWidget);
      final scrollable = tester.widget<SingleChildScrollView>(
        find.descendant(
          of: find.byType(RefreshIndicator),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      expect(scrollable.physics, isA<AlwaysScrollableScrollPhysics>());
    });

    testWidgets('with no unsaved edits, pulling reloads without a prompt', (
      tester,
    ) async {
      final repository = FakeVitalsRepository();
      await _pumpScreen(tester, repository: repository);
      final before = repository.getDayCallCount;

      await tester.fling(
        find.byType(RefreshIndicator),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text(loc.refreshDiscardTitle), findsNothing);
      expect(repository.getDayCallCount, before + 1);
    });

    testWidgets(
      'with unsaved edits, pulling asks first and cancelling keeps the draft '
      '(no reload)',
      (tester) async {
        final repository = FakeVitalsRepository();
        final controller = await _pumpScreen(tester, repository: repository);

        controller.setWeight(70);
        await tester.pump();
        expect(controller.hasUnsavedChanges, isTrue);
        final before = repository.getDayCallCount;

        await tester.fling(
          find.byType(RefreshIndicator),
          const Offset(0, 300),
          1000,
        );
        // Not pumpAndSettle: the RefreshIndicator spinner animates until its
        // onRefresh future resolves, which is gated on this dialog — so settle
        // would time out. Pump enough frames to surface the dialog instead.
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // The confirm dialog is up; cancelling keeps the draft and reloads
        // nothing.
        expect(find.text(loc.refreshDiscardTitle), findsOneWidget);
        await tester.tap(find.text(loc.cancel));
        await tester.pumpAndSettle();

        expect(controller.weightKg, 70);
        expect(controller.hasUnsavedChanges, isTrue);
        expect(repository.getDayCallCount, before);
      },
    );

    testWidgets(
      'with unsaved edits, confirming the discard reloads and drops the draft',
      (tester) async {
        final repository = FakeVitalsRepository();
        final controller = await _pumpScreen(tester, repository: repository);

        controller.setWeight(70);
        await tester.pump();
        final before = repository.getDayCallCount;

        await tester.fling(
          find.byType(RefreshIndicator),
          const Offset(0, 300),
          1000,
        );
        // See the cancel test: the spinner won't settle while the dialog is
        // open, so pump frames rather than settle.
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        await tester.tap(find.text(loc.discard));
        await tester.pumpAndSettle();

        expect(repository.getDayCallCount, before + 1);
        // The reload reset the draft to the stored (empty) record.
        expect(controller.weightKg, isNull);
        expect(controller.hasUnsavedChanges, isFalse);
      },
    );

    testWidgets('shows the controller\'s last-loaded time', (tester) async {
      final repository = FakeVitalsRepository();
      final controller = VitalsController(
        GetVitalsDay(repository),
        SaveVitalsDay(repository),
        clock: _pinnedClock,
        loadClock: () => DateTime(2026, 7, 18, 9, 41),
      );
      await controller.load('token', '2026-07-18');
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        l10nTestApp(
          home: VitalsScreen(
            controller: controller,
            idToken: () async => 'token',
            day: '2026-07-18',
            clock: _defaultClock,
            onSignInAgain: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final label = tester.widget<LastLoadedLabel>(
        find.byType(LastLoadedLabel),
      );
      expect(label.lastLoadedAt, DateTime(2026, 7, 18, 9, 41));
    });
  });

  group('VitalsScreen autoAddSection (PWA shortcut)', () {
    /// Pumps the screen with an [autoAddSection], returning the controller.
    /// The surface is tall so the mid-list glucose section is actually built.
    Future<VitalsController> pumpAuto(
      WidgetTester tester, {
      required String? autoAddSection,
      bool load = true,
      VitalsController? controller,
      FakeVitalsRepository? repository,
      // Tall by default so every section is on screen; a phone-sized override
      // is what exposes a lazily-built scroll body.
      Size surfaceSize = const Size(800, 1600),
    }) async {
      await tester.binding.setSurfaceSize(surfaceSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final c = controller ?? _controller(repository ?? FakeVitalsRepository());
      if (load) await c.load('token', '2026-07-18');
      await tester.pumpWidget(
        l10nTestApp(
          home: VitalsScreen(
            controller: c,
            idToken: () async => 'token',
            day: '2026-07-18',
            clock: _defaultClock,
            autoAddSection: autoAddSection,
            onSignInAgain: () {},
          ),
        ),
      );
      if (load) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump();
      }
      return c;
    }

    testWidgets('arriving already loaded still adds the glucose reading', (
      tester,
    ) async {
      // The common case for an already-running PWA: the day loaded long ago,
      // so a listener-only implementation would never fire.
      final controller = await pumpAuto(tester, autoAddSection: 'glucose');

      expect(controller.glucoseReadings, hasLength(1));
      expect(find.byKey(const Key('vitals-glucose-value-0')), findsOneWidget);
    });

    testWidgets(
      'a reading added while still loading survives the arriving record',
      (tester) async {
        // Adding into a screen that is about to be overwritten by
        // `_applyRecord` would silently lose the row.
        final repository = FakeVitalsRepository();
        final controller = await pumpAuto(
          tester,
          autoAddSection: 'glucose',
          load: false,
          repository: repository,
        );
        expect(controller.glucoseReadings, isEmpty);

        await controller.load('token', '2026-07-18');
        await tester.pumpAndSettle();

        expect(controller.glucoseReadings, hasLength(1));
      },
    );

    testWidgets('adds exactly one reading — the flag is set before the add', (
      tester,
    ) async {
      // `addGlucoseReading` notifies synchronously and so re-enters the
      // controller listener; a flag set after the add recurses forever.
      final controller = await pumpAuto(tester, autoAddSection: 'glucose');

      expect(controller.glucoseReadings, hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('rebuilding the screen does not add more readings', (
      tester,
    ) async {
      final controller = await pumpAuto(tester, autoAddSection: 'glucose');
      expect(controller.glucoseReadings, hasLength(1));

      // Any other state change: a keystroke in an unrelated field.
      await tester.enterText(
        find.byKey(const Key('vitals-weight-field')),
        '61',
      );
      await tester.pumpAndSettle();

      expect(controller.glucoseReadings, hasLength(1));
    });

    testWidgets('the blood-pressure shortcut adds a blood-pressure reading', (
      tester,
    ) async {
      final controller = await pumpAuto(tester, autoAddSection: 'bp');

      expect(controller.bpReadings, hasLength(1));
      expect(controller.glucoseReadings, isEmpty);
    });

    testWidgets('arriving with no shortcut adds nothing', (tester) async {
      final controller = await pumpAuto(tester, autoAddSection: null);

      expect(controller.bpReadings, isEmpty);
      expect(controller.glucoseReadings, isEmpty);
      expect(controller.spo2Readings, isEmpty);
    });

    testWidgets('an unrecognised kind adds nothing and does not fail', (
      tester,
    ) async {
      final controller = await pumpAuto(tester, autoAddSection: 'weight');

      expect(controller.bpReadings, isEmpty);
      expect(controller.glucoseReadings, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'switching from the glucose shortcut to the bp one adds the bp reading '
      'without re-adding the glucose one',
      (tester) async {
        // go_router's pageKey is the route TEMPLATE (`/health/:name`) — no
        // query, no name — so the two shortcuts land on the SAME State and
        // only `didUpdateWidget` runs. The controller is loaded by then and
        // will never notify again, so merely resetting the flag would do
        // nothing at all.
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = _controller(FakeVitalsRepository());
        await controller.load('token', '2026-07-18');

        Widget app(String? section) => l10nTestApp(
          home: VitalsScreen(
            controller: controller,
            idToken: () async => 'token',
            day: '2026-07-18',
            clock: _defaultClock,
            autoAddSection: section,
            onSignInAgain: () {},
          ),
        );

        await tester.pumpWidget(app('glucose'));
        await tester.pumpAndSettle();
        expect(controller.glucoseReadings, hasLength(1));

        await tester.pumpWidget(app('bp'));
        await tester.pumpAndSettle();

        expect(controller.bpReadings, hasLength(1));
        expect(controller.glucoseReadings, hasLength(1));
      },
    );

    testWidgets(
      'a shortcut arriving while the day-nav is on a past day records TODAY, '
      'not the browsed day',
      (tester) async {
        // This State survives the navigation (the pageKey is the route
        // template), so `viewedDay` can still be on a browsed past day — and
        // `_save` writes `viewedDay`. Without the switch-back, the user taps
        // "record glucose", types a number, saves, and it lands on yesterday.
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = FakeVitalsRepository();
        final controller = _controller(repository);
        await controller.load('token', '2026-07-18');

        Widget app(String? section) => l10nTestApp(
          home: VitalsScreen(
            controller: controller,
            idToken: () async => 'token',
            day: '2026-07-18',
            clock: _defaultClock,
            autoAddSection: section,
            onSignInAgain: () {},
          ),
        );

        await tester.pumpWidget(app(null));
        await tester.pumpAndSettle();
        // Browse to the 17th. An ordinary visit must be free to do this.
        await tester.tap(find.byKey(const Key('day-nav-previous')));
        await tester.pumpAndSettle();
        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.vitalsHistoryTitle), findsOneWidget);

        await tester.pumpWidget(app('glucose'));
        await tester.pumpAndSettle();

        expect(controller.glucoseReadings, hasLength(1));
        // The day the write actually goes to — not merely what the header says.
        await tester.tap(find.byKey(const Key('vitals-save-button')));
        await tester.pumpAndSettle();
        expect(repository.savedDay!.day, '2026-07-18');
      },
    );

    testWidgets('activating the same shortcut again adds nothing', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = _controller(FakeVitalsRepository());
      await controller.load('token', '2026-07-18');

      Widget app() => l10nTestApp(
        home: VitalsScreen(
          controller: controller,
          idToken: () async => 'token',
          day: '2026-07-18',
          clock: _defaultClock,
          autoAddSection: 'glucose',
          onSignInAgain: () {},
        ),
      );

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(controller.glucoseReadings, hasLength(1));
    });

    testWidgets(
      'the glucose shortcut focuses the VALUE field, not the free-text label',
      (tester) async {
        await pumpAuto(tester, autoAddSection: 'glucose');

        final value = tester.widget<TextField>(
          find.byKey(const Key('vitals-glucose-value-0')),
        );
        expect(value.focusNode?.hasFocus, isTrue);
        // Asserting the label field's own `focusNode.hasFocus` proves nothing:
        // `_RowTextField` takes no focusNode, so its TextField.focusNode is
        // always null and `?? false` would pass even if focus HAD gone there.
        // Compare against the one focus the framework actually holds.
        expect(
          FocusManager.instance.primaryFocus,
          same(value.focusNode),
        );
      },
    );

    testWidgets(
      'the shortcut still focuses when earlier readings push the section past '
      'the fold on a phone-sized screen',
      (tester) async {
        // The scroll body must not be lazily built: with a few readings already
        // logged, a `ListView`'s delegate never builds the glucose section, so
        // `_autoAddRowKey.currentContext` is null and BOTH the focus and the
        // scroll-into-view silently do nothing — the user taps "record
        // glucose" and nothing appears to happen. The other shortcut tests all
        // use 800x1600, which hides this entirely.
        final repository = FakeVitalsRepository(
          stored: const VitalsDay(
            day: '2026-07-18',
            weightKg: 72.5,
            bodyFatPct: 22.0,
            waistCm: null,
            bpReadings: [
              BpReading(systolic: 120, diastolic: 80, pulse: 70, time: '08:30'),
              BpReading(systolic: 118, diastolic: 78, pulse: 68, time: '12:30'),
              BpReading(systolic: 122, diastolic: 82, pulse: 72, time: '18:30'),
            ],
            glucoseReadings: [],
            spo2Readings: [],
          ),
        );
        final controller = await pumpAuto(
          tester,
          autoAddSection: 'glucose',
          repository: repository,
          surfaceSize: const Size(360, 640),
        );

        expect(controller.glucoseReadings, hasLength(1));
        final value = tester.widget<TextField>(
          find.byKey(const Key('vitals-glucose-value-0')),
        );
        expect(FocusManager.instance.primaryFocus, same(value.focusNode));
      },
    );

    testWidgets('the bp shortcut focuses the systolic field', (tester) async {
      await pumpAuto(tester, autoAddSection: 'bp');

      final systolic = tester.widget<TextField>(
        find.byKey(const Key('vitals-bp-systolic-0')),
      );
      expect(systolic.focusNode?.hasFocus, isTrue);
    });

    testWidgets('neither error nor needsReauth adds a reading', (tester) async {
      final repository = FakeVitalsRepository()
        ..getError = const VitalsFetchFailure('boom');
      final controller = await pumpAuto(
        tester,
        autoAddSection: 'glucose',
        repository: repository,
      );

      expect(controller.status, VitalsStatus.error);
      expect(controller.glucoseReadings, isEmpty);
    });

    testWidgets('needsReauth adds no reading either', (tester) async {
      // The case above only ever drove `error`; a 401 is the other terminal
      // state `_maybeAutoAdd` has to refuse, and it takes a different branch
      // in the controller.
      final repository = FakeVitalsRepository()
        ..getError = const VitalsReauthenticationRequired();
      final controller = await pumpAuto(
        tester,
        autoAddSection: 'glucose',
        repository: repository,
      );

      expect(controller.status, VitalsStatus.needsReauth);
      expect(controller.glucoseReadings, isEmpty);
    });
  });

  // The ID token is resolved at request time, so between the tap and the
  // controller's `saving` status there is a whole token round trip during which
  // nothing in the controller has changed yet. That window has to be closed by
  // the screen itself, or a second tap starts a second write.
  group('while the ID token is still resolving', () {
    /// Pumps a loaded screen with one unsaved edit (so Save is enabled) and a
    /// token provider held open by [gate].
    Future<void> pumpGatedTokenWithEdit(
      WidgetTester tester,
      FakeVitalsRepository repository,
      Completer<void> gate,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = _controller(repository);
      await controller.load('token', '2026-07-18');
      await tester.pumpWidget(
        l10nTestApp(
          home: VitalsScreen(
            controller: controller,
            idToken: () async {
              await gate.future;
              return 'token';
            },
            day: '2026-07-18',
            clock: _defaultClock,
            onSignInAgain: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('vitals-weight-field')),
        '60',
      );
      await tester.pump();
    }

    // Two taps inside one frame: the disable only takes effect on the next
    // rebuild, so the second tap still reaches the enabled button and only the
    // re-entrancy check in `_save` can drop it.
    testWidgets('a same-frame second Save tap writes only once', (tester) async {
      final repository = FakeVitalsRepository();
      final gate = Completer<void>();
      await pumpGatedTokenWithEdit(tester, repository, gate);

      await tester.tap(find.byKey(const Key('vitals-save-button')));
      await tester.tap(find.byKey(const Key('vitals-save-button')));

      gate.complete();
      await tester.pumpAndSettle();

      expect(repository.saveCalls, [60]);
    });

    // The visible half: the button disables and the busy bar appears during
    // token resolution, not only once the controller reaches `saving` — so a
    // later tap can't land either.
    testWidgets(
      'the Save button is disabled, the busy bar shows, and a later tap '
      'writes nothing more',
      (tester) async {
        final repository = FakeVitalsRepository();
        final gate = Completer<void>();
        await pumpGatedTokenWithEdit(tester, repository, gate);

        await tester.tap(find.byKey(const Key('vitals-save-button')));
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('vitals-save-button')))
              .onPressed,
          isNull,
        );
        expect(find.byKey(const Key('vitals-busy')), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('vitals-save-button')),
          warnIfMissed: false,
        );
        await tester.pump();

        gate.complete();
        await tester.pumpAndSettle();

        expect(repository.saveCalls, [60]);
      },
    );
  });
}
