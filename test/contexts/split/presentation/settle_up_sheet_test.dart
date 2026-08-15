import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/split/presentation/settle_up_sheet.dart';
import 'package:life_os/contexts/split/presentation/settlement_writer.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';

final _loc = lookupAppLocalizations(const Locale('en'));

/// A controllable fake [SettlementWriter]: records the last
/// [createSettlement] call's arguments and can be told to fail once.
class FakeSettlementWriter implements SettlementWriter {
  String? gotIdToken;
  String? gotGroupId;
  String? gotFromUserId;
  String? gotToUserId;
  int? gotAmount;
  String? gotCurrency;
  String? gotDay;
  String? gotNote;
  int createCalls = 0;

  Object? failNext;

  @override
  Object? mutationError;
  @override
  int mutationErrorSeq = 0;

  @override
  Future<void> createSettlement(
    String idToken, {
    String? groupId,
    required String fromUserId,
    required String toUserId,
    required int amount,
    required String currency,
    required String day,
    String? note,
  }) async {
    gotIdToken = idToken;
    gotGroupId = groupId;
    gotFromUserId = fromUserId;
    gotToUserId = toUserId;
    gotAmount = amount;
    gotCurrency = currency;
    gotDay = day;
    gotNote = note;
    createCalls++;
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      mutationError = failure;
      mutationErrorSeq++;
    }
  }
}

Future<void> _pumpSheet(WidgetTester tester, {required SettleUpSheet sheet}) async {
  await tester.pumpWidget(l10nTestApp(home: Scaffold(body: sheet)));
  await tester.pumpAndSettle();
}

void main() {
  group('SettleUpSheet — direction (the one place a wrong result reads as normal)', () {
    testWidgets('a positive balance (other owes me) submits them paying me', (tester) async {
      final writer = FakeSettlementWriter();

      await _pumpSheet(
        tester,
        sheet: SettleUpSheet(
          writer: writer,
          idToken: () async => 'tok',
          selfUserId: 'self-1',
          otherUserId: 'other-1',
          otherDisplayName: 'Bo',
          balanceAmount: 450,
          currency: 'TWD',
          today: '2026-08-02',
        ),
      );

      expect(find.text(_loc.settleUpTitleReceiving('Bo')), findsOneWidget);
      expect(find.text('450'), findsOneWidget);

      await tester.tap(find.byKey(const Key('settle-up-confirm-button')));
      await tester.pumpAndSettle();

      expect(writer.createCalls, 1);
      expect(writer.gotFromUserId, 'other-1');
      expect(writer.gotToUserId, 'self-1');
      expect(writer.gotAmount, 450);
      expect(writer.gotGroupId, isNull);
    });

    testWidgets('a negative balance (I owe them) submits me paying them', (tester) async {
      final writer = FakeSettlementWriter();

      await _pumpSheet(
        tester,
        sheet: SettleUpSheet(
          writer: writer,
          idToken: () async => 'tok',
          selfUserId: 'self-1',
          otherUserId: 'other-1',
          otherDisplayName: 'Bo',
          balanceAmount: -450,
          currency: 'TWD',
          today: '2026-08-02',
        ),
      );

      expect(find.text(_loc.settleUpTitlePaying('Bo')), findsOneWidget);
      expect(find.text('450'), findsOneWidget);

      await tester.tap(find.byKey(const Key('settle-up-confirm-button')));
      await tester.pumpAndSettle();

      expect(writer.createCalls, 1);
      expect(writer.gotFromUserId, 'self-1');
      expect(writer.gotToUserId, 'other-1');
      expect(writer.gotAmount, 450);
      expect(writer.gotGroupId, isNull);
    });
  });

  group('SettleUpSheet — amount', () {
    testWidgets('pre-fills the full outstanding amount', (tester) async {
      final writer = FakeSettlementWriter();

      await _pumpSheet(
        tester,
        sheet: SettleUpSheet(
          writer: writer,
          idToken: () async => 'tok',
          selfUserId: 'self-1',
          otherUserId: 'other-1',
          otherDisplayName: 'Bo',
          balanceAmount: 123456,
          currency: 'TWD',
          today: '2026-08-02',
        ),
      );

      expect(find.text('123456'), findsOneWidget);
    });

    testWidgets('a partial payment submits the typed amount', (tester) async {
      final writer = FakeSettlementWriter();

      await _pumpSheet(
        tester,
        sheet: SettleUpSheet(
          writer: writer,
          idToken: () async => 'tok',
          selfUserId: 'self-1',
          otherUserId: 'other-1',
          otherDisplayName: 'Bo',
          balanceAmount: 450,
          currency: 'TWD',
          today: '2026-08-02',
        ),
      );

      await tester.enterText(find.byKey(const Key('settle-up-amount-field')), '300');
      await tester.pump();
      await tester.tap(find.byKey(const Key('settle-up-confirm-button')));
      await tester.pumpAndSettle();

      expect(writer.gotAmount, 300);
    });

    testWidgets('an empty amount disables confirm and shows a reason', (tester) async {
      final writer = FakeSettlementWriter();

      await _pumpSheet(
        tester,
        sheet: SettleUpSheet(
          writer: writer,
          idToken: () async => 'tok',
          selfUserId: 'self-1',
          otherUserId: 'other-1',
          otherDisplayName: 'Bo',
          balanceAmount: 450,
          currency: 'TWD',
          today: '2026-08-02',
        ),
      );

      await tester.enterText(find.byKey(const Key('settle-up-amount-field')), '');
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byKey(const Key('settle-up-confirm-button')));
      expect(button.onPressed, isNull);
      expect(find.text(_loc.settleUpAmountRequired), findsOneWidget);
    });

    testWidgets('a zero amount disables confirm', (tester) async {
      final writer = FakeSettlementWriter();

      await _pumpSheet(
        tester,
        sheet: SettleUpSheet(
          writer: writer,
          idToken: () async => 'tok',
          selfUserId: 'self-1',
          otherUserId: 'other-1',
          otherDisplayName: 'Bo',
          balanceAmount: 450,
          currency: 'TWD',
          today: '2026-08-02',
        ),
      );

      await tester.enterText(find.byKey(const Key('settle-up-amount-field')), '0');
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byKey(const Key('settle-up-confirm-button')));
      expect(button.onPressed, isNull);
    });

    testWidgets('a fractional amount for a zero-decimal currency is refused, not rounded', (
      tester,
    ) async {
      final writer = FakeSettlementWriter();

      await _pumpSheet(
        tester,
        sheet: SettleUpSheet(
          writer: writer,
          idToken: () async => 'tok',
          selfUserId: 'self-1',
          otherUserId: 'other-1',
          otherDisplayName: 'Bo',
          balanceAmount: 450,
          currency: 'TWD',
          today: '2026-08-02',
        ),
      );

      await tester.enterText(find.byKey(const Key('settle-up-amount-field')), '12.5');
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byKey(const Key('settle-up-confirm-button')));
      expect(button.onPressed, isNull);
      expect(find.text(_loc.settleUpAmountMustBeWhole), findsOneWidget);
    });

    testWidgets('an amount above the backend maximum is refused', (tester) async {
      final writer = FakeSettlementWriter();

      await _pumpSheet(
        tester,
        sheet: SettleUpSheet(
          writer: writer,
          idToken: () async => 'tok',
          selfUserId: 'self-1',
          otherUserId: 'other-1',
          otherDisplayName: 'Bo',
          balanceAmount: 450,
          currency: 'TWD',
          today: '2026-08-02',
        ),
      );

      await tester.enterText(find.byKey(const Key('settle-up-amount-field')), '2147483648');
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byKey(const Key('settle-up-confirm-button')));
      expect(button.onPressed, isNull);
      expect(find.text(_loc.settleUpAmountTooLarge), findsOneWidget);
    });
  });

  group('SettleUpSheet — overpay warning (two directions, one each)', () {
    testWidgets('I am paying them and overpay: they end up owing me', (tester) async {
      final writer = FakeSettlementWriter();

      await _pumpSheet(
        tester,
        sheet: SettleUpSheet(
          writer: writer,
          idToken: () async => 'tok',
          selfUserId: 'self-1',
          otherUserId: 'other-1',
          otherDisplayName: 'Bo',
          balanceAmount: -450,
          currency: 'TWD',
          today: '2026-08-02',
        ),
      );

      await tester.enterText(find.byKey(const Key('settle-up-amount-field')), '600');
      await tester.pump();

      expect(find.text(_loc.settleUpOverpayWarningTheyWillOwe('Bo', '150')), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byKey(const Key('settle-up-confirm-button')));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('they are paying me and it is recorded as an overpay: I end up owing them', (
      tester,
    ) async {
      final writer = FakeSettlementWriter();

      await _pumpSheet(
        tester,
        sheet: SettleUpSheet(
          writer: writer,
          idToken: () async => 'tok',
          selfUserId: 'self-1',
          otherUserId: 'other-1',
          otherDisplayName: 'Bo',
          balanceAmount: 450,
          currency: 'TWD',
          today: '2026-08-02',
        ),
      );

      await tester.enterText(find.byKey(const Key('settle-up-amount-field')), '600');
      await tester.pump();

      expect(find.text(_loc.settleUpOverpayWarningYouWillOwe('Bo', '150')), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byKey(const Key('settle-up-confirm-button')));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('an exact payment shows no overpay warning', (tester) async {
      final writer = FakeSettlementWriter();

      await _pumpSheet(
        tester,
        sheet: SettleUpSheet(
          writer: writer,
          idToken: () async => 'tok',
          selfUserId: 'self-1',
          otherUserId: 'other-1',
          otherDisplayName: 'Bo',
          balanceAmount: 450,
          currency: 'TWD',
          today: '2026-08-02',
        ),
      );

      expect(find.byKey(const Key('settle-up-overpay-warning')), findsNothing);
    });
  });

  group('SettleUpSheet — submission lifecycle', () {
    testWidgets('disables confirm while submitting', (tester) async {
      final writer = FakeSettlementWriter();

      await _pumpSheet(
        tester,
        sheet: SettleUpSheet(
          writer: writer,
          idToken: () async => 'tok',
          selfUserId: 'self-1',
          otherUserId: 'other-1',
          otherDisplayName: 'Bo',
          balanceAmount: 450,
          currency: 'TWD',
          today: '2026-08-02',
        ),
      );

      await tester.tap(find.byKey(const Key('settle-up-confirm-button')));
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byKey(const Key('settle-up-confirm-button')));
      expect(button.onPressed, isNull);
    });

    testWidgets('a failed submission keeps every typed field and shows an error', (tester) async {
      final writer = FakeSettlementWriter()..failNext = Exception('boom');

      await _pumpSheet(
        tester,
        sheet: SettleUpSheet(
          writer: writer,
          idToken: () async => 'tok',
          selfUserId: 'self-1',
          otherUserId: 'other-1',
          otherDisplayName: 'Bo',
          balanceAmount: 450,
          currency: 'TWD',
          today: '2026-08-02',
        ),
      );

      await tester.enterText(find.byKey(const Key('settle-up-amount-field')), '300');
      await tester.enterText(find.byKey(const Key('settle-up-note-field')), 'partial repay');
      await tester.pump();
      await tester.tap(find.byKey(const Key('settle-up-confirm-button')));
      await tester.pumpAndSettle();

      expect(find.text('300'), findsOneWidget);
      expect(find.text('partial repay'), findsOneWidget);
      expect(find.text(_loc.splitErrorGeneric), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byKey(const Key('settle-up-confirm-button')));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('note is omitted (null) when left blank', (tester) async {
      final writer = FakeSettlementWriter();

      await _pumpSheet(
        tester,
        sheet: SettleUpSheet(
          writer: writer,
          idToken: () async => 'tok',
          selfUserId: 'self-1',
          otherUserId: 'other-1',
          otherDisplayName: 'Bo',
          balanceAmount: 450,
          currency: 'TWD',
          today: '2026-08-02',
        ),
      );

      await tester.tap(find.byKey(const Key('settle-up-confirm-button')));
      await tester.pumpAndSettle();

      expect(writer.gotNote, isNull);
    });

    testWidgets('the day defaults to today', (tester) async {
      final writer = FakeSettlementWriter();

      await _pumpSheet(
        tester,
        sheet: SettleUpSheet(
          writer: writer,
          idToken: () async => 'tok',
          selfUserId: 'self-1',
          otherUserId: 'other-1',
          otherDisplayName: 'Bo',
          balanceAmount: 450,
          currency: 'TWD',
          today: '2026-08-02',
        ),
      );

      await tester.tap(find.byKey(const Key('settle-up-confirm-button')));
      await tester.pumpAndSettle();

      expect(writer.gotDay, '2026-08-02');
    });
  });

  group('SettleUpSheet — an unknown display name falls back cleanly', () {
    testWidgets('null otherDisplayName shows the generic label', (tester) async {
      final writer = FakeSettlementWriter();

      await _pumpSheet(
        tester,
        sheet: SettleUpSheet(
          writer: writer,
          idToken: () async => 'tok',
          selfUserId: 'self-1',
          otherUserId: 'other-1',
          otherDisplayName: null,
          balanceAmount: 450,
          currency: 'TWD',
          today: '2026-08-02',
        ),
      );

      expect(find.text(_loc.settleUpTitleReceiving(_loc.splitUnknownMember)), findsOneWidget);
    });
  });
}
