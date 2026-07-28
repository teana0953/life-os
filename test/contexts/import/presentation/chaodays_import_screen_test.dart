import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/import/application/import_bowel.dart';
import 'package:life_os/contexts/import/application/import_diet.dart';
import 'package:life_os/contexts/import/application/import_diet_target.dart';
import 'package:life_os/contexts/import/application/import_menstrual.dart';
import 'package:life_os/contexts/import/application/import_water.dart';
import 'package:life_os/contexts/import/application/import_weight.dart';
import 'package:life_os/contexts/import/domain/chaodays_import_summary.dart';
import 'package:life_os/contexts/import/domain/import_exceptions.dart';
import 'package:life_os/contexts/import/domain/import_repository.dart';
import 'package:life_os/contexts/import/presentation/chaodays_import_controller.dart';
import 'package:life_os/contexts/import/presentation/chaodays_import_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/data_revision.dart';
import 'package:life_os/shared/theme/app_colors.dart';
import 'package:life_os/shared/theme/app_theme.dart';

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
  ChaodaysImportSummary menstrualSummary = const ChaodaysImportSummary(
    imported: 9,
    skipped: 3,
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

  @override
  Future<ChaodaysImportSummary> importMenstrual(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) async {
    calls.add('menstrual');
    return menstrualSummary;
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

  @override
  Future<ChaodaysImportSummary> importMenstrual(
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
      ImportMenstrual(repository),
      DataRevision(),
    );

DateTime _defaultClock() => DateTime(2026, 7, 20, 9);

Future<void> _pumpScreen(
  WidgetTester tester, {
  required ChaodaysImportController controller,
  AuthRepository? authRepository,
  DateTime Function() clock = _defaultClock,
  Locale locale = const Locale('en'),
  ThemeData? theme,
  Size size = const Size(600, 1200),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    l10nTestApp(
      locale: locale,
      theme: theme,
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

/// Whatever currently occupies the row's trailing status slot — an icon, a
/// spinner, or the blank that stands in for "nothing to report".
Finder _statusFor(ImportType type) =>
    find.byKey(Key('import-type-status-${type.name}'));

/// Unchecks every type except [keep] (nothing is kept when it is null).
Future<void> _selectOnly(WidgetTester tester, {ImportType? keep}) async {
  for (final type in ImportType.values.where((t) => t != keep)) {
    await tester.tap(_checkboxFor(type));
    await tester.pump();
  }
}

/// The color the row's title actually renders with: the `Text`'s own style
/// merged onto the `DefaultTextStyle` the (possibly disabled) `ListTile` hands
/// down — i.e. what the user sees, not what the tile would have imposed.
Color _titleColor(WidgetTester tester, ImportType type, String label) => tester
    .renderObject<RenderParagraph>(
      find.descendant(of: _rowFor(type), matching: find.text(label)),
    )
    .text
    .style!
    .color!;

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

      expect(repository.calls, [
        'weight',
        'diet',
        'water',
        'bowel',
        'dietTarget',
        'menstrual',
      ]);
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
        ImportMenstrual(repository),
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
      expect(find.text(loc.importTypeMenstrual), findsOneWidget);
      expect(find.text(loc.importResultSummary(9, 3)), findsOneWidget);
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

    testWidgets('the menstrual row is on screen and can be toggled', (
      tester,
    ) async {
      await _pumpScreen(tester, controller: _controller(_FakeImportRepository()));

      expect(find.text(loc.importTypeMenstrual), findsOneWidget);
      expect(
        tester.widget<Checkbox>(_checkboxFor(ImportType.menstrual)).value,
        isTrue,
      );

      await tester.tap(
        find.descendant(
          of: _rowFor(ImportType.menstrual),
          matching: find.text(loc.importTypeMenstrual),
        ),
      );
      await tester.pump();

      expect(
        tester.widget<Checkbox>(_checkboxFor(ImportType.menstrual)).value,
        isFalse,
      );
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
      final handle = tester.ensureSemantics();
      final repository = _HangingImportRepository();
      await _pumpScreen(
        tester,
        controller: _controller(repository),
        theme: lightTheme,
      );

      await _fillCompleteForm(tester);
      await tester.tap(_checkboxFor(ImportType.bowel));
      await tester.pump();
      await tester.tap(find.byKey(const Key('import-submit-button')));
      await tester.pump();
      // Past the tile's disabled-text fade, so a title left to the ListTile's
      // DefaultTextStyle would have settled on the disabled grey by now.
      await tester.pump(const Duration(milliseconds: 400));

      // The checkboxes never leave, so "left out" (unchecked) still reads apart
      // from "selected but not started yet" (checked) without any dimming.
      expect(find.byType(Checkbox), findsNWidgets(ImportType.values.length));
      expect(tester.widget<Checkbox>(_checkboxFor(ImportType.bowel)).value, isFalse);
      expect(tester.widget<Checkbox>(_checkboxFor(ImportType.diet)).value, isTrue);
      // Locked, not gone: the run they drive is already under way.
      for (final type in ImportType.values) {
        expect(tester.widget<Checkbox>(_checkboxFor(type)).onChanged, isNull);
      }
      // The lock must not cost the label its contrast: the title carries its
      // own onSurface color, so it keeps rendering at full strength even
      // though the tile itself is disabled (which is what the screen reader
      // needs to hear).
      expect(
        _titleColor(tester, ImportType.diet, loc.importTypeDiet),
        lightTheme.colorScheme.onSurface,
      );
      final spinner = tester.widget<CircularProgressIndicator>(
        find.descendant(
          of: _rowFor(ImportType.weight),
          matching: find.byType(CircularProgressIndicator),
        ),
      );
      // The pastel primary is 1.64:1 on the light card — the running row uses
      // the deeper light-theme icon color instead.
      expect(spinner.color, importRunningIconLight);
      expect(spinner.color, isNot(lightTheme.colorScheme.primary));
      // A screen reader must not be told "enabled checkbox" for a row that has
      // no toggle action left.
      expect(
        tester
            .getSemantics(_rowFor(ImportType.diet))
            .getSemanticsData()
            .flagsCollection
            .isEnabled,
        isFalse,
      );

      repository.weightCompleter.complete(
        const ChaodaysImportSummary(imported: 0, skipped: 0),
      );
      await tester.pumpAndSettle();
      handle.dispose();
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

    testWidgets('no status is shown before the first run, and the slot keeps its width', (
      tester,
    ) async {
      final repository = _FakeImportRepository();
      await _pumpScreen(tester, controller: _controller(repository));

      // Six identical empty circles report nothing and read like a stray set
      // of radio buttons — the slot stays blank until it has something to say.
      for (final type in ImportType.values) {
        expect(
          find.descendant(of: _rowFor(type), matching: find.byType(Icon)),
          findsNothing,
        );
      }
      final blankWidth = tester.getSize(_statusFor(ImportType.weight)).width;

      await _fillCompleteForm(tester);
      await tester.tap(find.byKey(const Key('import-submit-button')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: _rowFor(ImportType.weight),
          matching: find.byIcon(Icons.check_circle),
        ),
        findsOneWidget,
      );
      // The blank stands in at the icon's own width, so the labels don't jump
      // sideways the first time a run reports back.
      expect(tester.getSize(_statusFor(ImportType.weight)).width, blankWidth);
    });

    testWidgets('the checkbox leads the row and the status icon trails it', (
      tester,
    ) async {
      await _pumpScreen(tester, controller: _controller(_FakeImportRepository()));

      // Once a run has reported back — before that the trailing slot is blank
      // by design, so there is no icon to place.
      await _fillCompleteForm(tester);
      await tester.tap(find.byKey(const Key('import-submit-button')));
      await tester.pumpAndSettle();

      // The two slots never swap roles: the checkbox deciding the next run
      // stays on the left, the icon reporting the last one on the right.
      for (final type in ImportType.values) {
        final checkboxX = tester.getCenter(_checkboxFor(type)).dx;
        final iconX = tester
            .getCenter(
              find.descendant(
                of: _rowFor(type),
                matching: find.byIcon(Icons.check_circle),
              ),
            )
            .dx;
        expect(checkboxX, lessThan(iconX));
      }
    });

    testWidgets('the type selection sits under a heading, above the submit button', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        controller: _controller(_FakeImportRepository()),
        theme: lightTheme,
      );

      final heading = find.text(loc.importTypesTitle);
      expect(heading, findsOneWidget);
      // Heading names the group, then the rows, then the action they drive —
      // so "clear every type and the button greys out" reads as cause first,
      // effect second.
      expect(
        tester.getBottomLeft(heading).dy,
        lessThanOrEqualTo(tester.getTopLeft(_rowFor(ImportType.weight)).dy),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('import-submit-button'))).dy,
        greaterThan(tester.getBottomLeft(_rowFor(ImportType.menstrual)).dy),
      );
      expect(
        tester.renderObject<RenderParagraph>(heading).text.style!.fontWeight,
        lightTheme.textTheme.labelLarge!.fontWeight,
      );
    });

    testWidgets('the success icon uses the deeper light-theme icon color', (
      tester,
    ) async {
      final repository = _FakeImportRepository();
      await _pumpScreen(
        tester,
        controller: _controller(repository),
        theme: lightTheme,
      );

      await _fillCompleteForm(tester);
      await tester.tap(find.byKey(const Key('import-submit-button')));
      await tester.pumpAndSettle();

      // The pastel tertiary is 1.28:1 on the light card, so the ✓ that the
      // trailing slot now carries permanently would be invisible there.
      final icon = tester.widget<Icon>(
        find.descendant(
          of: _rowFor(ImportType.weight),
          matching: find.byIcon(Icons.check_circle),
        ),
      );
      expect(icon.color, importSuccessIconLight);
      expect(icon.color, isNot(lightTheme.colorScheme.tertiary));
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

    testWidgets('changing one type\'s selection after a run clears that row only', (
      tester,
    ) async {
      final repository = _FakeImportRepository();
      await _pumpScreen(tester, controller: _controller(repository));

      await _fillCompleteForm(tester);
      await tester.tap(find.byKey(const Key('import-submit-button')));
      await tester.pumpAndSettle();
      expect(find.text(loc.importResultSummary(4, 0)), findsOneWidget);

      await tester.tap(_checkboxFor(ImportType.water));
      await tester.pump();

      // The user just changed what water is going to do next, so last run's
      // water result no longer describes anything the screen is showing.
      expect(find.text(loc.importResultSummary(4, 0)), findsNothing);
      // Structural, not "the success icon is gone": a cleared row must show no
      // status at all. Naming one icon lets a wrong implementation swap in a
      // different one — driving this off the overall ImportStatus instead of
      // the type's own leaves a circle_outlined here, and the row then reads
      // out "Not attempted" to a screen reader.
      expect(
        find.descendant(
          of: _rowFor(ImportType.water),
          matching: find.byType(Icon),
        ),
        findsNothing,
      );
      // The rows the user did not touch still stand.
      expect(find.text(loc.importResultSummary(1, 0)), findsOneWidget);
      expect(
        find.descendant(
          of: _rowFor(ImportType.weight),
          matching: find.byIcon(Icons.check_circle),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a running type and its outcome are described for a screen reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final repository = _HangingImportRepository();
      await _pumpScreen(tester, controller: _controller(repository));

      await _fillCompleteForm(tester);
      await tester.tap(find.byKey(const Key('import-submit-button')));
      await tester.pump();

      // The row merges into a single node, so the spinner has to put its
      // meaning into that node's label or it says nothing at all.
      expect(
        tester.getSemantics(_rowFor(ImportType.weight)).label,
        contains(loc.importStatusImporting),
      );

      repository.weightCompleter.complete(
        const ChaodaysImportSummary(imported: 0, skipped: 0),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(_rowFor(ImportType.weight)).label,
        contains(loc.importStatusSuccess),
      );
      handle.dispose();
    });

    testWidgets('a failed type and the ones it stopped are described too', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final repository = _FakeImportRepository()
        ..weightError = const ImportChaodaysUnavailable();
      await _pumpScreen(tester, controller: _controller(repository));

      await _fillCompleteForm(tester);
      await tester.tap(find.byKey(const Key('import-submit-button')));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(_rowFor(ImportType.weight)).label,
        contains(loc.importStatusFailed),
      );
      expect(
        tester.getSemantics(_rowFor(ImportType.bowel)).label,
        contains(loc.importStatusNotAttempted),
      );
      handle.dispose();
    });

    testWidgets('after a fully successful run the selection can be changed and re-run', (
      tester,
    ) async {
      final repository = _FakeImportRepository();
      await _pumpScreen(tester, controller: _controller(repository));

      await _fillCompleteForm(tester);
      await tester.tap(find.byKey(const Key('import-submit-button')));
      await tester.pumpAndSettle();
      expect(repository.calls, [
        'weight',
        'diet',
        'water',
        'bowel',
        'dietTarget',
        'menstrual',
      ]);

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

      // The failed row plus the five not-attempted ones are all editable
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

  group('ChaodaysImportScreen narrow layout', () {
    for (final width in const [320.0, 360.0]) {
      for (final locale in testSupportedLocales) {
        testWidgets(
          'the submit button is reachable and nothing overflows at '
          '${width.toInt()}dp (${locale.toLanguageTag()})',
          (tester) async {
            await _pumpScreen(
              tester,
              controller: _controller(_FakeImportRepository()),
              locale: locale,
              size: Size(width, 780),
            );

            // Six type rows plus the hint no longer fit above the fold, so the
            // button has to be scrolled to — which is fine, but it has to be
            // REACHABLE. A row added without checking this is how a submit
            // button quietly ends up below a viewport nobody scrolls.
            await tester.scrollUntilVisible(
              find.byKey(const Key('import-submit-button')),
              200,
              scrollable: find.byType(Scrollable).first,
            );

            expect(find.byKey(const Key('import-submit-button')), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets('the open-period hint is shown before any import runs', (
      tester,
    ) async {
      final loc = await AppLocalizations.delegate.load(const Locale('en'));
      await _pumpScreen(tester, controller: _controller(_FakeImportRepository()));

      // Stated up front, not as an after-the-fact reading of "skipped": the
      // user decides whether to re-import later while still on this screen.
      expect(find.byKey(const Key('import-menstrual-hint')), findsOneWidget);
      expect(find.text(loc.importMenstrualOpenPeriodHint), findsOneWidget);
    });

    testWidgets('the open-period hint is still there after a run finishes', (
      tester,
    ) async {
      // The moment the sentence is actually needed: the user is looking at
      // "Imported 12 · Skipped 1" and deciding whether that means done. A hint
      // that only shows before the run would be gone exactly then.
      await _pumpScreen(tester, controller: _controller(_FakeImportRepository()));
      await _fillCompleteForm(tester);
      await tester.tap(find.byKey(const Key('import-submit-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('import-done-message')), findsOneWidget);
      expect(find.byKey(const Key('import-menstrual-hint')), findsOneWidget);
    });
  });
}
