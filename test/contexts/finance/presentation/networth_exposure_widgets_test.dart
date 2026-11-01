import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/finance/application/exposure_settings.dart';
import 'package:life_os/contexts/finance/domain/networth_account.dart';
import 'package:life_os/contexts/finance/domain/networth_exposure.dart';
import 'package:life_os/contexts/finance/presentation/networth_controller.dart';
import 'package:life_os/contexts/finance/presentation/networth_tab.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/theme/app_theme.dart';

import '../../../support/l10n_test_app.dart';
import '../../../support/layout_guard.dart';
import '../exposure_test_support.dart';
import '../finance_test_support.dart';

FakeFinanceRepository _repo({
  bool missingDebt = false,
  bool empty = false,
  int debt = 12000000,
}) {
  final repo = FakeFinanceRepository()..accounts.clear();
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

FakeExposureSettingsRepository _store() => FakeExposureSettingsRepository()
  ..values['a'] = {
    'etf': ExposureFactor.leveraged2,
    'property': ExposureFactor.unleveraged,
  };

Future<NetWorthController> _pump(
  WidgetTester tester, {
  FakeFinanceRepository? repo,
  FakeExposureSettingsRepository? store,
  Locale locale = const Locale('en'),
  bool dark = false,
  double scale = 1,
}) async {
  await tester.binding.setSurfaceSize(const Size(320, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final controller = testNetWorthController(
    repo ?? _repo(),
    exposureSettings: ExposureSettings(store ?? _store()),
  );
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

  testWidgets('complete property example publishes total and ratio', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byKey(const Key('exposure-total')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('exposure-total'))).data,
      '21,000,000',
    );
    expect(find.text(loc.exposureRatio('3.50')), findsOneWidget);
  });

  testWidgets('missing active liability explicitly blocks the headline', (
    tester,
  ) async {
    await _pump(tester, repo: _repo(missingDebt: true));
    expect(find.text(loc.exposureUnrecorded), findsOneWidget);
    expect(find.text(loc.exposureMissingAccounts('debt')), findsOneWidget);
    expect(find.byKey(const Key('exposure-total')), findsNothing);
    expect(find.byKey(const Key('exposure-ratio')), findsNothing);
  });

  testWidgets(
    'empty is not zero and unknown assets are not guessed from names',
    (tester) async {
      final store = _store()..values['a']!.remove('etf');
      final controller = await _pump(tester, store: store);
      expect(find.text(loc.exposureUnknownAccounts('etf')), findsOneWidget);
      expect(find.byKey(const Key('exposure-total')), findsNothing);
      await controller.load('token', '2026-08');
      await tester.pumpAndSettle();
      expect(find.text(loc.exposureEmpty), findsOneWidget);
      expect(find.byKey(const Key('exposure-ratio')), findsNothing);
    },
  );

  testWidgets('nonpositive net worth shows exposure but no ratio', (
    tester,
  ) async {
    await _pump(tester, repo: _repo(debt: 20000000));
    expect(find.byKey(const Key('exposure-total')), findsOneWidget);
    expect(find.text(loc.exposureNoRatio), findsOneWidget);
    expect(find.byKey(const Key('exposure-ratio')), findsNothing);
  });

  testWidgets('archived monthly-only ID can be classified and unclassified', (
    tester,
  ) async {
    final store = _store()..values['a']!.remove('property');
    final controller = await _pump(tester, store: store);
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
      final store = _store()..failWrite = true;
      await _pump(tester, store: store);
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
      store.failWrite = false;
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
      final store = _store()..failRead = true;
      final controller = await _pump(tester, store: store);
      expect(find.text(loc.exposureReadFailed), findsOneWidget);
      expect(find.byKey(const Key('exposure-total')), findsNothing);
      await _open(tester);
      store.failRead = false;
      final retry = find.byKey(const Key('exposure-read-retry'));
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(controller.exposureSettingsStatus, ExposureSettingsStatus.ready);
      controller.reset();
      await tester.pump();
      expect(find.text(loc.exposureUnavailable), findsOneWidget);
      expect(find.byKey(const Key('exposure-account-etf')), findsNothing);
    },
  );

  for (final locale in testSupportedLocales) {
    for (final dark in [false, true]) {
      testWidgets('320dp 2x tab and usable editor $locale dark=$dark', (
        tester,
      ) async {
        await expectNoLayoutErrors(() async {
          await _pump(tester, locale: locale, dark: dark, scale: 2);
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
