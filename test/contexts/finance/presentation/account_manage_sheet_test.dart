import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/finance/domain/networth_account.dart';
import 'package:life_os/contexts/finance/presentation/account_manage_sheet.dart';
import 'package:life_os/contexts/finance/presentation/networth_controller.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';
import '../finance_test_support.dart';

const _locale = Locale('en');
final _loc = lookupAppLocalizations(_locale);

Future<NetWorthController> _pumpSheet(
  WidgetTester tester,
  FakeFinanceRepository repo,
) async {
  await tester.binding.setSurfaceSize(const Size(600, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final controller = testNetWorthController(repo);
  await controller.load('token', '2026-07');
  await tester.pumpWidget(
    l10nTestApp(
      home: Scaffold(
        body: AnimatedBuilder(
          animation: controller,
          builder: (context, _) =>
              AccountManageSheet(controller: controller, idToken: () async => 'token'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

const _twoAssets = [
  NetWorthAccount(
    id: 'a1',
    kind: NetWorthKind.asset,
    name: 'First',
    sortOrder: 0,
    archived: false,
  ),
  NetWorthAccount(
    id: 'a2',
    kind: NetWorthKind.asset,
    name: 'Second',
    sortOrder: 1,
    archived: false,
  ),
];

void main() {
  group('AccountManageSheet', () {
    testWidgets('adds an account with the chosen kind and name', (tester) async {
      final repo = FakeFinanceRepository();
      final controller = await _pumpSheet(tester, repo);

      await tester.tap(find.byKey(const Key('account-add-kind-liability')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('account-add-name')), '車貸');
      await tester.pump();
      await tester.tap(find.byKey(const Key('account-add-submit')));
      await tester.pumpAndSettle();

      expect(repo.networthCalls, contains('create:liability:車貸'));
      expect(controller.accounts.map((a) => a.name), contains('車貸'));
    });

    testWidgets('the add button stays disabled without a name', (tester) async {
      await _pumpSheet(tester, FakeFinanceRepository());

      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('account-add-submit')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('renaming an account submits the new name', (tester) async {
      final repo = FakeFinanceRepository();
      final controller = await _pumpSheet(tester, repo);

      await tester.enterText(find.byKey(const Key('account-name-acc-cash')), '主帳戶');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(repo.networthCalls.single, contains('name=主帳戶'));
      expect(
        controller.accounts.firstWhere((a) => a.id == 'acc-cash').name,
        '主帳戶',
      );
    });

    testWidgets('a typed name is saved by the explicit save button', (
      tester,
    ) async {
      final repo = FakeFinanceRepository();
      final controller = await _pumpSheet(tester, repo);

      // No save control until the field actually differs from the account.
      expect(find.byKey(const Key('account-name-save-acc-cash')), findsNothing);

      await tester.enterText(find.byKey(const Key('account-name-acc-cash')), '主帳戶');
      await tester.pump();

      // The edit is visibly unsaved, and saving it is one tap away — it is
      // never silently dropped by tapping some other control.
      final save = find.byKey(const Key('account-name-save-acc-cash'));
      expect(save, findsOneWidget);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(repo.networthCalls.single, contains('name=主帳戶'));
      expect(
        controller.accounts.firstWhere((a) => a.id == 'acc-cash').name,
        '主帳戶',
      );
      // Saved: nothing left pending on screen.
      expect(find.byKey(const Key('account-name-save-acc-cash')), findsNothing);
    });

    testWidgets('an emptied name shows an error and cannot be saved', (
      tester,
    ) async {
      final repo = FakeFinanceRepository();
      await _pumpSheet(tester, repo);

      await tester.enterText(find.byKey(const Key('account-name-acc-cash')), '   ');
      await tester.pump();

      expect(find.text(_loc.networthAccountNameRequired), findsOneWidget);
      expect(find.byKey(const Key('account-name-save-acc-cash')), findsNothing);

      // Submitting anyway writes nothing — and says so rather than silently
      // discarding the edit.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(repo.networthCalls, isEmpty);
      expect(find.text(_loc.networthAccountNameRequired), findsOneWidget);
    });

    testWidgets('archiving an account keeps it listed here, restorable', (
      tester,
    ) async {
      final repo = FakeFinanceRepository();
      final controller = await _pumpSheet(tester, repo);

      await tester.tap(find.byKey(const Key('account-archive-acc-cash')));
      await tester.pumpAndSettle();

      expect(
        controller.accounts.firstWhere((a) => a.id == 'acc-cash').archived,
        isTrue,
      );
      expect(find.text(_loc.networthArchivedLabel), findsOneWidget);
      expect(find.text(_loc.networthRestoreButton), findsOneWidget);

      await tester.tap(find.byKey(const Key('account-archive-acc-cash')));
      await tester.pumpAndSettle();

      expect(
        controller.accounts.firstWhere((a) => a.id == 'acc-cash').archived,
        isFalse,
      );
    });

    testWidgets('a new account gets its name field without build creating it', (
      tester,
    ) async {
      final repo = FakeFinanceRepository();
      final controller = await _pumpSheet(tester, repo);

      await tester.enterText(find.byKey(const Key('account-add-name')), '新帳戶');
      await tester.pump();
      await tester.tap(find.byKey(const Key('account-add-submit')));
      await tester.pumpAndSettle();

      // The row for an account that did not exist at the last build is seeded
      // and settled in the frame the controller's notification triggers —
      // building a row must stay a pure read, never a create-and-subscribe.
      final id = controller.accounts.firstWhere((a) => a.name == '新帳戶').id;
      final field = tester.widget<TextField>(find.byKey(Key('account-name-$id')));
      expect(field.controller?.text, '新帳戶');
      expect(tester.takeException(), isNull);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('the reorder button never moves as a rename comes and goes', (
      tester,
    ) async {
      final repo = FakeFinanceRepository()..accounts = _twoAssets;
      await _pumpSheet(tester, repo);

      final moveUp = find.byKey(const Key('account-move-up-a2'));
      final atRest = tester.getTopLeft(moveUp);

      // A pending rename adds a save button to the same row...
      await tester.enterText(find.byKey(const Key('account-name-a2')), 'Renamed');
      await tester.pump();
      expect(find.byKey(const Key('account-name-save-a2')), findsOneWidget);
      expect(tester.getTopLeft(moveUp), atRest);

      // ...and saving takes it away again. Neither may slide the reorder
      // button under the finger that just tapped save: reordering has no undo.
      await tester.tap(find.byKey(const Key('account-name-save-a2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account-name-save-a2')), findsNothing);
      expect(tester.getTopLeft(moveUp), atRest);
    });

    testWidgets('moving an account up swaps its order with the one above', (
      tester,
    ) async {
      final repo = FakeFinanceRepository()
        ..accounts = const [
          NetWorthAccount(
            id: 'a1',
            kind: NetWorthKind.asset,
            name: 'First',
            sortOrder: 0,
            archived: false,
          ),
          NetWorthAccount(
            id: 'a2',
            kind: NetWorthKind.asset,
            name: 'Second',
            sortOrder: 1,
            archived: false,
          ),
        ];
      final controller = await _pumpSheet(tester, repo);

      // The topmost account has nothing to swap with.
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('account-move-up-a1')))
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const Key('account-move-up-a2')));
      await tester.pumpAndSettle();

      expect(controller.accounts.firstWhere((a) => a.id == 'a2').sortOrder, 0);
      expect(controller.accounts.firstWhere((a) => a.id == 'a1').sortOrder, 1);
    });

    // Issue #130: every user-created account arrives with sortOrder 0 (the
    // create call never sends one and the backend defaults to 0), so ties are
    // the *normal* state, not an edge case. These three tests pin each
    // reported symptom against tied-sortOrder fixtures.

    NetWorthAccount tiedAsset(String id, String name) => NetWorthAccount(
      id: id,
      kind: NetWorthKind.asset,
      name: name,
      sortOrder: 0,
      archived: false,
    );

    // The on-screen top-to-bottom order of the given account rows.
    List<String> displayedOrder(WidgetTester tester, List<String> ids) {
      final byDy = [
        for (final id in ids)
          (id: id, dy: tester.getTopLeft(find.byKey(Key('account-name-$id'))).dy),
      ]..sort((a, b) => a.dy.compareTo(b.dy));
      return [for (final row in byDy) row.id];
    }

    testWidgets('moving up an account tied at sortOrder 0 actually reorders', (
      tester,
    ) async {
      // Both rows tied at 0 — the state every pair of user-created accounts
      // is in. Swapping the two sortOrders (0 <-> 0) is a no-op.
      final repo = FakeFinanceRepository()
        ..accounts = [tiedAsset('a1', 'First'), tiedAsset('a2', 'Second')];
      await _pumpSheet(tester, repo);

      expect(displayedOrder(tester, ['a1', 'a2']), ['a1', 'a2']);

      await tester.tap(find.byKey(const Key('account-move-up-a2')));
      await tester.pumpAndSettle();

      // Symptom (2)/(1): pressing "up" must visibly move the row up.
      expect(
        displayedOrder(tester, ['a1', 'a2']),
        ['a2', 'a1'],
        reason: '按向上後,原本在下面的 a2 必須顯示在 a1 上面',
      );
    });

    testWidgets('repeated move-up walks a tied account all the way to the top', (
      tester,
    ) async {
      final repo = FakeFinanceRepository()
        ..accounts = [
          tiedAsset('a1', 'First'),
          tiedAsset('a2', 'Second'),
          tiedAsset('a3', 'Third'),
        ];
      await _pumpSheet(tester, repo);

      expect(displayedOrder(tester, ['a1', 'a2', 'a3']), ['a1', 'a2', 'a3']);

      // Symptom (1): the bottom account, moved up once per gap, must reach
      // the very top of its group.
      await tester.tap(find.byKey(const Key('account-move-up-a3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account-move-up-a3')));
      await tester.pumpAndSettle();

      expect(
        displayedOrder(tester, ['a1', 'a2', 'a3']),
        ['a3', 'a1', 'a2'],
        reason: '連按兩次向上後,a3 必須排在最上面',
      );
    });

    testWidgets('the same accounts reloaded in a different arrival order '
        'display in the same order', (tester) async {
      // The backend guarantees no row order for tied sortOrders, so "the same
      // data" can legitimately arrive in a different sequence on any reload.
      final repo = FakeFinanceRepository()
        ..accounts = [tiedAsset('a1', 'First'), tiedAsset('a2', 'Second')];
      final controller = await _pumpSheet(tester, repo);

      final firstLoad = displayedOrder(tester, ['a1', 'a2']);

      repo.accounts = [tiedAsset('a2', 'Second'), tiedAsset('a1', 'First')];
      await controller.load('token', '2026-07');
      await tester.pumpAndSettle();

      // Symptom (2): display order must be a function of the data, not of
      // the order the rows happened to arrive in.
      expect(
        displayedOrder(tester, ['a1', 'a2']),
        firstLoad,
        reason: '同樣的兩筆科目重新載入後,顯示順序必須跟第一次載入一致',
      );
    });
  });
}
