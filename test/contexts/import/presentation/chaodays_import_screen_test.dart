import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/import/application/import_bowel.dart';
import 'package:life_os/contexts/import/application/import_diet.dart';
import 'package:life_os/contexts/import/application/import_diet_target.dart';
import 'package:life_os/contexts/import/application/import_water.dart';
import 'package:life_os/contexts/import/application/import_weight.dart';
import 'package:life_os/contexts/import/domain/chaodays_import_summary.dart';
import 'package:life_os/contexts/import/domain/import_exceptions.dart';
import 'package:life_os/contexts/import/domain/import_repository.dart';
import 'package:life_os/contexts/import/presentation/chaodays_import_controller.dart';
import 'package:life_os/contexts/import/presentation/chaodays_import_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/data_revision.dart';

import '../../../support/l10n_test_app.dart';

class _FakeImportRepository implements ImportRepository {
  final List<String> calls = [];
  String? capturedUid;
  String? capturedPassword;
  String? capturedStart;
  String? capturedEnd;

  Object? weightError;

  ChaodaysImportSummary weightSummary = const ChaodaysImportSummary(
    imported: 1,
    skipped: 0,
  );
  ChaodaysImportSummary dietSummary = const ChaodaysImportSummary(
    imported: 2,
    skipped: 1,
    glucoseImported: 3,
  );
  ChaodaysImportSummary waterSummary = const ChaodaysImportSummary(
    imported: 4,
    skipped: 0,
  );
  ChaodaysImportSummary bowelSummary = const ChaodaysImportSummary(
    imported: 5,
    skipped: 2,
  );
  ChaodaysImportSummary dietTargetSummary = const ChaodaysImportSummary(
    imported: 6,
    skipped: 1,
    waterTargetsImported: 7,
  );

  void _capture(String chaodaysUid, String chaodaysPassword, String startDate, String endDate) {
    capturedUid = chaodaysUid;
    capturedPassword = chaodaysPassword;
    capturedStart = startDate;
    capturedEnd = endDate;
  }

  @override
  Future<ChaodaysImportSummary> importWeight(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) async {
    calls.add('weight');
    _capture(chaodaysUid, chaodaysPassword, startDate, endDate);
    if (weightError != null) throw weightError!;
    return weightSummary;
  }

  @override
  Future<ChaodaysImportSummary> importDiet(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) async {
    calls.add('diet');
    return dietSummary;
  }

  @override
  Future<ChaodaysImportSummary> importWater(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) async {
    calls.add('water');
    return waterSummary;
  }

  @override
  Future<ChaodaysImportSummary> importBowel(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) async {
    calls.add('bowel');
    return bowelSummary;
  }

  @override
  Future<ChaodaysImportSummary> importDietTarget(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) async {
    calls.add('dietTarget');
    return dietTargetSummary;
  }
}

/// An import repository whose `importWeight` never resolves, so a submitted
/// import stays in the importing state for the duration of a test (mirrors
/// `login_screen_test.dart`'s `HangingAuthRepository`).
class _HangingImportRepository implements ImportRepository {
  final Completer<ChaodaysImportSummary> weightCompleter =
      Completer<ChaodaysImportSummary>();

  @override
  Future<ChaodaysImportSummary> importWeight(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) => weightCompleter.future;

  @override
  Future<ChaodaysImportSummary> importDiet(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) async => const ChaodaysImportSummary(imported: 0, skipped: 0);

  @override
  Future<ChaodaysImportSummary> importWater(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) async => const ChaodaysImportSummary(imported: 0, skipped: 0);

  @override
  Future<ChaodaysImportSummary> importBowel(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) async => const ChaodaysImportSummary(imported: 0, skipped: 0);

  @override
  Future<ChaodaysImportSummary> importDietTarget(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) async => const ChaodaysImportSummary(imported: 0, skipped: 0);
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> idToken() async => 'fake-token';

  @override
  Stream<bool> get authStateChanges => const Stream.empty();
}

ChaodaysImportController _controller(ImportRepository repository) =>
    ChaodaysImportController(
      ImportWeight(repository),
      ImportDiet(repository),
      ImportWater(repository),
      ImportBowel(repository),
      ImportDietTarget(repository),
      DataRevision(),
    );

DateTime _defaultClock() => DateTime(2026, 7, 20, 9);

Future<void> _pumpScreen(
  WidgetTester tester, {
  required ChaodaysImportController controller,
  AuthRepository? authRepository,
  DateTime Function() clock = _defaultClock,
  Locale locale = const Locale('en'),
}) async {
  await tester.binding.setSurfaceSize(const Size(600, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    l10nTestApp(
      locale: locale,
      home: ChaodaysImportScreen(
        controller: controller,
        authRepository: authRepository ?? _FakeAuthRepository(),
        clock: clock,
      ),
    ),
  );
  await tester.pump();
}

/// Fills the account/password fields and picks a start (5th) and end (10th)
/// date of the clock's current month, mirroring the menstrual screen tests'
/// date-picker interaction.
Future<void> _fillCompleteForm(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('import-account-field')), 'user1');
  await tester.enterText(find.byKey(const Key('import-password-field')), 'pass1');

  await tester.tap(find.byKey(const Key('import-start-date')));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(of: find.byType(DatePickerDialog), matching: find.text('5')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('import-end-date')));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(of: find.byType(DatePickerDialog), matching: find.text('10')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Finder _rowFor(ImportType type) => find.byKey(Key('import-type-row-${type.name}'));

Finder _checkboxFor(ImportType type) =>
    find.descendant(of: _rowFor(type), matching: find.byType(Checkbox));

/// Unchecks every type except [keep] (nothing is kept when it is null).
Future<void> _selectOnly(WidgetTester tester, {ImportType? keep}) async {
  for (final type in ImportType.values.where((t) => t != keep)) {
    await tester.tap(_checkboxFor(type));
    await tester.pump();
  }
}

void main() {
  final loc = lookupAppLocalizations(const Locale('en'));

  group('ChaodaysImportScreen', () {
    testWidgets('shows the account, password, and date fields, and the submit button', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        controller: _controller(_FakeImportRepository()),
      );

      expect(find.byKey(const Key('import-account-field')), findsOneWidget);
      expect(find.byKey(const Key('import-password-field')), findsOneWidget);
      expect(find.byKey(const Key('import-start-date')), findsOneWidget);
      expect(find.byKey(const Key('import-end-date')), findsOneWidget);
      expect(find.byKey(const Key('import-submit-button')), findsOneWidget);
      expect(find.text(loc.importCredentialsNote), findsOneWidget);

      final passwordField = tester.widget<TextField>(
        find.byKey(const Key('import-password-field')),
      );
      expect(passwordField.obscureText, isTrue);
    });

    testWidgets('the submit button is disabled until the form is complete', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        controller: _controller(_FakeImportRepository()),
      );

      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('import-submit-button')))
            .onPressed,
        isNull,
      );

      await _fillCompleteForm(tester);

      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('import-submit-button')))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('submitting a complete form calls import with the entered values', (
      tester,
    ) async {
      final repository = _FakeImportRepository();
      await _pumpScreen(tester, controller: _controller(repository));

      await _fillCompleteForm(tester);
      await tester.tap(find.byKey(const Key('import-submit-button')));
      await tester.pumpAndSettle();

      expect(repository.calls, ['weight', 'diet', 'water', 'bowel', 'dietTarget']);
      expect(repository.capturedUid, 'user1');
      expect(repository.capturedPassword, 'pass1');
      expect(repository.capturedStart, '2026-07-05');
      expect(repository.capturedEnd, '2026-07-10');
    });

    testWidgets('shows a loading state while importing and re-disables the button', (
      tester,
    ) async {
      final repository = _HangingImportRepository();
      final controller = ChaodaysImportController(
        ImportWeight(repository),
        ImportDiet(repository),
        ImportWater(repository),
        ImportBowel(repository),
        ImportDietTarget(repository),
        DataRevision(),
      );
      await _pumpScreen(tester, controller: controller);

      await _fillCompleteForm(tester);
      await tester.tap(find.byKey(const Key('import-submit-button')));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('import-submit-button')))
            .onPressed,
        isNull,
      );

      repository.weightCompleter.complete(
        const ChaodaysImportSummary(imported: 0, skipped: 0),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('a successful import shows each type\'s imported/skipped count', (
      tester,
    ) async {
      final repository = _FakeImportRepository();
      await _pumpScreen(tester, controller: _controller(repository));

      await _fillCompleteForm(tester);
      await tester.tap(find.byKey(const Key('import-submit-button')));
      await tester.pumpAndSettle();

      expect(find.text(loc.importResultSummary(1, 0)), findsOneWidget);
      expect(
        find.text(
          '${loc.importResultSummary(2, 1)}${loc.importResultGlucoseSuffix(3)}',
        ),
        findsOneWidget,
      );
      expect(find.text(loc.importResultSummary(4, 0)), findsOneWidget);
      expect(find.text(loc.importResultSummary(5, 2)), findsOneWidget);
      expect(find.text(loc.importTypeDietTarget), findsOneWidget);
      expect(
        find.text(
          '${loc.importResultSummary(6, 1)}${loc.importResultWaterTargetSuffix(7)}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('wrong chaodays credentials show the specific error message', (
      tester,
    ) async {
      final repository = _FakeImportRepository()
        ..weightError = const ImportChaodaysAuthFailed();
      await _pumpScreen(tester, controller: _controller(repository));

      await _fillCompleteForm(tester);
      await tester.tap(find.byKey(const Key('import-submit-button')));
      await tester.pumpAndSettle();

      expect(find.text(loc.importErrorAuthFailed), findsOneWidget);
      expect(find.text(loc.importErrorUnavailable), findsNothing);
      // The account/password fields are still there to correct and retry.
      expect(find.byKey(const Key('import-account-field')), findsOneWidget);
    });

    testWidgets('chaodays being unreachable shows a distinct message', (
      tester,
    ) async {
      final repository = _FakeImportRepository()
        ..weightError = const ImportChaodaysUnavailable();
      await _pumpScreen(tester, controller: _controller(repository));

      await _fillCompleteForm(tester);
      await tester.tap(find.byKey(const Key('import-submit-button')));
      await tester.pumpAndSettle();

      expect(find.text(loc.importErrorUnavailable), findsOneWidget);
      expect(find.text(loc.importErrorAuthFailed), findsNothing);
    });

    testWidgets('a lifeos 401 shows a re-authenticate prompt', (tester) async {
      final repository = _FakeImportRepository()
        ..weightError = const ImportReauthenticationRequired();
      await _pumpScreen(tester, controller: _controller(repository));

      await _fillCompleteForm(tester);
      await tester.tap(find.byKey(const Key('import-submit-button')));
      await tester.pumpAndSettle();

      expect(find.text(loc.pleaseSignInAgain), findsOneWidget);
    });
  });

  group('ChaodaysImportScreen type selection', () {
    testWidgets('every type is selected on first build', (tester) async {
      await _pumpScreen(tester, controller: _controller(_FakeImportRepository()));

      expect(find.byType(Checkbox), findsNWidgets(ImportType.values.length));
      for (final type in ImportType.values) {
        expect(tester.widget<Checkbox>(_checkboxFor(type)).value, isTrue);
      }
    });

    testWidgets('tapping anywhere on a row toggles its selection', (
      tester,
    ) async {
      await _pumpScreen(tester, controller: _controller(_FakeImportRepository()));

      // The label, not the 48px checkbox box — that is what the user aims at.
      await tester.tap(
        find.descendant(
          of: _rowFor(ImportType.water),
          matching: find.text(loc.importTypeWater),
        ),
      );
      await tester.pump();

      expect(tester.widget<Checkbox>(_checkboxFor(ImportType.water)).value, isFalse);
      expect(tester.widget<Checkbox>(_checkboxFor(ImportType.diet)).value, isTrue);
    });

    testWidgets('the submit button is disabled when no type is selected', (
      tester,
    ) async {
      await _pumpScreen(tester, controller: _controller(_FakeImportRepository()));

      await _fillCompleteForm(tester);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('import-submit-button')))
            .onPressed,
        isNotNull,
      );

      await _selectOnly(tester);

      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('import-submit-button')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('submitting with one type selected imports only that type', (
      tester,
    ) async {
      final repository = _FakeImportRepository();
      await _pumpScreen(tester, controller: _controller(repository));

      await _fillCompleteForm(tester);
      await _selectOnly(tester, keep: ImportType.diet);
      await tester.tap(find.byKey(const Key('import-submit-button')));
      await tester.pumpAndSettle();

      expect(repository.calls, ['diet']);
      // The run does not reset the selection back to everything: what the user
      // submitted is still what the next submit would run.
      for (final type in ImportType.values) {
        expect(
          tester.widget<Checkbox>(_checkboxFor(type)).value,
          type == ImportType.diet,
        );
      }
    });

    testWidgets('the checkboxes stay put but are locked while an import is running', (
      tester,
    ) async {
      final repository = _HangingImportRepository();
      await _pumpScreen(tester, controller: _controller(repository));

      await _fillCompleteForm(tester);
      await tester.tap(_checkboxFor(ImportType.bowel));
      await tester.pump();
      await tester.tap(find.byKey(const Key('import-submit-button')));
      await tester.pump();

      // The checkboxes never leave, so "left out" (unchecked) still reads apart
      // from "selected but not started yet" (checked) without any dimming.
      expect(find.byType(Checkbox), findsNWidgets(ImportType.values.length));
      expect(tester.widget<Checkbox>(_checkboxFor(ImportType.bowel)).value, isFalse);
      expect(tester.widget<Checkbox>(_checkboxFor(ImportType.diet)).value, isTrue);
      // Locked, not gone: the run they drive is already under way.
      for (final type in ImportType.values) {
        expect(tester.widget<Checkbox>(_checkboxFor(type)).onChanged, isNull);
      }
      expect(
        find.descendant(
          of: _rowFor(ImportType.weight),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      repository.weightCompleter.complete(
        const ChaodaysImportSummary(imported: 0, skipped: 0),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('tapping a row while an import is running does not change the selection', (
      tester,
    ) async {
      final repository = _HangingImportRepository();
      await _pumpScreen(tester, controller: _controller(repository));

      await _fillCompleteForm(tester);
      await tester.tap(find.byKey(const Key('import-submit-button')));
      await tester.pump();

      await tester.tap(
        find.descendant(
          of: _rowFor(ImportType.diet),
          matching: find.text(loc.importTypeDiet),
        ),
      );
      await tester.pump();

      expect(tester.widget<Checkbox>(_checkboxFor(ImportType.diet)).value, isTrue);

      repository.weightCompleter.complete(
        const ChaodaysImportSummary(imported: 0, skipped: 0),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('a row reads as one checkbox named after its type', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpScreen(tester, controller: _controller(_FakeImportRepository()));

      // One merged node carrying both the name and the checked state — not a
      // button node plus a same-named checkbox node read out one after another.
      final data = tester.getSemantics(_rowFor(ImportType.water)).getSemanticsData();
      // Exactly the type name once — a second label on the checkbox itself
      // would merge in and have the reader say the name twice.
      expect(data.label, loc.importTypeWater);
      expect(data.flagsCollection.hasCheckedState, isTrue);
      expect(data.flagsCollection.isChecked, isTrue);

      await tester.tap(_checkboxFor(ImportType.water));
      await tester.pump();

      expect(
        tester
            .getSemantics(_rowFor(ImportType.water))
            .getSemanticsData()
            .flagsCollection
            .isChecked,
        isFalse,
      );

      handle.dispose();
    });

    testWidgets('every row keeps its success icon after a fully successful run', (
      tester,
    ) async {
      final repository = _FakeImportRepository();
      await _pumpScreen(tester, controller: _controller(repository));

      await _fillCompleteForm(tester);
      await tester.tap(find.byKey(const Key('import-submit-button')));
      await tester.pumpAndSettle();

      // The outcome stays on the row the checkbox came back on — the user reads
      // what ran and re-selects in the same place.
      for (final type in ImportType.values) {
        expect(
          find.descendant(
            of: _rowFor(type),
            matching: find.byIcon(Icons.check_circle),
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('after a run stopped by a failure the failed row still shows its icon', (
      tester,
    ) async {
      final repository = _FakeImportRepository()
        ..weightError = const ImportChaodaysUnavailable();
      await _pumpScreen(tester, controller: _controller(repository));

      await _fillCompleteForm(tester);
      await tester.tap(find.byKey(const Key('import-submit-button')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: _rowFor(ImportType.weight),
          matching: find.byIcon(Icons.error),
        ),
        findsOneWidget,
      );
      // The types the run never reached keep the not-attempted circle rather
      // than a bare checked box that would read as an affirmation.
      for (final type in ImportType.values.where((t) => t != ImportType.weight)) {
        expect(
          find.descendant(
            of: _rowFor(type),
            matching: find.byIcon(Icons.circle_outlined),
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('after a fully successful run the selection can be changed and re-run', (
      tester,
    ) async {
      final repository = _FakeImportRepository();
      await _pumpScreen(tester, controller: _controller(repository));

      await _fillCompleteForm(tester);
      await tester.tap(find.byKey(const Key('import-submit-button')));
      await tester.pumpAndSettle();
      expect(repository.calls, ['weight', 'diet', 'water', 'bowel', 'dietTarget']);

      // Every row is `success` now — the checkboxes must be editable again, or
      // there is no way to re-run a single type without leaving the screen.
      for (final type in ImportType.values) {
        expect(tester.widget<Checkbox>(_checkboxFor(type)).onChanged, isNotNull);
      }

      repository.calls.clear();
      await _selectOnly(tester, keep: ImportType.water);
      await tester.tap(find.byKey(const Key('import-submit-button')));
      await tester.pumpAndSettle();

      expect(repository.calls, ['water']);
    });

    testWidgets('after a run that stopped on a failure the selection can be changed', (
      tester,
    ) async {
      final repository = _FakeImportRepository()
        ..weightError = const ImportChaodaysUnavailable();
      await _pumpScreen(tester, controller: _controller(repository));

      await _fillCompleteForm(tester);
      await tester.tap(find.byKey(const Key('import-submit-button')));
      await tester.pumpAndSettle();
      expect(find.text(loc.importErrorUnavailable), findsOneWidget);

      // The failed row plus the four not-attempted ones are all editable
      // again — the abort must not leave the card locked.
      for (final type in ImportType.values) {
        expect(tester.widget<Checkbox>(_checkboxFor(type)).onChanged, isNotNull);
      }

      repository.calls.clear();
      await _selectOnly(tester, keep: ImportType.bowel);
      await tester.tap(find.byKey(const Key('import-submit-button')));
      await tester.pumpAndSettle();

      expect(repository.calls, ['bowel']);
    });
  });
}
