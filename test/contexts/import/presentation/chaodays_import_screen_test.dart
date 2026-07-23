import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/import/application/import_bowel.dart';
import 'package:life_os/contexts/import/application/import_diet.dart';
import 'package:life_os/contexts/import/application/import_water.dart';
import 'package:life_os/contexts/import/application/import_weight.dart';
import 'package:life_os/contexts/import/domain/chaodays_import_summary.dart';
import 'package:life_os/contexts/import/domain/import_exceptions.dart';
import 'package:life_os/contexts/import/domain/import_repository.dart';
import 'package:life_os/contexts/import/presentation/chaodays_import_controller.dart';
import 'package:life_os/contexts/import/presentation/chaodays_import_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

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

ChaodaysImportController _controller(_FakeImportRepository repository) =>
    ChaodaysImportController(
      ImportWeight(repository),
      ImportDiet(repository),
      ImportWater(repository),
      ImportBowel(repository),
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

      expect(repository.calls, ['weight', 'diet', 'water', 'bowel']);
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
}
