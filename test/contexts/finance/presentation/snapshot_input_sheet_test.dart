import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/finance/domain/networth_account.dart';
import 'package:life_os/contexts/finance/presentation/networth_controller.dart';
import 'package:life_os/contexts/finance/presentation/snapshot_input_sheet.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';
import '../finance_test_support.dart';

const _locale = Locale('en');
final _loc = lookupAppLocalizations(_locale);

const _cash = NetWorthAccount(
  id: 'acc-cash',
  kind: NetWorthKind.asset,
  name: '台幣活存',
  sortOrder: 0,
  archived: false,
);

Future<NetWorthController> _pumpSheet(
  WidgetTester tester,
  FakeFinanceRepository repo, {
  int? currentValue,
}) async {
  final controller = testNetWorthController(repo);
  await controller.load('token', '2026-07');
  await tester.pumpWidget(
    l10nTestApp(
      home: Scaffold(
        body: SnapshotInputSheet(
          controller: controller,
          idToken: 'token',
          account: _cash,
          currentValue: currentValue,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

bool _saveEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(const Key('snapshot-save'))).onPressed != null;

void main() {
  group('parseSnapshotValue', () {
    test('accepts 0 and positive whole numbers', () {
      expect(parseSnapshotValue('0'), 0);
      expect(parseSnapshotValue(' 30000 '), 30000);
    });

    test('rejects empty, negative, decimal, and non-numeric input', () {
      expect(parseSnapshotValue(''), isNull);
      expect(parseSnapshotValue('-1'), isNull);
      // Never silently rounded — TWD has no minor units.
      expect(parseSnapshotValue('12.5'), isNull);
      expect(parseSnapshotValue('abc'), isNull);
    });

    test('rejects notations Dart would silently reinterpret', () {
      // `int.tryParse('0x1f')` is 31 in Dart — typing a hex-looking value
      // must never be stored as some other decimal number.
      expect(parseSnapshotValue('0x1f'), isNull);
      expect(parseSnapshotValue('+5'), isNull);
      expect(parseSnapshotValue('1 000'), isNull);
    });
  });

  group('SnapshotInputSheet', () {
    testWidgets('pre-fills the account\'s existing value for the month', (tester) async {
      await _pumpSheet(tester, FakeFinanceRepository(), currentValue: 30000);

      expect(
        tester.widget<TextField>(find.byKey(const Key('snapshot-field'))).controller!.text,
        '30000',
      );
    });

    testWidgets('saving upserts the value and refreshes the month', (tester) async {
      final repo = FakeFinanceRepository();
      final controller = await _pumpSheet(tester, repo);

      await tester.enterText(find.byKey(const Key('snapshot-field')), '30000');
      await tester.pump();
      await tester.tap(find.byKey(const Key('snapshot-save')));
      await tester.pumpAndSettle();

      expect(repo.networthCalls, ['upsert:acc-cash:2026-07:30000']);
      expect(controller.monthly!.netWorth, 30000);
    });

    testWidgets('0 is a legal value, not an invalid one', (tester) async {
      final repo = FakeFinanceRepository();
      await _pumpSheet(tester, repo, currentValue: 500);

      await tester.enterText(find.byKey(const Key('snapshot-field')), '0');
      await tester.pump();

      expect(find.text(_loc.networthInvalidValue), findsNothing);
      expect(_saveEnabled(tester), isTrue);

      await tester.tap(find.byKey(const Key('snapshot-save')));
      await tester.pumpAndSettle();

      expect(repo.networthCalls, ['upsert:acc-cash:2026-07:0']);
    });

    testWidgets('a negative value shows an error and disables save', (tester) async {
      final repo = FakeFinanceRepository();
      await _pumpSheet(tester, repo, currentValue: 500);

      await tester.enterText(find.byKey(const Key('snapshot-field')), '-5');
      await tester.pump();

      expect(find.text(_loc.networthInvalidValue), findsOneWidget);
      expect(_saveEnabled(tester), isFalse);
      // The existing value is never silently overwritten by the rejection.
      expect(repo.networthCalls, isEmpty);
      expect(repo.snapshots['acc-cash'], isNull);
    });

    testWidgets('non-numeric input shows an error and disables save', (tester) async {
      await _pumpSheet(tester, FakeFinanceRepository());

      await tester.enterText(find.byKey(const Key('snapshot-field')), 'abc');
      await tester.pump();

      expect(find.text(_loc.networthInvalidValue), findsOneWidget);
      expect(_saveEnabled(tester), isFalse);
    });

    testWidgets('an empty field means unrecorded — nothing is sent', (tester) async {
      final repo = FakeFinanceRepository();
      await _pumpSheet(tester, repo, currentValue: 500);

      await tester.enterText(find.byKey(const Key('snapshot-field')), '');
      await tester.pump();

      // Empty isn't an error, but there's nothing to write either.
      expect(find.text(_loc.networthInvalidValue), findsNothing);
      expect(_saveEnabled(tester), isFalse);
      expect(repo.networthCalls, isEmpty);
    });
  });
}
