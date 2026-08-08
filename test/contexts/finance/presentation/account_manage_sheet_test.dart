import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/finance/domain/finance_exceptions.dart';
import 'package:life_os/contexts/finance/domain/networth_account.dart';
import 'package:life_os/contexts/finance/presentation/account_manage_sheet.dart';
import 'package:life_os/contexts/finance/presentation/networth_controller.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';
import '../../../support/month_label.dart';
import '../finance_test_support.dart';

const _locale = Locale('en');
final _loc = lookupAppLocalizations(_locale);

Future<NetWorthController> _pumpSheet(
  WidgetTester tester,
  FakeFinanceRepository repo, {
  // 600dp is a desk-width surface no phone has. It is the default because most
  // of these tests are about behaviour, not layout — but the row this sheet
  // draws now carries a name field plus up to four controls, so anything that
  // widens it has to be checked at a real phone width too. See the 320dp guard
  // at the end of this file.
  Size surface = const Size(600, 1600),
}) async {
  await tester.binding.setSurfaceSize(surface);
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

/// The on-screen top-to-bottom order of the given account rows.
List<String> displayedOrder(WidgetTester tester, List<String> ids) {
  final byDy = [
    for (final id in ids)
      (id: id, dy: tester.getTopLeft(find.byKey(Key('account-name-$id'))).dy),
  ]..sort((a, b) => a.dy.compareTo(b.dy));
  return [for (final row in byDy) row.id];
}

/// Past the sheet's reorder debounce, then let the write settle. A plain
/// `pumpAndSettle` does not do it: the debounce is a `Timer`, not an
/// animation, so no frame is scheduled for it and settling returns at once
/// with the write never sent.
Future<void> letTheWriteGo(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

void main() {
  _reorderResponsivenessTests();

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
      await letTheWriteGo(tester);

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
      await letTheWriteGo(tester);

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
      await letTheWriteGo(tester);
      await tester.tap(find.byKey(const Key('account-move-up-a3')));
      await letTheWriteGo(tester);

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


    testWidgets('the down button moves a row down, and the last row cannot', (
      tester,
    ) async {
      // Every other new test taps move-up only, so the whole down half — the
      // feature this change adds — rode on "the shared _reorder is already
      // covered". It is not: swapping `isFirstInGroup` and `isLastInGroup`, or
      // wiring the down icon to `_moveUp`, would leave all of them green.
      final repo = FakeFinanceRepository()
        ..accounts = [
          tiedAsset('a1', 'First'),
          tiedAsset('a2', 'Second'),
          tiedAsset('a3', 'Third'),
        ];
      await _pumpSheet(tester, repo);

      await tester.tap(find.byKey(const Key('account-move-down-a1')));
      await letTheWriteGo(tester);

      expect(
        displayedOrder(tester, ['a1', 'a2', 'a3']),
        ['a2', 'a1', 'a3'],
        reason: '按向下後,a1 必須落到 a2 下面 — 而不是往上,也不是不動',
      );

      // The ends, each disabled on its own side. Asserted together because a
      // swapped pair of flags satisfies either one alone.
      final order = displayedOrder(tester, ['a1', 'a2', 'a3']);
      final firstUp = tester.widget<IconButton>(
        find.byKey(Key('account-move-up-${order.first}')),
      );
      final lastDown = tester.widget<IconButton>(
        find.byKey(Key('account-move-down-${order.last}')),
      );
      expect(firstUp.onPressed, isNull, reason: '第一列不能再往上');
      expect(lastDown.onPressed, isNull, reason: '最後一列不能再往下');
      // And the other end of each is live, so "disable everything" fails too.
      expect(
        tester.widget<IconButton>(
          find.byKey(Key('account-move-down-${order.first}')),
        ).onPressed,
        isNotNull,
      );
      expect(
        tester.widget<IconButton>(
          find.byKey(Key('account-move-up-${order.last}')),
        ).onPressed,
        isNotNull,
      );
    });

    testWidgets('reordering is one atomic call, not one write per account', (
      tester,
    ) async {
      // The point of the batch endpoint. Every other reorder test passes with
      // the per-account loop this replaced, because the fake ends up in the
      // same state either way — only the call log tells them apart, and a loop
      // is what leaves a half-renumbered group behind when it fails midway.
      final repo = FakeFinanceRepository()
        ..accounts = [
          tiedAsset('a1', 'First'),
          tiedAsset('a2', 'Second'),
          tiedAsset('a3', 'Third'),
        ];
      await _pumpSheet(tester, repo);
      repo.networthCalls.clear();

      await tester.tap(find.byKey(const Key('account-move-up-a3')));
      await letTheWriteGo(tester);

      expect(
        repo.networthCalls.where((c) => c.startsWith('reorder:')).length,
        1,
        reason: '整組重編必須是一次呼叫',
      );
      expect(
        repo.networthCalls.where((c) => c.startsWith('update:')).length,
        0,
        reason: '不能再逐筆送 updateAccount',
      );
      // The one call carries the whole group in its new order, archived
      // included — a call that sent only the two swapped ids would satisfy the
      // count above.
      expect(repo.networthCalls.single, 'reorder:asset:a1,a3,a2');
    });

    testWidgets('the account row lays out on a 320dp phone at textScale 2.0', (
      tester,
    ) async {
      // The row now holds a name field plus up to four controls (save, up,
      // down, archive) and every other test in this file runs at 600dp — a
      // width no phone has. This project has repeatedly shipped rows that only
      // break below 360dp, and an overflow raises a real error, so the guard
      // is cheap: render the widest state (a dirty name, so the save icon is
      // present too) at the narrowest supported width.
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      useTextScaleFactor(tester, 2.0);

      final repo = FakeFinanceRepository()
        ..accounts = [tiedAsset('a1', 'First'), tiedAsset('a2', 'Second')];
      await _pumpSheet(tester, repo, surface: const Size(320, 800));

      // Dirty the name so the save icon joins the row — the widest it gets.
      await tester.enterText(
        find.byKey(const Key('account-name-a1')),
        'A considerably longer account name',
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}

/// Reordering, from the user's side of the wait (issue #136: "每次調整順序都
/// 要等一陣子,如果要把某個項目調離原本距離很遠的話會很慢").
///
/// Each tap used to be a write **plus** a full month reload — three parallel
/// requests for something that only changes a display order — with the whole
/// sheet disabled meanwhile. Walking an account past five others meant five
/// of those, one at a time.
void _reorderResponsivenessTests() {
  NetWorthAccount tied(String id, String name) => NetWorthAccount(
    id: id,
    kind: NetWorthKind.asset,
    name: name,
    sortOrder: 0,
    archived: false,
  );

  FakeFinanceRepository threeTied() => FakeFinanceRepository()
    ..accounts = [tied('a1', 'First'), tied('a2', 'Second'), tied('a3', 'Third')];

  group('AccountManageSheet — reordering does not make the user wait', () {
    testWidgets('the row moves before any request finishes', (tester) async {
      final repo = threeTied();
      final gate = Completer<void>();
      repo.reorderGate = gate.future;
      await _pumpSheet(tester, repo);

      await tester.tap(find.byKey(const Key('account-move-up-a3')));
      await tester.pump();

      // Still in flight, and the list has already moved. `pump` without
      // settle is the whole point: `pumpAndSettle` would wait out exactly the
      // latency being measured.
      expect(gate.isCompleted, isFalse);
      expect(displayedOrder(tester, ['a1', 'a2', 'a3']), ['a1', 'a3', 'a2']);

      gate.complete();
      await letTheWriteGo(tester);
      expect(displayedOrder(tester, ['a1', 'a2', 'a3']), ['a1', 'a3', 'a2']);
    });

    testWidgets('the buttons stay live, so a burst of taps is possible at all', (tester) async {
      final repo = threeTied();
      final gate = Completer<void>();
      repo.reorderGate = gate.future;
      await _pumpSheet(tester, repo);

      await tester.tap(find.byKey(const Key('account-move-up-a3')));
      await tester.pump();

      // Disabled-while-busy is what made a far move N sequential waits: the
      // second tap could not even be registered until the first round trip
      // came back.
      expect(
        tester.widget<IconButton>(find.byKey(const Key('account-move-up-a3'))).onPressed,
        isNotNull,
      );

      gate.complete();
      await letTheWriteGo(tester);
    });

    testWidgets('a burst of taps is one request carrying the final order', (tester) async {
      final repo = threeTied();
      await _pumpSheet(tester, repo);
      repo.networthCalls.clear();

      // Walking a3 to the top: two taps in a row, as fast as a person can
      // press them.
      await tester.tap(find.byKey(const Key('account-move-up-a3')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('account-move-up-a3')));
      await letTheWriteGo(tester);

      expect(displayedOrder(tester, ['a1', 'a2', 'a3']), ['a3', 'a1', 'a2']);
      final reorders = repo.networthCalls.where((c) => c.startsWith('reorder:')).toList();
      // One call, and it carries where the account ended up — not the
      // intermediate order the first tap produced.
      expect(reorders, ['reorder:asset:a3,a1,a2']);
    });

    testWidgets('reordering does not refetch the month', (tester) async {
      // The reload was three parallel requests (accounts, monthly, trend) for
      // a change to a display order the client already knows in full.
      final repo = threeTied();
      await _pumpSheet(tester, repo);
      final trendsBefore = repo.trendCalls.length;

      await tester.tap(find.byKey(const Key('account-move-up-a3')));
      await letTheWriteGo(tester);

      expect(repo.trendCalls.length, trendsBefore);
    });

    testWidgets('closing the sheet right after a tap still sends the write', (tester) async {
      // The debounce cannot become a way to lose the change: a user who taps
      // and immediately dismisses the sheet meant it.
      final repo = threeTied();
      final controller = testNetWorthController(repo);
      await controller.load('token', '2026-07');
      var showSheet = true;
      await tester.pumpWidget(
        l10nTestApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: Column(
                children: [
                  TextButton(
                    key: const Key('close-sheet'),
                    onPressed: () => setState(() => showSheet = false),
                    child: const Text('close'),
                  ),
                  if (showSheet)
                    Expanded(
                      child: AnimatedBuilder(
                        animation: controller,
                        builder: (context, _) => AccountManageSheet(
                          controller: controller,
                          idToken: () async => 'token',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      repo.networthCalls.clear();

      await tester.tap(find.byKey(const Key('account-move-up-a3')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('close-sheet')));
      // A zero-duration frame first, so the sheet is really gone before the
      // clock moves. `pump(500ms)` advances time *then* builds, which fires
      // the debounce while the sheet is still mounted — the write goes out
      // through the ordinary path and the dispose flush is never exercised.
      // Written the obvious way, this test passed with that flush deleted.
      await tester.pump();
      expect(find.byKey(const Key('account-move-up-a3')), findsNothing);
      await letTheWriteGo(tester);

      expect(
        repo.networthCalls.where((c) => c.startsWith('reorder:')).toList(),
        ['reorder:asset:a1,a3,a2'],
      );
    });

    testWidgets('a failed write puts the order back and says so', (tester) async {
      // Optimism has to be reversible. Left alone, the screen would keep
      // showing an order the server never accepted, and the next reload would
      // silently undo it in front of the user.
      final repo = threeTied();
      await _pumpSheet(tester, repo);
      // Armed after the initial load, which would otherwise spend it.
      repo.failNext = const FinanceFetchFailure('boom');

      await tester.tap(find.byKey(const Key('account-move-up-a3')));
      await letTheWriteGo(tester);

      expect(displayedOrder(tester, ['a1', 'a2', 'a3']), ['a1', 'a2', 'a3']);
      expect(find.text(_loc.financeSaveFailed), findsOneWidget);
    });
  });
}
