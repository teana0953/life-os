import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/notifications/application/care_items.dart';
import 'package:life_os/contexts/notifications/domain/care_item.dart';
import 'package:life_os/contexts/notifications/presentation/care_item_form.dart';
import 'package:life_os/contexts/notifications/presentation/care_items_controller.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';

class _FakeCareItemRepository implements CareItemRepository {
  List<CareItem> items;
  Object? mutateError;
  CareItemDraft? lastDraft;
  String? lastUpdateId;
  CareItemUpdate? lastUpdate;

  _FakeCareItemRepository({this.items = const []});

  @override
  Future<List<CareItem>> list(String idToken) async => items;

  @override
  Future<CareItem> create(String idToken, CareItemDraft draft) async {
    lastDraft = draft;
    if (mutateError != null) throw mutateError!;
    return CareItem(
      id: 'care-new',
      category: draft.category,
      title: draft.title,
      note: draft.note,
      dose: draft.dose,
      stock: draft.stock,
      stockAlert: draft.stockAlert,
      schedules: draft.schedules,
    );
  }

  @override
  Future<CareItem> update(
    String idToken,
    String id,
    CareItemUpdate update,
  ) async {
    lastUpdateId = id;
    lastUpdate = update;
    if (mutateError != null) throw mutateError!;
    return CareItem(
      id: id,
      category: update.category,
      title: update.title,
      note: update.note,
      dose: update.dose,
      stock: update.stock,
      stockAlert: update.stockAlert,
      schedules: update.schedules,
    );
  }

  @override
  Future<void> delete(String idToken, String id) async {}
}

final _medicationItem = CareItem(
  id: 'care-1',
  category: CareCategory.medication,
  title: 'Metformin',
  note: 'take with food',
  dose: '500mg',
  stock: 30,
  stockAlert: 5,
  schedules: [
    CareSchedule(
      id: 'sch-1',
      timeOfDay: '08:00',
      repeatDays: const [1, 3],
      weekInterval: 2,
      startDate: DateTime(2026, 7, 6),
      doseQuantity: 2,
      nagIntervalMinutes: 10,
      enabled: true,
    ),
  ],
);

CareItemsController _controller({CareItemRepository? repository}) {
  final repo = repository ?? _FakeCareItemRepository();
  return CareItemsController(
    ListCareItems(repo),
    CreateCareItem(repo),
    UpdateCareItem(repo),
    DeleteCareItem(repo),
  );
}

Future<void> _pumpForm(
  WidgetTester tester,
  CareItemsController controller, {
  CareItem? existing,
  Locale locale = const Locale("en"),
}) async {
  // The form's content can exceed the default 800x600 test surface, pushing
  // the submit button below the visible area — a taller surface keeps it
  // reachable without scrolling gymnastics.
  await tester.binding.setSurfaceSize(const Size(800, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    l10nTestApp(
      locale: locale,
      home: CareItemForm(
        controller: controller,
        idToken: () async => 'token-123',
        existing: existing,
        clock: () => DateTime(2026, 7, 22),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _addSchedule(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('care-item-add-schedule')));
  await tester.pumpAndSettle();
  // The Material time picker's OK button.
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  // The form's two pickers were the only ones of the seven routed through
  // `pickTime24h` with nothing asserting the 24-hour format directly. The
  // helper's other call sites are covered ten times over, but a change to
  // *these two* — say a hand-written builder creeping back — would not have
  // been caught here.
  group('CareItemForm time pickers are always 24-hour', () {
    testWidgets('adding a schedule opens a 24-hour picker under a 12-hour locale', (
      tester,
    ) async {
      final controller = _controller();
      await _pumpForm(tester, controller);

      await tester.tap(find.byKey(const Key('care-item-add-schedule')));
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsOneWidget);
      expect(find.text('AM'), findsNothing);
      expect(find.text('PM'), findsNothing);
    });

    testWidgets("changing an existing schedule's time opens a 24-hour picker", (
      tester,
    ) async {
      final controller = _controller();
      await _pumpForm(tester, controller);
      await _addSchedule(tester);

      await tester.tap(find.byKey(const Key('care-item-schedule-time-0')));
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsOneWidget);
      expect(find.text('AM'), findsNothing);
      expect(find.text('PM'), findsNothing);
    });
  });

  group('CareItemForm category', () {
    testWidgets(
      'defaults to medication and shows dose/stock fields; hides them for '
      'a non-medication category',
      (tester) async {
        final controller = _controller();
        await _pumpForm(tester, controller);

        expect(find.byKey(const Key('care-item-dose-field')), findsOneWidget);
        expect(find.byKey(const Key('care-item-stock-field')), findsOneWidget);
        expect(
          find.byKey(const Key('care-item-stock-alert-field')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('care-item-category-chip-rehab')),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('care-item-dose-field')), findsNothing);
        expect(find.byKey(const Key('care-item-stock-field')), findsNothing);
        expect(
          find.byKey(const Key('care-item-stock-alert-field')),
          findsNothing,
        );
      },
    );

    testWidgets('an existing non-medication item hides the medication fields', (
      tester,
    ) async {
      final rehabItem = CareItem(
        id: 'care-2',
        category: CareCategory.rehab,
        title: 'Stretching',
        schedules: const [],
      );
      final controller = _controller();
      await _pumpForm(tester, controller, existing: rehabItem);

      expect(find.byKey(const Key('care-item-dose-field')), findsNothing);
      expect(find.byKey(const Key('care-item-stock-field')), findsNothing);
    });
  });

  group('CareItemForm schedules', () {
    testWidgets('add mode: submit is disabled until a title and a schedule exist', (
      tester,
    ) async {
      final repository = _FakeCareItemRepository();
      final controller = _controller(repository: repository);
      await _pumpForm(tester, controller);

      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('care-item-form-submit')))
            .onPressed,
        isNull,
      );
      expect(
        find.byKey(const Key('care-item-incomplete-hint')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('care-item-title-field')),
        'Metformin',
      );
      await tester.pump();
      // Title alone still isn't enough (no schedule yet).
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('care-item-form-submit')))
            .onPressed,
        isNull,
      );

      await _addSchedule(tester);

      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('care-item-form-submit')))
            .onPressed,
        isNotNull,
      );
      expect(
        find.byKey(const Key('care-item-incomplete-hint')),
        findsNothing,
      );

      await tester.ensureVisible(
        find.byKey(const Key('care-item-form-submit')),
      );
      await tester.tap(find.byKey(const Key('care-item-form-submit')));
      await tester.pumpAndSettle();

      expect(repository.lastDraft, isNotNull);
      expect(repository.lastDraft!.title, 'Metformin');
      expect(repository.lastDraft!.schedules, hasLength(1));
      // Empty weekdays (never toggled) → every day, sent as [].
      expect(repository.lastDraft!.schedules.single.repeatDays, isEmpty);
      // dose_quantity defaults to 1 even though the medication category's
      // per-schedule editor is visible but untouched.
      expect(repository.lastDraft!.schedules.single.doseQuantity, 1);
    });

    testWidgets('removing the only schedule disables submit again', (
      tester,
    ) async {
      final controller = _controller();
      await _pumpForm(tester, controller, existing: _medicationItem);

      // Pre-filled from `existing`: submit should already be enabled.
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('care-item-form-submit')))
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.byKey(const Key('care-item-schedule-remove-0')));
      await tester.pump();

      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('care-item-form-submit')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('toggling a weekday chip on then off leaves it unselected', (
      tester,
    ) async {
      final controller = _controller();
      await _pumpForm(tester, controller, existing: _medicationItem);

      final mondayChip = tester.widget<FilterChip>(
        find.byKey(const Key('care-item-schedule-weekday-chip-0-1')),
      );
      expect(mondayChip.selected, isTrue);

      await tester.tap(
        find.byKey(const Key('care-item-schedule-weekday-chip-0-1')),
      );
      await tester.pump();

      final updatedChip = tester.widget<FilterChip>(
        find.byKey(const Key('care-item-schedule-weekday-chip-0-1')),
      );
      expect(updatedChip.selected, isFalse);
    });

    testWidgets(
      'hides the start-date picker while weekInterval == 1, and shows it '
      'once the interval is raised above 1',
      (tester) async {
        final controller = _controller();
        await _pumpForm(tester, controller);
        await _addSchedule(tester);

        expect(
          find.byKey(const Key('care-item-schedule-start-date-0')),
          findsNothing,
        );

        await tester.tap(
          find.byKey(
            const Key('care-item-schedule-week-interval-increment-0'),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const Key('care-item-schedule-start-date-0')),
          findsOneWidget,
        );
      },
    );

    testWidgets('edit mode with an existing weekInterval > 1 shows the start-date picker', (
      tester,
    ) async {
      final controller = _controller();
      await _pumpForm(tester, controller, existing: _medicationItem);

      expect(
        find.byKey(const Key('care-item-schedule-start-date-0')),
        findsOneWidget,
      );
    });

    testWidgets('adding then removing an end date clears it', (tester) async {
      final controller = _controller();
      await _pumpForm(tester, controller, existing: _medicationItem);

      expect(
        find.byKey(const Key('care-item-schedule-end-date-add-0')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('care-item-schedule-end-date-add-0')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('care-item-schedule-end-date-0')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('care-item-schedule-end-date-remove-0')),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('care-item-schedule-end-date-add-0')),
        findsOneWidget,
      );
    });

    testWidgets(
      'shows a muted hint that leaving all weekday chips unselected means '
      'every day',
      (tester) async {
        final controller = _controller();
        await _pumpForm(tester, controller);
        await _addSchedule(tester);

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.careWeekdaysEmptyHint), findsOneWidget);
      },
    );

    testWidgets(
      'labels the time control and wires the change-time tooltip',
      (tester) async {
        final controller = _controller();
        await _pumpForm(tester, controller);
        await _addSchedule(tester);

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.careTimeLabel), findsOneWidget);

        final tooltip = tester.widget<Tooltip>(
          find.ancestor(
            of: find.byKey(const Key('care-item-schedule-time-0')),
            matching: find.byType(Tooltip),
          ),
        );
        expect(tooltip.message, loc.careChangeTimeTooltip);
      },
    );

    testWidgets(
      'the per-schedule dose quantity field hints 1, matching the value sent '
      'when left empty',
      (tester) async {
        final controller = _controller();
        await _pumpForm(tester, controller, existing: _medicationItem);

        final field = tester.widget<TextField>(
          find.byKey(const Key('care-item-schedule-dose-quantity-0')),
        );
        expect(field.decoration?.hintText, '1');
      },
    );

    testWidgets(
      'zh-Hant week-interval label reads 每週 for =1 and 每 N 週 otherwise',
      (tester) async {
        final controller = _controller();
        await tester.binding.setSurfaceSize(const Size(800, 2000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          l10nTestApp(
            locale: const Locale.fromSubtags(
              languageCode: 'zh',
              scriptCode: 'Hant',
            ),
            home: CareItemForm(
              controller: controller,
              idToken: () async => 'token-123',
              existing: _medicationItem,
              clock: () => DateTime(2026, 7, 22),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final loc = lookupAppLocalizations(
          const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        );
        // _medicationItem's schedule has weekInterval: 2.
        expect(find.text(loc.careWeekIntervalValue(2)), findsOneWidget);
        expect(loc.careWeekIntervalValue(1), '每週');
        expect(loc.careWeekIntervalValue(2), '每 2 週');
      },
    );
  });

  group('CareItemForm submit', () {
    testWidgets('edit mode: submitting calls update with the item\'s id', (
      tester,
    ) async {
      final repository = _FakeCareItemRepository(items: [_medicationItem]);
      final controller = _controller(repository: repository);
      await _pumpForm(tester, controller, existing: _medicationItem);

      await tester.enterText(
        find.byKey(const Key('care-item-title-field')),
        'Metformin XR',
      );
      await tester.ensureVisible(
        find.byKey(const Key('care-item-form-submit')),
      );
      await tester.tap(find.byKey(const Key('care-item-form-submit')));
      await tester.pumpAndSettle();

      expect(repository.lastUpdateId, 'care-1');
      expect(repository.lastUpdate!.title, 'Metformin XR');
      // Existing schedule id round-trips.
      expect(repository.lastUpdate!.schedules.single.id, 'sch-1');
    });

    testWidgets(
      'a mutation failure keeps the form open and shows an inline error',
      (tester) async {
        final repository = _FakeCareItemRepository(items: [_medicationItem])
          ..mutateError = const CareRequestFailed();
        final controller = _controller(repository: repository);
        await _pumpForm(tester, controller, existing: _medicationItem);

        await tester.ensureVisible(
          find.byKey(const Key('care-item-form-submit')),
        );
        await tester.tap(find.byKey(const Key('care-item-form-submit')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('care-item-form-error')), findsOneWidget);
        // Still on the form (didn't pop).
        expect(find.byKey(const Key('care-item-title-field')), findsOneWidget);
      },
    );
  });
}
