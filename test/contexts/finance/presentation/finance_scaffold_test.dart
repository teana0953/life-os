import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/finance/domain/networth_account.dart';
import 'package:life_os/contexts/finance/presentation/finance_scaffold.dart';

import '../../../support/l10n_test_app.dart';
import '../finance_test_support.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<String?> idToken() async => 'tok';

  @override
  Stream<bool> get authStateChanges => const Stream.empty();

  @override
  Future<void> signOut() async {}

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}
}

/// Locates the drag handle Flutter renders for `showModalBottomSheet(
/// showDragHandle: true)`. The handle itself is the SDK-private `_DragHandle`
/// widget (`material/bottom_sheet.dart`), so it is matched structurally by what
/// it uniquely renders: a 48x48 `Semantics` **button** labelled with the
/// modal-barrier dismiss label, *inside* the sheet. Without `showDragHandle`
/// the sheet's child is the builder's content alone and nothing matches.
Finder _dragHandleIn(WidgetTester tester, Finder sheet) {
  final label = MaterialLocalizations.of(
    tester.element(sheet),
  ).modalBarrierDismissLabel;
  return find.descendant(
    of: sheet,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.button == true &&
          widget.properties.label == label,
    ),
  );
}

/// Asserts the currently open bottom sheet has a working drag handle — the
/// only close affordance left when a tall sheet fills the viewport.
void _expectSheetHasDragHandle(WidgetTester tester) {
  final sheet = find.byType(BottomSheet);
  expect(sheet, findsOneWidget);
  final handle = _dragHandleIn(tester, sheet);
  expect(handle, findsOneWidget);
  // The handle's interactive area, i.e. the region a pull-down can grab.
  expect(tester.getSize(handle), const Size(48, 48));
}

void main() {
  group('FinanceScaffold', () {
    testWidgets('shows both bottom-nav destinations and switches tabs', (
      tester,
    ) async {
      final repo = FakeFinanceRepository();
      final controller = testFinanceController(repo);

      await tester.pumpWidget(
        l10nTestApp(
          home: FinanceScaffold(
            authRepository: _FakeAuthRepository(),
            controller: controller,
            netWorthController: testNetWorthController(repo),
            clock: () => DateTime(2026, 7, 15),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('finance-empty-title')), findsOneWidget);

      await tester.tap(find.byIcon(Icons.list_alt_outlined));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('finance-transactions-empty')), findsOneWidget);
    });

    testWidgets('the FAB opens the record sheet', (tester) async {
      final repo = FakeFinanceRepository();
      final controller = testFinanceController(repo);

      await tester.pumpWidget(
        l10nTestApp(
          home: FinanceScaffold(
            authRepository: _FakeAuthRepository(),
            controller: controller,
            netWorthController: testNetWorthController(repo),
            clock: () => DateTime(2026, 7, 15),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('finance-fab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('amount-field')), findsOneWidget);
      expect(find.byKey(const Key('save-transaction-button')), findsOneWidget);
    });

    testWidgets('the 淨值 tab loads its own month, independent of the ledger', (
      tester,
    ) async {
      final repo = FakeFinanceRepository()..seedSnapshot('acc-cash', '2026-07', 1234);
      final controller = testFinanceController(repo);
      final netWorthController = testNetWorthController(repo);

      await tester.pumpWidget(
        l10nTestApp(
          home: FinanceScaffold(
            authRepository: _FakeAuthRepository(),
            controller: controller,
            netWorthController: netWorthController,
            clock: () => DateTime(2026, 7, 15),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The net worth tab is not loaded until it's actually opened.
      expect(netWorthController.selectedMonth, isEmpty);

      await tester.tap(find.byKey(const Key('networth-tab')));
      await tester.pumpAndSettle();

      expect(netWorthController.selectedMonth, '2026-07');
      expect(find.byKey(const Key('networth-net-value')), findsOneWidget);
      expect(find.byKey(const Key('networth-month-label')), findsOneWidget);
      // The transaction FAB doesn't belong on the net worth tab.
      expect(find.byKey(const Key('finance-fab')), findsNothing);

      // Switching the net worth month leaves the ledger's month alone.
      await tester.tap(find.byKey(const Key('networth-month-previous')));
      await tester.pumpAndSettle();

      expect(netWorthController.selectedMonth, '2026-06');
      expect(controller.selectedMonth, '2026-07');
    });

    testWidgets('re-entering finance reloads the 淨值 tab, keeping its month', (
      tester,
    ) async {
      final repo = FakeFinanceRepository()..seedSnapshot('acc-cash', '2026-07', 1234);
      final netWorthController = testNetWorthController(repo);

      Widget scaffold() => l10nTestApp(
        home: FinanceScaffold(
          authRepository: _FakeAuthRepository(),
          controller: testFinanceController(repo),
          netWorthController: netWorthController,
          clock: () => DateTime(2026, 7, 15),
        ),
      );

      await tester.pumpWidget(scaffold());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('networth-tab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('networth-month-previous')));
      await tester.pumpAndSettle();

      expect(netWorthController.selectedMonth, '2026-06');
      expect(repo.trendCalls.length, 2);

      // Leave finance entirely (the State is disposed), then come back. The
      // controller is an app-lifetime singleton, so without a per-State
      // "already loaded" flag the tab would never refetch.
      await tester.pumpWidget(l10nTestApp(home: const Scaffold(body: Text('away'))));
      await tester.pumpAndSettle();
      await tester.pumpWidget(scaffold());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('networth-tab')));
      await tester.pumpAndSettle();

      expect(repo.trendCalls.length, 3);
      // The month the user was last looking at is kept, not reset to today.
      expect(netWorthController.selectedMonth, '2026-06');
    });

    testWidgets('tapping an account row opens the value sheet', (tester) async {
      final repo = FakeFinanceRepository()..seedSnapshot('acc-cash', '2026-07', 1234);

      await tester.pumpWidget(
        l10nTestApp(
          home: FinanceScaffold(
            authRepository: _FakeAuthRepository(),
            controller: testFinanceController(repo),
            netWorthController: testNetWorthController(repo),
            clock: () => DateTime(2026, 7, 15),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('networth-tab')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('account-row-acc-cash')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('snapshot-field')), findsOneWidget);
    });

    testWidgets('the manage button opens the account management sheet', (
      tester,
    ) async {
      final repo = FakeFinanceRepository();

      await tester.pumpWidget(
        l10nTestApp(
          home: FinanceScaffold(
            authRepository: _FakeAuthRepository(),
            controller: testFinanceController(repo),
            netWorthController: testNetWorthController(repo),
            clock: () => DateTime(2026, 7, 15),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('networth-tab')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('account-manage-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('account-add-name')), findsOneWidget);
    });

    group('sheets carry a drag handle, and it is what closes them', () {
      // Opened from the scaffold itself, not by pumping the sheet widget with a
      // local showModalBottomSheet — the bug lives in the scaffold's call sites,
      // so a test that supplies its own sheet route could never catch it.
      Future<void> pumpScaffold(WidgetTester tester, FakeFinanceRepository repo) async {
        await tester.pumpWidget(
          l10nTestApp(
            home: FinanceScaffold(
              authRepository: _FakeAuthRepository(),
              controller: testFinanceController(repo),
              netWorthController: testNetWorthController(repo),
              clock: () => DateTime(2026, 7, 15),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('the record sheet', (tester) async {
        await pumpScaffold(tester, FakeFinanceRepository());

        await tester.tap(find.byKey(const Key('finance-fab')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('amount-field')), findsOneWidget);
        _expectSheetHasDragHandle(tester);
      });

      testWidgets('the budget sheet', (tester) async {
        await pumpScaffold(tester, FakeFinanceRepository());

        await tester.tap(find.byKey(const Key('budget-edit-button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('budget-sheet-save')), findsOneWidget);
        _expectSheetHasDragHandle(tester);
      });

      testWidgets('the snapshot sheet', (tester) async {
        await pumpScaffold(
          tester,
          FakeFinanceRepository()..seedSnapshot('acc-cash', '2026-07', 1234),
        );

        await tester.tap(find.byKey(const Key('networth-tab')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('account-row-acc-cash')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('snapshot-field')), findsOneWidget);
        _expectSheetHasDragHandle(tester);
      });

      testWidgets('the account management sheet', (tester) async {
        await pumpScaffold(tester, FakeFinanceRepository());

        await tester.tap(find.byKey(const Key('networth-tab')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('account-manage-button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('account-add-name')), findsOneWidget);
        _expectSheetHasDragHandle(tester);
      });

      /// Enough accounts that the management sheet's content is taller than the
      /// viewport — the state the user actually hit. On a phone (<= the M3
      /// sheet maxWidth of 640) the sheet then covers the screen edge to edge
      /// with no scrim left to tap, so a broken handle leaves it inescapable
      /// rather than merely degraded. (This test's 800px-wide viewport keeps
      /// side scrim; the vertical fill, which is what the drag exercises, is
      /// the same.)
      FakeFinanceRepository tallAccountsRepo() {
        return FakeFinanceRepository()
          ..accounts = [
            for (var i = 0; i < 14; i++)
              NetWorthAccount(
                id: 'acc-asset-$i',
                kind: NetWorthKind.asset,
                name: '資產 $i',
                sortOrder: i,
                archived: false,
              ),
            for (var i = 0; i < 6; i++)
              NetWorthAccount(
                id: 'acc-liab-$i',
                kind: NetWorthKind.liability,
                name: '負債 $i',
                sortOrder: i,
                archived: false,
              ),
          ];
      }

      Future<Finder> openTallAccountSheet(WidgetTester tester) async {
        await pumpScaffold(tester, tallAccountsRepo());
        await tester.tap(find.byKey(const Key('networth-tab')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('account-manage-button')));
        await tester.pumpAndSettle();

        final sheet = find.byType(BottomSheet);
        expect(find.byKey(const Key('account-add-name')), findsOneWidget);
        // Precondition for everything below: the sheet really does fill the
        // viewport, leaving no scrim to tap outside of.
        final sheetRect = tester.getRect(sheet);
        final viewport = tester.view.physicalSize / tester.view.devicePixelRatio;
        expect(sheetRect.top, lessThanOrEqualTo(0));
        expect(sheetRect.height, greaterThanOrEqualTo(viewport.height));
        return sheet;
      }

      testWidgets('pulling the handle down closes a viewport-filling sheet', (
        tester,
      ) async {
        final sheet = await openTallAccountSheet(tester);

        await tester.drag(_dragHandleIn(tester, sheet), const Offset(0, 500));
        await tester.pumpAndSettle();

        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byKey(const Key('account-add-name')), findsNothing);
        // Closed the sheet, not popped the whole finance route — the original
        // complaint was that the only way out took the user off the screen.
        expect(find.byType(FinanceScaffold), findsOneWidget);
        expect(find.byKey(const Key('networth-tab')), findsOneWidget);
        expect(find.byKey(const Key('account-manage-button')), findsOneWidget);
      });

      testWidgets('dragging the content, unlike the handle, never closes the sheet', (
        tester,
      ) async {
        final sheet = await openTallAccountSheet(tester);

        // Well below the 48px handle strip: the content's own scrollable, which
        // is exactly what swallowed the pull-down before the handle existed.
        final sheetRect = tester.getRect(sheet);
        await tester.dragFrom(
          Offset(sheetRect.center.dx, sheetRect.top + 300),
          const Offset(0, 500),
        );
        await tester.pumpAndSettle();

        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.byKey(const Key('account-add-name')), findsOneWidget);
      });
    });
  });
}
