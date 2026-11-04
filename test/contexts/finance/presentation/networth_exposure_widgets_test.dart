import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/finance/domain/finance_exceptions.dart';
import 'package:life_os/contexts/finance/domain/networth_account.dart';
import 'package:life_os/contexts/finance/domain/networth_exposure.dart';
import 'package:life_os/contexts/finance/domain/networth_snapshot.dart';
import 'package:life_os/contexts/finance/presentation/finance_controller.dart';
import 'package:life_os/contexts/finance/presentation/networth_controller.dart';
import 'package:life_os/contexts/finance/presentation/networth_tab.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/theme/app_theme.dart';

import '../../../support/l10n_test_app.dart';
import '../../../support/layout_guard.dart';
import '../exposure_test_support.dart';
import '../finance_test_support.dart';

ExposureTestRepository _repo({
  ExposureTestRepository? repository,
  bool missingDebt = false,
  bool empty = false,
  int debt = 12000000,
}) {
  final repo = (repository ?? ExposureTestRepository())..accounts.clear();
  for (final (id, kind, archived) in [
    ('etf', NetWorthKind.asset, false),
    ('property', NetWorthKind.asset, true),
    ('debt', NetWorthKind.liability, false),
  ]) {
    repo.accounts.add(
      NetWorthAccount(
        id: id,
        name: id,
        kind: kind,
        archived: archived,
        sortOrder: 0,
        exposureFactor: id == 'etf'
            ? ExposureFactor.leveraged2
            : id == 'property'
            ? ExposureFactor.unleveraged
            : null,
      ),
    );
  }
  if (!empty) {
    repo.seedSnapshot('etf', '2026-07', 3000000);
    repo.seedSnapshot('property', '2026-07', 15000000);
    if (!missingDebt) repo.seedSnapshot('debt', '2026-07', debt);
  }
  return repo;
}

Future<NetWorthController> _pump(
  WidgetTester tester, {
  FakeFinanceRepository? repo,
  Locale locale = const Locale('en'),
  bool dark = false,
  double scale = 1,
}) async {
  await tester.binding.setSurfaceSize(const Size(320, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final controller = testNetWorthController(repo ?? _repo());
  addTearDown(controller.dispose);
  await controller.loadForUser('a');
  await controller.load('token', '2026-07');
  await tester.pumpWidget(
    MaterialApp(
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: testSupportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: AnimatedBuilder(
          animation: controller,
          builder: (_, _) => NetWorthTab(
            controller: controller,
            idToken: () async => 'token',
            onSwitchMonth: (m) => controller.load('token', m),
            onEditAccountValue: (_) {},
            onManageAccounts: () {},
            onRefresh: () async {},
            onSignInAgain: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

Future<void> _open(WidgetTester tester) async {
  final button = find.byKey(const Key('exposure-settings-button'));
  await tester.scrollUntilVisible(
    button,
    250,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 60,
  );
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _sheetScrollTo(WidgetTester tester, Finder target) async {
  final scrollable = find.descendant(
    of: find.byKey(const Key('exposure-settings-list')),
    matching: find.byType(Scrollable),
  );
  await tester.scrollUntilVisible(
    target,
    250,
    scrollable: scrollable,
    maxScrolls: 100,
  );
  await tester.pumpAndSettle();
}

void main() {
  final loc = lookupAppLocalizations(const Locale('en'));

  testWidgets(
    'complete property example publishes total, percentage and ratio',
    (tester) async {
      await _pump(tester);
      expect(find.byKey(const Key('exposure-total')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('exposure-total'))).data,
        '21,000,000',
      );
      expect(find.text(loc.exposureRatio('3.50')), findsOneWidget);
      final percentage = find.byKey(const Key('exposure-percentage'));
      expect(
        tester.widget<Text>(percentage).data,
        loc.exposurePercentage('350.00'),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('exposure-total'))).dy,
        lessThan(tester.getTopLeft(percentage).dy),
      );
      expect(
        tester.getTopLeft(percentage).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('exposure-ratio'))).dy),
      );
    },
  );

  for (final (investment, cash, factor, percentage, ratio) in [
    (3000000, 3000000, ExposureFactor.leveraged2, '100.00', '1.00'),
    (3000000, 3000000, ExposureFactor.unleveraged, '50.00', '0.50'),
    (3000000, 3000000, ExposureFactor.cash, '0.00', '0.00'),
    (1000000, 2000000, ExposureFactor.unleveraged, '33.33', '0.33'),
  ]) {
    testWidgets('exposure is $percentage% with $ratio leverage', (
      tester,
    ) async {
      final repo = _repo(debt: 0)
        ..setFactor('etf', factor)
        ..setFactor('property', ExposureFactor.cash)
        ..seedSnapshot('etf', '2026-07', investment)
        ..seedSnapshot('property', '2026-07', cash);
      await _pump(tester, repo: repo);
      expect(
        tester.widget<Text>(find.byKey(const Key('exposure-percentage'))).data,
        loc.exposurePercentage(percentage),
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('exposure-ratio'))).data,
        loc.exposureRatio(ratio),
      );
    });
  }

  testWidgets('missing active liability explicitly blocks the headline', (
    tester,
  ) async {
    await _pump(tester, repo: _repo(missingDebt: true));
    expect(find.text(loc.exposureUnrecorded), findsOneWidget);
    expect(find.text(loc.exposureMissingAccounts('debt')), findsOneWidget);
    expect(find.byKey(const Key('exposure-total')), findsNothing);
    expect(find.byKey(const Key('exposure-ratio')), findsNothing);
    expect(find.byKey(const Key('exposure-percentage')), findsNothing);
  });

  testWidgets(
    'empty is not zero and unknown assets are not guessed from names',
    (tester) async {
      final repo = _repo()..setFactor('etf', null);
      final controller = await _pump(tester, repo: repo);
      expect(find.text(loc.exposureUnknownAccounts('etf')), findsOneWidget);
      expect(find.byKey(const Key('exposure-total')), findsNothing);
      expect(find.byKey(const Key('exposure-percentage')), findsNothing);
      await controller.load('token', '2026-08');
      await tester.pumpAndSettle();
      expect(find.text(loc.exposureEmpty), findsOneWidget);
      expect(find.byKey(const Key('exposure-ratio')), findsNothing);
      expect(find.byKey(const Key('exposure-percentage')), findsNothing);
    },
  );

  for (final debt in [18000000, 20000000]) {
    testWidgets('debt $debt leaves no percentage or leverage', (tester) async {
      await _pump(tester, repo: _repo(debt: debt));
      expect(find.byKey(const Key('exposure-total')), findsOneWidget);
      expect(find.text(loc.exposureNoRatio), findsOneWidget);
      expect(find.byKey(const Key('exposure-ratio')), findsNothing);
      expect(find.byKey(const Key('exposure-percentage')), findsNothing);
    });
  }

  testWidgets('archived monthly-only ID can be classified and unclassified', (
    tester,
  ) async {
    final repo = _repo()..setFactor('property', null);
    final controller = await _pump(tester, repo: repo);
    controller.accounts = controller.accounts
        .where((a) => a.id != 'property')
        .toList();
    await _open(tester);
    final factor = find.byKey(const Key('exposure-factor-property-1'));
    await _sheetScrollTo(tester, factor);
    await tester.tap(factor);
    await tester.pumpAndSettle();
    expect(controller.exposure!.totalExposure, 21000000);
    expect(tester.widget<ChoiceChip>(factor).selected, isTrue);
    final unknown = find.byKey(const Key('exposure-factor-property-unknown'));
    await _sheetScrollTo(tester, unknown);
    await tester.tap(unknown);
    await tester.pumpAndSettle();
    expect(controller.exposure!.status, ExposureStatus.unclassified);
  });

  testWidgets(
    'failed saves retain selection, show error, and retry successfully',
    (tester) async {
      final repo = _repo()..failWrite = true;
      await _pump(tester, repo: repo);
      await _open(tester);
      final factor = find.byKey(const Key('exposure-factor-etf-3'));
      await _sheetScrollTo(tester, factor);
      await tester.tap(factor);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('exposure-factor-etf-2')))
            .selected,
        isTrue,
      );
      expect(tester.widget<ChoiceChip>(factor).selected, isFalse);
      expect(find.byKey(const Key('exposure-save-error')), findsOneWidget);
      repo.failWrite = false;
      await _sheetScrollTo(tester, factor);
      await tester.tap(factor);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(factor).selected, isTrue);
      expect(find.byKey(const Key('exposure-save-error')), findsNothing);
    },
  );

  testWidgets(
    'read error blocks calculation until retry and sign-out clears open editor',
    (tester) async {
      final repo = _repo();
      final controller = await _pump(tester, repo: repo);
      repo.failRead = true;
      await controller.load('token', '2026-07');
      await tester.pumpAndSettle();
      expect(find.text(loc.exposureReadFailed), findsOneWidget);
      expect(find.byKey(const Key('exposure-total')), findsNothing);
      expect(find.byKey(const Key('exposure-percentage')), findsNothing);
      await _open(tester);
      repo.failRead = false;
      final retry = find.byKey(const Key('exposure-read-retry'));
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(controller.exposureSettingsStatus, ExposureSettingsStatus.ready);
      controller.reset();
      await tester.pump();
      expect(find.text(loc.exposureUnavailable), findsOneWidget);
      expect(find.byKey(const Key('exposure-account-etf')), findsNothing);
      expect(find.byKey(const Key('exposure-percentage')), findsNothing);
    },
  );

  for (final (failure, status, error) in [
    (
      const FinanceValidationFailure(),
      FinanceStatus.error,
      FinanceError.validation,
    ),
    (
      const FinanceFetchFailure('offline'),
      FinanceStatus.error,
      FinanceError.fetchFailed,
    ),
    (const FinanceReauthenticationRequired(), FinanceStatus.needsReauth, null),
  ]) {
    for (final refreshFinishesFirst in [false, true]) {
      testWidgets(
        'snapshot error $failure leaves usable exposure recovery, refresh first=$refreshFinishesFirst',
        (tester) async {
          final repo = _SnapshotRaceRepository();
          _repo(repository: repo);
          final controller = await _pump(tester, repo: repo);
          await _open(tester);
          final chip = find.byKey(const Key('exposure-factor-etf-3'));
          await _sheetScrollTo(tester, chip);
          repo.snapshotGate = Completer<void>();
          repo.snapshotFailure = failure;
          final save = controller.saveSnapshot(
            'token',
            accountId: 'etf',
            value: 4000000,
          );
          final readGate = Completer<void>();
          repo.nextReadGate = readGate;
          final refresh = controller.load(
            'token',
            '2026-07',
            notifyOnStart: true,
          );
          await tester.pump();
          expect(tester.widget<ChoiceChip>(chip).onSelected, isNull);
          if (refreshFinishesFirst) {
            readGate.complete();
            await refresh;
          }
          repo.snapshotGate!.complete();
          await save;
          if (!refreshFinishesFirst) {
            readGate.complete();
            await refresh;
          }
          await tester.pumpAndSettle();
          expect(controller.status, status);
          expect(controller.error, error);
          expect(find.text(loc.exposureReading), findsNothing);
          expect(controller.exposureFactors['etf'], ExposureFactor.leveraged2);
          if (controller.exposureSettingsStatus ==
              ExposureSettingsStatus.readFailed) {
            expect(
              find.byKey(const Key('exposure-read-retry')),
              findsOneWidget,
            );
            await tester.tap(find.byKey(const Key('exposure-read-retry')));
            await tester.pumpAndSettle();
          }
          await _sheetScrollTo(tester, chip);
          expect(tester.widget<ChoiceChip>(chip).onSelected, isNotNull);
          await tester.tap(chip);
          await tester.pumpAndSettle();
          expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
        },
      );
    }
  }

  for (final locale in testSupportedLocales) {
    for (final dark in [false, true]) {
      testWidgets('320dp 2x tab and usable editor $locale dark=$dark', (
        tester,
      ) async {
        await expectNoLayoutErrors(() async {
          await _pump(tester, locale: locale, dark: dark, scale: 2);
          final localized = lookupAppLocalizations(locale);
          final percentage = find.byKey(const Key('exposure-percentage'));
          await tester.scrollUntilVisible(
            percentage,
            250,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 60,
          );
          expect(find.text(localized.exposurePercentageLabel), findsOneWidget);
          expect(
            tester.widget<Text>(percentage).data,
            localized.exposurePercentage('350.00'),
          );
          expect(find.text(localized.exposureRatio('3.50')), findsOneWidget);
          expect(tester.getRect(percentage).width, lessThanOrEqualTo(320));
          await _open(tester);
          for (final id in ['etf', 'property']) {
            final chip = find.byKey(Key('exposure-factor-$id-3'));
            await _sheetScrollTo(tester, chip);
            expect(tester.getRect(chip).width, lessThanOrEqualTo(320));
            await tester.tap(chip);
            await tester.pumpAndSettle();
            expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
          }
          await _sheetScrollTo(
            tester,
            find.text(lookupAppLocalizations(locale).exposureSource),
          );
          expect(
            find.text(lookupAppLocalizations(locale).exposureExamples),
            findsOneWidget,
          );
        });
      });
    }
  }
}

class _SnapshotRaceRepository extends ExposureTestRepository {
  Completer<void>? snapshotGate;
  Completer<void>? nextReadGate;
  Object? snapshotFailure;

  @override
  Future<MonthlyNetWorth> getMonthlyNetWorth(
    String idToken,
    String month,
  ) async {
    final gate = nextReadGate;
    nextReadGate = null;
    final result = await super.getMonthlyNetWorth(idToken, month);
    await gate?.future;
    return result;
  }

  @override
  Future<NetWorthSnapshot> upsertNetWorthSnapshot(
    String idToken, {
    required String accountId,
    required String month,
    required int value,
  }) async {
    await snapshotGate?.future;
    if (snapshotFailure case final failure?) throw failure;
    return super.upsertNetWorthSnapshot(
      idToken,
      accountId: accountId,
      month: month,
      value: value,
    );
  }
}
