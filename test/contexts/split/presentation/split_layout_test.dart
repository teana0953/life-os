import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/finance/domain/finance_category.dart';
import 'package:life_os/contexts/finance/domain/finance_transaction.dart';
import 'package:life_os/contexts/finance/domain/finance_type.dart';
import 'package:life_os/contexts/finance/domain/split_spending.dart';
import 'package:life_os/contexts/finance/presentation/finance_overview_tab.dart';
import 'package:life_os/contexts/finance/presentation/finance_scaffold.dart';
import 'package:life_os/contexts/social/application/friend_use_cases.dart';
import 'package:life_os/contexts/social/domain/friend.dart';
import 'package:life_os/contexts/split/application/activity_use_cases.dart';
import 'package:life_os/contexts/split/application/balance_use_cases.dart';
import 'package:life_os/contexts/split/application/expense_use_cases.dart';
import 'package:life_os/contexts/split/application/group_use_cases.dart';
import 'package:life_os/contexts/split/domain/split_exceptions.dart';
import 'package:life_os/contexts/split/application/settlement_use_cases.dart';
import 'package:life_os/contexts/split/domain/balance.dart';
import 'package:life_os/contexts/split/domain/group_member.dart';
import 'package:life_os/contexts/split/domain/settlement.dart';
import 'package:life_os/contexts/split/domain/split_activity.dart';
import 'package:life_os/contexts/split/domain/split_expense.dart';
import 'package:life_os/contexts/split/domain/split_group.dart';
import 'package:life_os/contexts/split/domain/split_share.dart';
import 'package:life_os/contexts/split/presentation/group_detail_screen.dart';
import 'package:life_os/contexts/split/presentation/settle_up_sheet.dart';
import 'package:life_os/contexts/split/presentation/settlement_writer.dart';
import 'package:life_os/contexts/split/presentation/split_activity_controller.dart';
import 'package:life_os/contexts/split/presentation/split_activity_section.dart';
import 'package:life_os/contexts/split/presentation/split_controller.dart';
import 'package:life_os/contexts/split/presentation/split_expense_row.dart';
import 'package:life_os/contexts/split/presentation/split_expense_sheet.dart';
import 'package:life_os/contexts/split/presentation/split_tab.dart';
import 'package:life_os/contexts/split/presentation/split_tab_dependencies.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/date/day_format.dart';
import 'package:life_os/shared/widgets/ledge_card.dart';

import '../../../support/l10n_test_app.dart';
import '../../../support/layout_guard.dart';
import '../../../support/month_label.dart';
import '../../finance/finance_test_support.dart';
import '../support/fake_split_repository.dart';
import '../support/split_presentation_fakes.dart';

const _self = 'self-1';
final _loc = lookupAppLocalizations(const Locale('en'));

/// A realistic phone viewport height (design.md task 9.1 — deliberately not
/// the 2400dp-tall surface an earlier guard used elsewhere in this repo,
/// which is taller than any real phone and is exactly how a dialog overflow
/// slipped through there).
const _phoneHeight = 800.0;

const _longName =
    'Alexandria Bartholomew-Featherstonehaugh the Third of Wonderland';

/// The amount every expense in the narrow-width sweep carries.
///
/// Not the 900 the other fixtures use: QA measured the expense row's real
/// failure region on the amount, and it starts at NT$10,000 — 900 (and every
/// amount below 10,000) lays out cleanly at 320dp/2x whether the row is
/// broken or not, so a sweep pinned at 900 could not fail and read as
/// coverage it never gave (the same shape as the nav-bar ellipsis check
/// below, which could never fail either). 1,234,567 sits well inside that
/// region — the widest amount an ordinary trip expense plausibly reaches,
/// seven digits plus separators — so this sweep goes red the moment the
/// amount is put back anywhere it can claim the whole tile.
const _wideAmount = 1234567;

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<String?> idToken() async => 'tok';

  @override
  Stream<bool> get authStateChanges => const Stream.empty();

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {}
}

SplitExpense _expense({
  String id = 'e1',
  String? groupId,
  String description = 'Dinner',
  String day = '2026-08-02',
  String payerUserId = _self,
  String createdByUserId = _self,
  int amount = 900,
  List<SplitShare> shares = const [],
}) => SplitExpense(
  id: id,
  groupId: groupId,
  payerUserId: payerUserId,
  payerDisplayName: 'Payer',
  createdByUserId: createdByUserId,
  amount: amount,
  currency: 'TWD',
  description: description,
  day: day,
  splitMode: 'equal',
  shares: shares,
  createdAt: '2026-08-02T00:00:00.000Z',
  updatedAt: '2026-08-02T00:00:00.000Z',
);

SplitController _loadedController({
  List<Balance> balances = const [],
  List<SplitGroup> groups = const [],
  List<SplitExpense> expenses = const [],
  List<Settlement> settlements = const [],
}) {
  final repo = FakeSplitRepository();
  return SplitController(
      GetBalances(repo),
      ListGroups(repo),
      ListExpenses(repo),
      CreateExpense(repo),
      UpdateExpense(repo),
      DeleteExpense(repo),
      CreateGroup(repo),
      ListFriends(FakeSocialRepositoryForSplit()),
      GetProfile(FakeProfileRepository()),
      ListSettlements(repo),
      CreateSettlement(repo),
      DeleteSettlement(repo),
    )
    ..status = SplitStatus.loaded
    ..selfUserId = _self
    ..balances = balances
    ..groups = groups
    ..expenses = expenses
    ..settlements = settlements;
}

Widget _splitTabScreen({required SplitController controller}) => Scaffold(
  body: SplitTab(
    onAddFriend: () {},
    controller: controller,
    activityController: testSplitActivityController(),
    onRetry: () {},
    onRecordExpense: () {},
    onOpenGroup: (_) {},
    onCreateGroup: () {},
    onEditExpense: (_) {},
    onSettleUp: ({
      required otherUserId,
      required otherDisplayName,
      required balanceAmount,
      required currency,
    }) {},
    onDeleteSettlement: (_) {},
    onSignInAgain: () {},
  ),
);

Widget _groupDetailScreen({
  required FakeSplitRepository repo,
  String selfUserId = _self,
  Locale locale = const Locale('en'),
}) => l10nRouterTestApp(
  locale: locale,
  home: GroupDetailScreen(
    getGroup: GetGroup(repo),
    getGroupBalances: GetGroupBalances(repo),
    listExpenses: ListExpenses(repo),
    addGroupMember: AddGroupMember(repo),
    archiveGroup: ArchiveGroup(repo),
    createExpense: CreateExpense(repo),
    updateExpense: UpdateExpense(repo),
    deleteExpense: DeleteExpense(repo),
    listFriends: ListFriends(FakeSocialRepositoryForSplit()),
    getBalances: GetBalances(repo),
    createSettlement: CreateSettlement(repo),
    getProfile: GetProfile(FakeProfileRepository()..profileToReturn = testProfile(id: selfUserId)),
    authRepository: _FakeAuthRepository(),
    groupId: 'g1',
    clock: () => DateTime(2026, 8, 2),
  ),
);

Widget _expenseSheet({
  required FakeSplitRepository repo,
  List<Friend> friends = const [],
  SplitExpense? editing,
  Locale locale = const Locale('en'),
}) => l10nTestApp(
  locale: locale,
  home: Scaffold(
    body: SplitExpenseSheet(
      onAddFriend: () {},
      writer: SplitController(
        GetBalances(repo),
        ListGroups(repo),
        ListExpenses(repo),
        CreateExpense(repo),
        UpdateExpense(repo),
        DeleteExpense(repo),
        CreateGroup(repo),
        ListFriends(FakeSocialRepositoryForSplit()),
        GetProfile(FakeProfileRepository()),
        ListSettlements(repo),
        CreateSettlement(repo),
        DeleteSettlement(repo),
      ),
      idToken: () async => 'tok',
      selfUserId: _self,
      today: '2026-08-02',
      friends: friends,
      editing: editing,
    ),
  ),
);

/// [FinanceScaffold] wired with an inert split fake — used for the
/// four-destination nav-bar guard (task 9.2), which cares about the shell
/// itself, not any tab's data.
Widget _financeScaffold(FakeSplitRepository repo, {Locale locale = const Locale('en')}) {
  final financeRepo = FakeFinanceRepository();
  return l10nTestApp(
    locale: locale,
    home: FinanceScaffold(
      authRepository: _FakeAuthRepository(),
      controller: testFinanceController(financeRepo),
      netWorthController: testNetWorthController(financeRepo),
      split: SplitTabDependencies(
        onAddFriend: (_) {},
        getBalances: GetBalances(repo),
        listGroups: ListGroups(repo),
        listExpenses: ListExpenses(repo),
        createExpense: CreateExpense(repo),
        updateExpense: UpdateExpense(repo),
        deleteExpense: DeleteExpense(repo),
        createGroup: CreateGroup(repo),
        listFriends: ListFriends(FakeSocialRepositoryForSplit()),
        getProfile: GetProfile(FakeProfileRepository()..profileToReturn = testProfile()),
        listSettlements: ListSettlements(repo),
        createSettlement: CreateSettlement(repo),
        deleteSettlement: DeleteSettlement(repo),
        listActivity: ListActivity(repo),
        onOpenGroup: (_, __) async {},
      ),
      clock: () => DateTime(2026, 8, 2),
    ),
  );
}

/// A [SettlementWriter] that never actually submits — for layout guards,
/// which only care that the sheet lays out cleanly, never tap confirm.
class _InertSettlementWriter implements SettlementWriter {
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
  }) async {}
}

Widget _settleUpSheetScreen({Locale locale = const Locale('en')}) => l10nTestApp(
  locale: locale,
  home: Scaffold(
    body: SettleUpSheet(
      writer: _InertSettlementWriter(),
      idToken: () async => 'tok',
      selfUserId: _self,
      otherUserId: 'u2',
      otherDisplayName: 'Bo',
      // Seven-figure amount (task 7.4/design.md's own fixture rule) — 900
      // sits outside the failure region and could not fail this guard.
      balanceAmount: _wideAmount,
      currency: 'TWD',
      today: '2026-08-02',
    ),
  ),
);

/// The recorded-ledger half of the overview, seeded so the guard below
/// actually builds it.
///
/// The version this replaces seeded split spending *only*, so
/// `summary.totals`/`summary.byCategory` came back empty, the overview took
/// its `isEmpty` branch, and `_CurrencyTotalsCard`/`_CategoryBreakdown` — half
/// the screen the guard names — were never in the tree at all. It could not
/// fail, and it hid a real overflow in those rows (QA round 2).
///
/// What each part of the fixture is for:
///
/// * **Two currencies**, so more than one `_CurrencyTotalsCard` is built and
///   the guard covers the repeated shape rather than a single instance.
/// * **A seven-figure amount** ([_wideAmount]) on expense, income *and* net,
///   because those three `_TotalRow`s are what overflowed: below NT$10,000
///   every one of them lays out cleanly at 320dp/2x whether the row is broken
///   or not (same failure-region reasoning as [_wideAmount] itself).
/// * **Three expense categories**, one of them named [_longName], so
///   `_CategoryBar`'s label-plus-amount row is exercised with a label long
///   enough to fight the amount for the row — the case that decides whether
///   the label wraps or the amount is pushed off the edge.
void _seedOverviewLedger(FakeFinanceRepository repo) {
  repo.categoriesToReturn = [
    ...repo.categoriesToReturn,
    const FinanceCategory(
      id: 'cat-long',
      name: _longName,
      type: FinanceType.expense,
      icon: 'other',
      sortOrder: 2,
      archived: false,
    ),
  ];
  repo.byMonth['2026-08'] = const [
    FinanceTransaction(
      id: 't1',
      type: FinanceType.expense,
      amount: _wideAmount,
      currency: 'TWD',
      categoryId: 'cat-food',
      date: '2026-08-02',
    ),
    FinanceTransaction(
      id: 't2',
      type: FinanceType.expense,
      amount: 456789,
      currency: 'TWD',
      categoryId: 'cat-long',
      date: '2026-08-02',
    ),
    FinanceTransaction(
      id: 't3',
      type: FinanceType.income,
      amount: _wideAmount,
      currency: 'TWD',
      categoryId: 'cat-salary',
      date: '2026-08-01',
    ),
    FinanceTransaction(
      id: 't4',
      type: FinanceType.expense,
      amount: _wideAmount,
      currency: 'USD',
      categoryId: 'cat-transport',
      date: '2026-08-03',
    ),
  ];
}

Widget _financeOverviewScreen(FakeFinanceRepository repo, {Locale locale = const Locale('en')}) {
  final controller = testFinanceController(repo);
  return l10nTestApp(
    locale: locale,
    home: Scaffold(
      body: FutureBuilder<void>(
        future: controller.load('tok', '2026-08'),
        builder: (context, snapshot) => FinanceOverviewTab(
          controller: controller,
          onSwitchMonth: (_) async {},
          onAdd: () {},
          onEditBudgets: () {},
          onSignInAgain: () {},
        ),
      ),
    ),
  );
}

/// The change-log entry the guard below measures: an **amount change**, by
/// somebody with a long display name, on something with a long description.
///
/// Each part is load-bearing. The amount change is the only shape that puts
/// *two* figures and an arrow in one label; the long name and description are
/// what make the headline fight it for the row. An ordinary "Amy edited
/// Dinner / 2,000" entry lays out acceptably even under the broken shape at
/// 1.0 and would not carry this guard.
///
/// 18,000 → 12,500 rather than the seven-figure [_wideAmount] the other
/// sweeps use: at textScale 2.0 a seven-figure amount is wider than the whole
/// tile at every width in this file (see the overview guard's own note), so
/// **no** layout could keep it on one line and an assertion on it would be a
/// false one. These are the figures QA measured the break on.
SplitActivity _amountChangeEntry({String id = 'a1'}) => SplitActivity(
  id: id,
  type: SplitActivityType.expenseUpdated,
  actorUserId: 'u-amy',
  actorDisplayName: _longName,
  groupId: null,
  groupName: null,
  subjectId: 'e1',
  counterpartUserId: null,
  counterpartDisplayName: null,
  amount: 12500,
  previousAmount: 18000,
  actorIsPayer: null,
  currency: 'TWD',
  description: _longName,
  createdAt: '2026-08-01T10:30:00.000Z',
);

Widget _changeLogScreen(FakeSplitRepository repo, {required Locale locale}) => l10nTestApp(
  locale: locale,
  home: Scaffold(
    body: SplitActivitySection(
      controller: SplitActivityController(
        listActivity: ListActivity(repo),
        getProfile: GetProfile(FakeProfileRepository()..profileToReturn = testProfile()),
        idToken: () async => 'tok',
      ),
      onSignInAgain: () {},
      // Pinned so the timestamp is the same under TZ=UTC (CI) and UTC+8.
      toLocalTime: (instant) => instant.toUtc(),
    ),
  ),
);

/// One [SplitExpenseRow] in the same shell the change log puts its own rows
/// in — the 600dp-capped, 20dp-padded `ListView` of a [LedgeCard] per row.
///
/// This is the *baseline* the guard compares against, and it is rebuilt here
/// rather than reached through the split tab so that both rows are measured
/// under exactly the same width, padding and card, with the same long
/// description and the same amount. Anything else would compare two different
/// geometries and prove nothing about the row.
Widget _expenseRowInSameShell(Locale locale) => l10nTestApp(
  locale: locale,
  home: Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            LedgeCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SplitExpenseRow(
                expense: _expense(description: _longName, amount: 12500),
                selfUserId: _self,
                keyPrefix: 'split-expense',
                onEdit: () {},
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  group('split screens: narrow-width layout guard (task 9.1)', () {
    for (final width in [320.0, 360.0]) {
      for (final locale in testSupportedLocales) {
        for (final textScale in [1.0, 2.0]) {
          testWidgets(
            'SplitTab lays out cleanly at ${width.toInt()}dp, textScale=$textScale, locale=$locale',
            (tester) async {
              useTextScaleFactor(tester, textScale);
              await tester.binding.setSurfaceSize(Size(width, _phoneHeight));
              addTearDown(() => tester.binding.setSurfaceSize(null));

              final controller = _loadedController(
                balances: const [
                  Balance(
                    userId: 'u2',
                    displayName: 'Bo',
                    balances: [
                      CurrencyBalance(currency: 'TWD', amount: 500),
                      CurrencyBalance(currency: 'USD', amount: -200),
                    ],
                  ),
                ],
                groups: const [
                  SplitGroup(id: 'g1', name: 'Trip', createdByUserId: _self, archivedAt: null),
                ],
                expenses: [_expense(amount: _wideAmount)],
              );

              await expectNoLayoutErrors(() async {
                await tester.pumpWidget(
                  MaterialApp(
                    locale: locale,
                    localizationsDelegates: AppLocalizations.localizationsDelegates,
                    supportedLocales: testSupportedLocales,
                    home: _splitTabScreen(controller: controller),
                  ),
                );
                await tester.pumpAndSettle();
              });

              expect(find.byKey(const Key('split-owed-to-me-0')), findsOneWidget);
            },
          );

          testWidgets(
            'GroupDetailScreen lays out cleanly at ${width.toInt()}dp, textScale=$textScale, locale=$locale',
            (tester) async {
              useTextScaleFactor(tester, textScale);
              await tester.binding.setSurfaceSize(Size(width, _phoneHeight));
              addTearDown(() => tester.binding.setSurfaceSize(null));

              final repo = FakeSplitRepository()
                ..groupToReturn = const SplitGroup(
                  id: 'g1',
                  name: 'Trip',
                  createdByUserId: _self,
                  archivedAt: null,
                )
                ..membersToReturn = const [
                  GroupMember(
                    groupId: 'g1',
                    userId: _self,
                    displayName: 'Self',
                    joinedAt: '2026-01-01T00:00:00Z',
                  ),
                  GroupMember(
                    groupId: 'g1',
                    userId: 'u2',
                    displayName: 'Bo',
                    joinedAt: '2026-01-01T00:00:00Z',
                  ),
                ]
                ..balancesToReturn = const [
                  Balance(
                    userId: 'u2',
                    displayName: 'Bo',
                    balances: [CurrencyBalance(currency: 'TWD', amount: 300)],
                  ),
                ]
                // A wide amount here too (design D8's new "your balance with
                // each member" section, task 5b.5/7.4) — covers the settle
                // icon sitting next to a seven-figure amount in the same
                // sweep as the group balances above.
                ..personalBalancesToReturn = const [
                  Balance(
                    userId: 'u2',
                    displayName: 'Bo',
                    balances: [CurrencyBalance(currency: 'TWD', amount: _wideAmount)],
                  ),
                ]
                ..expensesToReturn = [_expense(groupId: 'g1', amount: _wideAmount)];

              await expectNoLayoutErrors(() async {
                await tester.pumpWidget(_groupDetailScreen(repo: repo, locale: locale));
                await tester.pumpAndSettle();
              });

              expect(find.byKey(const Key('split-member-row-u2')), findsOneWidget);
            },
          );

          testWidgets(
            'SplitExpenseSheet lays out cleanly at ${width.toInt()}dp, textScale=$textScale, locale=$locale',
            (tester) async {
              useTextScaleFactor(tester, textScale);
              await tester.binding.setSurfaceSize(Size(width, _phoneHeight));
              addTearDown(() => tester.binding.setSurfaceSize(null));

              final repo = FakeSplitRepository();

              await expectNoLayoutErrors(() async {
                await tester.pumpWidget(
                  _expenseSheet(
                    repo: repo,
                    friends: const [Friend(userId: 'u2', displayName: 'Bo')],
                    locale: locale,
                  ),
                );
                await tester.pumpAndSettle();
              });

              expect(find.byKey(const Key('split-save-button')), findsOneWidget);

              // The exact-split mode adds a per-participant amount field —
              // its own row shape, so it gets its own layout pass.
              final loc = lookupAppLocalizations(locale);
              await expectNoLayoutErrors(() async {
                await tester.tap(find.text(loc.splitModeExact));
                await tester.pumpAndSettle();
              });
            },
          );
        }
      }
    }

    testWidgets('FinanceScaffold (all four destinations) lays out cleanly at 320dp, textScale=2.0', (
      tester,
    ) async {
      useTextScaleFactor(tester, 2.0);
      await tester.binding.setSurfaceSize(const Size(320, _phoneHeight));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await expectNoLayoutErrors(() async {
        await tester.pumpWidget(_financeScaffold(FakeSplitRepository()));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('split-tab')));
        await tester.pumpAndSettle();
      });

      expect(find.byKey(const Key('split-fab')), findsOneWidget);
    });
  });

  group('the fourth nav-bar destination (task 9.2)', () {
    // Which locale actually carries this guard: **English only**. Reverting
    // the `height:` override in `FinanceScaffold` reddens the `en` case and
    // nothing else — the labels that outgrow an 80dp slot are the two-word
    // English ones ("Transactions", "Net worth"), which wrap to two lines at
    // textScale 2.0. Every zh-Hant destination label is two characters
    // (總覽/交易/淨值/分帳); they cannot wrap, so no assertion here can be
    // made to bite in that locale without inventing copy. The zh-Hant cases
    // are still run — they are the regression net for a future longer
    // translation — but they are not what proves the override necessary.
    for (final locale in testSupportedLocales) {
      testWidgets(
        'all four destinations keep their painted label inside their own slot at 320dp, '
        'textScale=2.0, locale=$locale',
        (tester) async {
          useTextScaleFactor(tester, 2.0);
          await tester.binding.setSurfaceSize(const Size(320, _phoneHeight));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await expectNoLayoutErrors(
            () => tester.pumpWidget(_financeScaffold(FakeSplitRepository(), locale: locale)),
          );
          await tester.pumpAndSettle();

          final loc = lookupAppLocalizations(locale);
          final labels = [
            loc.financeTabOverview,
            loc.financeTabTransactions,
            loc.financeTabNetWorth,
            loc.financeTabSplit,
          ];

          final navBar = find.byType(NavigationBar);
          expect(navBar, findsOneWidget);
          final navBarRect = tester.getRect(navBar);

          final rects = <Rect>[];
          for (final label in labels) {
            final finder = find.descendant(of: navBar, matching: find.text(label));
            expect(
              finder,
              findsOneWidget,
              reason: 'destination label "$label" was not found as its own painted text',
            );
            rects.add(tester.getRect(finder));
          }

          // `NavigationBar` builds each label as a bare `Text` with no
          // `maxLines`, so `RenderParagraph.didExceedMaxLines` is false for
          // every label at every width — an ellipsis check here could never
          // fail and read as coverage it did not provide. What *can* fail is
          // geometry: a label too big for its share of the bar paints outside
          // that share (vertically first — a wrapped label grows past the
          // bar's own height long before it overlaps its neighbour).
          final slotWidth = navBarRect.width / labels.length;
          for (var i = 0; i < rects.length; i++) {
            final slot = Rect.fromLTWH(
              navBarRect.left + i * slotWidth,
              navBarRect.top,
              slotWidth,
              navBarRect.height,
            );
            final rect = rects[i];
            expect(
              rect.left >= slot.left - 0.5 &&
                  rect.right <= slot.right + 0.5 &&
                  rect.top >= slot.top - 0.5 &&
                  rect.bottom <= slot.bottom + 0.5,
              isTrue,
              reason:
                  'destination label "${labels[i]}" painted $rect, outside its '
                  'own destination slot $slot',
            );
          }
        },
      );
    }

    // The `height:` override the guard above forced is a deliberate,
    // bounded trade, pinned here so it stays one. It is a `max` against 80 —
    // Material 3's own `_NavigationBarDefaultsM3.height` — so every text
    // scale up to 80/70 ≈ 1.14 renders exactly the bar the three
    // pre-existing tabs (總覽/交易/淨值) had before this change. Past that
    // threshold the bar does grow for all four, which is intended: it is
    // precisely where the labels themselves have outgrown the default, and
    // clamping the bar there would clip the user's chosen text size rather
    // than honour it.
    for (final (scale, expectedHeight) in [(1.0, 80.0), (1.14, 80.0), (2.0, 140.0)]) {
      testWidgets('the nav bar is $expectedHeight dp tall at textScale=$scale', (tester) async {
        useTextScaleFactor(tester, scale);
        await tester.binding.setSurfaceSize(const Size(320, _phoneHeight));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(_financeScaffold(FakeSplitRepository()));
        await tester.pumpAndSettle();

        expect(tester.getSize(find.byType(NavigationBar)).height, expectedHeight);
      });
    }
  });

  group('destructive confirmation dialogs (task 9.3)', () {
    for (final width in [320.0, 360.0]) {
      testWidgets(
        'archiving a group keeps Cancel and confirm reachable at ${width.toInt()}dp, textScale=2.0',
        (tester) async {
          useTextScaleFactor(tester, 2.0);
          await tester.binding.setSurfaceSize(Size(width, _phoneHeight));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final repo = FakeSplitRepository()
            ..groupToReturn = const SplitGroup(
              id: 'g1',
              name: _longName,
              createdByUserId: _self,
              archivedAt: null,
            )
            ..membersToReturn = const [
              GroupMember(
                groupId: 'g1',
                userId: _self,
                displayName: 'Self',
                joinedAt: '2026-01-01T00:00:00Z',
              ),
            ];

          await expectNoLayoutErrors(() async {
            await tester.pumpWidget(_groupDetailScreen(repo: repo));
            await tester.pumpAndSettle();
            // At textScale 2.0 the archive button sits below the fold of
            // this phone-height viewport, past a plain `ListView`'s
            // SliverList cache extent — it isn't built into the tree yet, so
            // `ensureVisible` (which needs the element to already exist)
            // can't reach it. `scrollUntilVisible` drags incrementally,
            // which is what actually realizes it — mirroring the friends
            // page's own revoke-dialog guard.
            await tester.scrollUntilVisible(find.byKey(const Key('split-archive-button')), 200);
            // `scrollUntilVisible` stops as soon as the element's Rect
            // intersects the viewport at all — that can leave it clipped
            // right at the edge, where its geometric center (what `tap()`
            // targets) isn't actually hit-testable. `ensureVisible` nudges
            // it fully into view.
            await tester.ensureVisible(find.byKey(const Key('split-archive-button')));
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const Key('split-archive-button')));
            await tester.pumpAndSettle();
          });

          final cancelRect = tester.getRect(find.byKey(const Key('split-archive-cancel')));
          final confirmRect = tester.getRect(find.byKey(const Key('split-archive-confirm')));
          expect(cancelRect.bottom, lessThanOrEqualTo(_phoneHeight));
          expect(confirmRect.bottom, lessThanOrEqualTo(_phoneHeight));

          await tester.tap(find.byKey(const Key('split-archive-confirm')));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('split-archive-confirm')), findsNothing);
        },
      );

      testWidgets(
        'deleting an expense keeps Cancel and confirm reachable at ${width.toInt()}dp, textScale=2.0',
        (tester) async {
          useTextScaleFactor(tester, 2.0);
          await tester.binding.setSurfaceSize(Size(width, _phoneHeight));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final repo = FakeSplitRepository();
          final editing = _expense(id: 'e1', description: _longName);

          await expectNoLayoutErrors(() async {
            await tester.pumpWidget(_expenseSheet(repo: repo, editing: editing));
            await tester.pumpAndSettle();
            // The delete button is the sheet's last row — at textScale 2.0
            // on a narrow screen it can sit below the fold. Unlike the
            // archive button above, the sheet's `SingleChildScrollView`
            // builds its single child eagerly (no sliver laziness), so the
            // element already exists and a direct `ensureVisible` (rather
            // than `scrollUntilVisible`'s incremental drag loop, which threw
            // spuriously here) is enough to bring it on screen.
            await tester.ensureVisible(find.byKey(const Key('split-delete-button')));
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const Key('split-delete-button')));
            await tester.pumpAndSettle();
          });

          final cancelRect = tester.getRect(find.byKey(const Key('split-delete-cancel')));
          final confirmRect = tester.getRect(find.byKey(const Key('split-delete-confirm')));
          expect(cancelRect.bottom, lessThanOrEqualTo(_phoneHeight));
          expect(confirmRect.bottom, lessThanOrEqualTo(_phoneHeight));
        },
      );
    }
  });

  group('a long display name (task 9.4)', () {
    testWidgets(
      "a long participant name in the exact-split row wraps or shrinks and the "
      'amount field stays fully within the viewport',
      (tester) async {
        const width = 320.0;
        await tester.binding.setSurfaceSize(const Size(width, _phoneHeight));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final repo = FakeSplitRepository();

        await expectNoLayoutErrors(() async {
          await tester.pumpWidget(
            _expenseSheet(
              repo: repo,
              friends: const [Friend(userId: 'u2', displayName: _longName)],
            ),
          );
          await tester.pumpAndSettle();
          // Bring the long-named friend into the split and switch to exact
          // mode, where name and amount are laid out as separate widgets
          // (the equal-mode preview and the balance rows elsewhere are a
          // single merged sentence, so they carry no such risk).
          await tester.tap(find.byKey(const Key('split-participant-u2')));
          await tester.pumpAndSettle();
          await tester.tap(find.text(_loc.splitModeExact));
          await tester.pumpAndSettle();
        });

        final amountFieldFinder = find.byKey(const Key('split-exact-field-u2'));
        expect(amountFieldFinder, findsOneWidget);
        final amountRect = tester.getRect(amountFieldFinder);
        expect(amountRect.right, lessThanOrEqualTo(width));
        expect(amountRect.left, greaterThanOrEqualTo(0));
      },
    );
  });

  group('expense day is a calendar date, not an instant (task 9.5b)', () {
    // `day` is a plain `YYYY-MM-DD` string fed straight to
    // `mediumDateLabelOrDash` (design.md task 9.5) — never through
    // `parseInstant`/`toLocalTime`, which would shift it by a day depending
    // on the host's offset from UTC. This pins the day actually painted
    // against the *local, date-only* parse (`DateTime(year, month, day)`,
    // never `DateTime.utc`/`.toLocal()`), so the assertion itself would
    // catch a regression under whatever offset the test happens to run
    // under — this machine's local time and a `TZ=UTC flutter test` rerun
    // (design.md's own re-verification step) between them cover both a
    // positive and a zero UTC offset.
    testWidgets('a split expense recorded on a given day shows that exact day, unshifted', (
      tester,
    ) async {
      final controller = _loadedController(expenses: [_expense(id: 'e1', day: '2026-01-01')]);

      await tester.pumpWidget(l10nTestApp(home: _splitTabScreen(controller: controller)));
      await tester.pumpAndSettle();

      final expected = mediumDateLabel(
        tester.element(find.byKey(const Key('split-expense-row-e1'))),
        DateTime(2026, 1, 1),
      );
      // A wrong-by-one-day parse (e.g. `parseInstant('2026-01-01').toLocal()`
      // under a negative offset) would paint Dec 31 2025 instead — comparing
      // against the exact expected label, not just "found *a* date", is what
      // would catch that.
      expect(find.text(_loc.splitExpensePaidBy('Payer', expected)), findsOneWidget);
    });
  });

  group('settle-up surfaces: narrow-width layout guard (add-settle-up-ui task 7.4)', () {
    for (final width in [320.0, 360.0]) {
      for (final locale in testSupportedLocales) {
        for (final textScale in [1.0, 2.0]) {
          testWidgets(
            'SettleUpSheet lays out cleanly at ${width.toInt()}dp, textScale=$textScale, locale=$locale',
            (tester) async {
              useTextScaleFactor(tester, textScale);
              await tester.binding.setSurfaceSize(Size(width, _phoneHeight));
              addTearDown(() => tester.binding.setSurfaceSize(null));

              await expectNoLayoutErrors(() async {
                await tester.pumpWidget(_settleUpSheetScreen(locale: locale));
                await tester.pumpAndSettle();
              });

              expect(find.byKey(const Key('settle-up-confirm-button')), findsOneWidget);
              final confirmRect = tester.getRect(find.byKey(const Key('settle-up-confirm-button')));
              expect(confirmRect.bottom, lessThanOrEqualTo(_phoneHeight));
            },
          );

          testWidgets(
            'the reason a settle-up amount is refused stays readable at ${width.toInt()}dp, '
            'textScale=$textScale, locale=$locale',
            (tester) async {
              useTextScaleFactor(tester, textScale);
              await tester.binding.setSurfaceSize(Size(width, _phoneHeight));
              addTearDown(() => tester.binding.setSurfaceSize(null));

              final loc = lookupAppLocalizations(locale);

              await expectNoLayoutErrors(() async {
                await tester.pumpWidget(_settleUpSheetScreen(locale: locale));
                await tester.pumpAndSettle();
              });

              // TWD has no decimals, so a fractional amount is refused
              // outright; 2147483648 is one past the backend maximum.
              for (final (input, message) in [
                ('450.5', loc.settleUpAmountMustBeWhole),
                ('2147483648', loc.settleUpAmountTooLarge),
              ]) {
                await expectNoLayoutErrors(() async {
                  await tester.enterText(find.byKey(const Key('settle-up-amount-field')), input);
                  await tester.pumpAndSettle();
                });

                // Confirm really is blocked — otherwise the message below is
                // not the reason for anything.
                final button = tester.widget<FilledButton>(
                  find.byKey(const Key('settle-up-confirm-button')),
                );
                expect(button.onPressed, isNull);

                // Not "no layout error was raised": these sentences used to
                // go into the amount field's 120dp `errorText`, whose default
                // `errorMaxLines: 1` **clips** them — silently, raising
                // nothing at all, which is why the sweep above was green
                // while the user faced a dead Confirm with no readable
                // reason. (Same shape as the nav-bar guard's ellipsis check,
                // which could never fail either.) Measure the painted
                // paragraph instead, wherever it is rendered.
                final finder = find.text(message);
                expect(finder, findsOneWidget, reason: 'the refusal reason was not painted at all');
                final paragraph = tester.renderObject<RenderParagraph>(
                  find.descendant(of: finder, matching: find.byType(RichText)),
                );
                expect(
                  paragraph.didExceedMaxLines,
                  isFalse,
                  reason: '"$message" was clipped rather than laid out in full',
                );
                final rect = tester.getRect(finder);
                expect(rect.left, greaterThanOrEqualTo(0));
                expect(rect.right, lessThanOrEqualTo(width));
              }
            },
          );

          testWidgets(
            'a repayment row lays out cleanly at ${width.toInt()}dp, textScale=$textScale, locale=$locale',
            (tester) async {
              useTextScaleFactor(tester, textScale);
              await tester.binding.setSurfaceSize(Size(width, _phoneHeight));
              addTearDown(() => tester.binding.setSurfaceSize(null));

              final controller = _loadedController(
                settlements: [
                  Settlement(
                    id: 's1',
                    groupId: null,
                    fromUserId: 'u2',
                    fromDisplayName: 'Bo',
                    toUserId: _self,
                    toDisplayName: 'Self',
                    amount: _wideAmount,
                    currency: 'TWD',
                    day: '2026-08-02',
                    note: null,
                    createdByUserId: 'u2',
                  ),
                ],
              );

              await expectNoLayoutErrors(() async {
                await tester.pumpWidget(
                  MaterialApp(
                    locale: locale,
                    localizationsDelegates: AppLocalizations.localizationsDelegates,
                    supportedLocales: testSupportedLocales,
                    home: _splitTabScreen(controller: controller),
                  ),
                );
                await tester.pumpAndSettle();
                // Below a plain `ListView`'s SliverList cache extent at a
                // large text scale, the row isn't built into the tree yet —
                // `scrollUntilVisible` drags incrementally to realize it
                // (mirrors the group-detail archive-button guard above).
                await tester.scrollUntilVisible(
                  find.byKey(const Key('split-settlement-row-s1')),
                  200,
                );
              });

              expect(find.byKey(const Key('split-settlement-row-s1')), findsOneWidget);
            },
          );

          testWidgets(
            'the overview lays out cleanly at ${width.toInt()}dp, '
            'textScale=$textScale, locale=$locale',
            (tester) async {
              useTextScaleFactor(tester, textScale);
              await tester.binding.setSurfaceSize(Size(width, _phoneHeight));
              addTearDown(() => tester.binding.setSurfaceSize(null));

              // Both a counted and an uncounted currency, because the
              // split-spending card is no longer one sentence and one list:
              // it is two headed groups, each with its own sentence. A
              // single-currency fixture only ever builds one of them, so the
              // widget that actually grew would ship through a sweep that
              // never swept it.
              final repo = FakeFinanceRepository()
                ..splitSpendingByMonth['2026-08'] = [
                  const SplitSpending(
                    currency: 'TWD',
                    amount: _wideAmount,
                    countedInTransactions: true,
                  ),
                  const SplitSpending(
                    currency: 'THB',
                    amount: _wideAmount,
                    countedInTransactions: false,
                  ),
                ];
              _seedOverviewLedger(repo);
              final loc = lookupAppLocalizations(locale);

              await expectNoLayoutErrors(() async {
                await tester.pumpWidget(_financeOverviewScreen(repo, locale: locale));
                await tester.pumpAndSettle();
                // The totals cards, the split-spending card and the category
                // breakdown sit below the fold at a large text scale, so a
                // single pump never builds all of them — the sweep has to drag
                // the whole list past to see every row (same reason as the
                // repayment-row guard above). Down to the recent-transactions
                // heading, which is below every card, then back up so the
                // assertions below have the split-spending card in the tree.
                await tester.scrollUntilVisible(
                  find.text(loc.financeRecentTransactions),
                  200,
                );
                await tester.scrollUntilVisible(
                  find.text(loc.financeSplitSpendingTitle),
                  -200,
                );
              });

              expect(find.text(loc.financeSplitSpendingTitle), findsOneWidget);
            },
          );
        }
      }
    }

    // The sweep above cannot see this, and that is the point: a wrapped amount
    // raises **no** layout error, so `expectNoLayoutErrors` stays green while
    // `+1,234,567` paints as `+1,234,5` / `67` — two lines, broken
    // mid-digit-group, reading as two numbers (QA round 3). Same shape as the
    // refusal-reason and nav-bar-label guards above: "nothing threw" is not a
    // criterion for anything the renderer degrades silently, so measure the
    // painted paragraph instead.
    //
    // Swept from 320dp, not 360dp. An earlier version of this guard started at
    // 360 on the premise that "320dp does not fit either shape"; measured, that
    // was wrong, and skipping 320 is how QA round 4 found the row still broken
    // at the narrowest width everything else in this file sweeps. The numbers,
    // textScale 1.0, `bodyLarge`/w700, the amount `-1,234,567`:
    //
    //   screen  tile title  amount natural  main (trailing)  shipped shape
    //   320dp   236.0dp     165.0dp         165.0dp -> 1 ln  165.0dp -> 1 ln
    //   360dp   276.0dp     165.0dp         165.0dp -> 1 ln  165.0dp -> 1 ln
    //   375dp   291.0dp     165.0dp         165.0dp -> 1 ln  165.0dp -> 1 ln
    //   390dp   306.0dp     165.0dp         165.0dp -> 1 ln  165.0dp -> 1 ln
    //   412dp   328.0dp     165.0dp         165.0dp -> 1 ln  165.0dp -> 1 ln
    //
    // The shape between those two — the amount inside a `LabelValueRow`, whose
    // cap is a fixed 65% of the row — allowed only (236 - 12) * 0.65 = 145.6dp
    // at 320dp and painted `-1,234,5` / `67`. 390 and 412 are swept even though
    // they have never failed: the failure region moves with the shape, and the
    // two rounds that regressed here both did so at a width the then-current
    // guard had decided could not fail.
    //
    // A seven-figure amount is required — anything below NT$100,000 fits at
    // every width here under every shape tried and could not fail this guard.
    //
    // textScale 1.0 only, and that is a measured limit rather than an omission:
    // at 2.0 the same amount is 325.0dp wide, which exceeds the whole tile title
    // at every width above (236.0–328.0dp), so no arrangement can keep it on one
    // line there and an assertion at 2.0 could only be a false one. What 2.0 is
    // guarded for instead is that the row still *lays out* — the 320/360dp x 2.0
    // sweep above, which is what the amount-in-`ListTile.trailing` shape used to
    // fail with "Trailing widget consumes entire tile width".
    //
    // Asserted on the *signed* amount, which only `_TransactionRow` paints: the
    // totals cards and the category breakdown print the same digits unsigned,
    // so a signed match cannot drift onto some other row and pass there.
    for (final width in [320.0, 360.0, 375.0, 390.0, 412.0]) {
      for (final locale in testSupportedLocales) {
        testWidgets(
          "the overview's recent-transaction amount stays on one line at "
          '${width.toInt()}dp, textScale=1.0, locale=$locale',
          (tester) async {
            useTextScaleFactor(tester, 1.0);
            await tester.binding.setSurfaceSize(Size(width, _phoneHeight));
            addTearDown(() => tester.binding.setSurfaceSize(null));

            final repo = FakeFinanceRepository();
            _seedOverviewLedger(repo);

            await expectNoLayoutErrors(() async {
              await tester.pumpWidget(_financeOverviewScreen(repo, locale: locale));
              await tester.pumpAndSettle();
            });

            for (final amount in ['-1,234,567', '+1,234,567']) {
              final finder = find.text(amount);
              // The recent-transactions card sits below every other card, so a
              // single pump never builds it — drag it into the viewport first
              // (same reason as the repayment-row guard above). Listed in the
              // order the rows are sorted into (date descending), so each drag
              // continues downwards rather than scrolling the previous one back
              // out of the tree.
              await expectNoLayoutErrors(() async {
                await tester.scrollUntilVisible(finder, 200);
              });
              expect(finder, findsOneWidget, reason: '$amount was not painted at all');
              expect(
                paintedTextLineCount(tester, finder),
                1,
                reason: '$amount was broken across lines at ${width.toInt()}dp',
              );
            }
          },
        );
      }
    }

    // Swept over the same width x locale x textScale matrix as the other
    // three settle-up surfaces, and — unlike the version this replaces,
    // which hand-rebuilt an equivalent `AlertDialog` inside the test body —
    // driven through the real `FinanceScaffold._confirmDeleteSettlement`, so
    // a change to the production dialog is something it can actually see.
    for (final width in [320.0, 360.0]) {
      for (final locale in testSupportedLocales) {
        for (final textScale in [1.0, 2.0]) {
          testWidgets(
            'the delete-repayment confirmation keeps Cancel and confirm reachable at '
            '${width.toInt()}dp, textScale=$textScale, locale=$locale',
            (tester) async {
              useTextScaleFactor(tester, textScale);
              await tester.binding.setSurfaceSize(Size(width, _phoneHeight));
              addTearDown(() => tester.binding.setSurfaceSize(null));

              final repo = FakeSplitRepository()
                ..settlementsToReturn = const [
                  Settlement(
                    id: 's1',
                    groupId: null,
                    fromUserId: _self,
                    fromDisplayName: 'Self',
                    toUserId: 'u2',
                    toDisplayName: _longName,
                    amount: _wideAmount,
                    currency: 'TWD',
                    day: '2026-08-02',
                    note: null,
                    createdByUserId: _self,
                  ),
                ];

              await expectNoLayoutErrors(() async {
                await tester.pumpWidget(_financeScaffold(repo, locale: locale));
                await tester.pumpAndSettle();
                await tester.tap(find.byKey(const Key('split-tab')));
                await tester.pumpAndSettle();
                // Below a plain `ListView`'s SliverList cache extent at a
                // large text scale, the row isn't built into the tree yet
                // (mirrors the repayment-row guard above).
                await tester.scrollUntilVisible(
                  find.byKey(const Key('split-settlement-delete-s1')),
                  200,
                );
                // `scrollUntilVisible` stops as soon as the row's Rect
                // intersects the viewport at all, which can leave the icon's
                // own centre (what `tap()` targets) still below the fold.
                await tester.ensureVisible(find.byKey(const Key('split-settlement-delete-s1')));
                await tester.pumpAndSettle();
                await tester.tap(find.byKey(const Key('split-settlement-delete-s1')));
                await tester.pumpAndSettle();
              });

              final cancelRect = tester.getRect(
                find.byKey(const Key('split-delete-settlement-cancel')),
              );
              final confirmRect = tester.getRect(
                find.byKey(const Key('split-delete-settlement-confirm')),
              );
              expect(cancelRect.bottom, lessThanOrEqualTo(_phoneHeight));
              expect(confirmRect.bottom, lessThanOrEqualTo(_phoneHeight));
            },
          );
        }
      }
    }
  });

  // The change log's own rows, which the sweep at the top of this file never
  // reaches: it renders `SplitTab`, and `SplitTab` builds the 變更紀錄
  // section only once its segment is selected — which that sweep never does.
  // It was updated to *compile* against the new constructor argument and
  // stayed green while every change-log row on a 320dp phone was shattered.
  //
  // And `expectNoLayoutErrors` is not what can catch this even with the
  // section on screen: nothing throws. QA measured the painted glyph lines of
  // an amount-change row under the shipped shape at 320dp/2x —
  // `18,` / `000 ` / `→ ` / `12,` / `500`, a figure broken mid-thousands-group
  // and readable as a different number — with a 1288dp row (`SplitExpenseRow`
  // renders the same expense at 128dp) and a headline of one glyph per line
  // over 15 lines. So both assertions here are measurements: where the amount
  // was allowed to break, and how tall the row came out next to the row
  // shape this one is supposed to match.
  group('the change log at a narrow width', () {
    for (final locale in testSupportedLocales) {
      testWidgets(
        'an amount-change row keeps each figure whole and stays the height of an '
        'expense row at 320dp, textScale=2.0, locale=$locale',
        (tester) async {
          useTextScaleFactor(tester, 2.0);
          await tester.binding.setSurfaceSize(const Size(320, _phoneHeight));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final repo = FakeSplitRepository()
            ..activityPagesToReturn = [
              SplitActivityPage(entries: [_amountChangeEntry()], nextCursor: null),
            ];

          await expectNoLayoutErrors(() async {
            await tester.pumpWidget(_changeLogScreen(repo, locale: locale));
            // The first page is fetched post-frame, then resolves over two
            // microtask turns (the reader's id, then the page).
            await tester.pump();
            await tester.pump();
            await tester.pump();
          });

          final loc = lookupAppLocalizations(locale);
          final finder = find.text(loc.splitActivityAmountChange('18,000', '12,500'));
          expect(finder, findsOneWidget, reason: 'the amount change was not painted at all');
          for (final figure in ['18,000', '12,500']) {
            expect(
              paintedLineCountOfPart(tester, finder, figure),
              1,
              reason: '$figure was broken across lines and reads as a different number',
            );
          }

          final activityHeight = tester
              .getSize(find.byKey(const Key('split-activity-row-a1')))
              .height;

          // The same width, the same padding, the same card, the same long
          // description and the same amount — only the row differs.
          await tester.pumpWidget(_expenseRowInSameShell(locale));
          await tester.pumpAndSettle();
          final expenseHeight = tester
              .getSize(find.byKey(const Key('split-expense-row-e1')))
              .height;

          // No taller than the expense row, not merely "within an order of
          // it". A `* 2` allowance was tried and measured first: the shipped
          // shape came back 6088dp against the expense row's 3088dp, i.e. it
          // would have *passed* a doubled bound by 88dp — a guard that cannot
          // fail on the very defect it was written for. The bound that bites
          // is the plain one, and the fix clears it with room to spare (1480dp
          // against 3088dp).
          //
          // (The 3088dp baseline is not a comfortable row either — a 64-char
          // description at 320dp/2x is hard on any layout, and `SplitExpenseRow`
          // is left exactly as it is here. It is the *reference* shape, so it
          // is what "the same order" is measured against, not an ideal.)
          expect(
            activityHeight,
            lessThanOrEqualTo(expenseHeight),
            reason:
                'the change-log row is ${activityHeight}dp against the expense '
                "row's ${expenseHeight}dp for the same content",
          );
        },
      );

      testWidgets(
        'the refresh-failed notice fits beside the retry button at 320dp, '
        'textScale=2.0, locale=$locale',
        (tester) async {
          // The notice is ~250px of copy plus a button in one row. It was
          // added after the row-shattering finding on this very surface, and
          // the guard above never constructs it — a passing suite there says
          // only that the case was not built, not that it was checked.
          useTextScaleFactor(tester, 2.0);
          await tester.binding.setSurfaceSize(const Size(320, _phoneHeight));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final repo = FakeSplitRepository()
            ..activityPagesToReturn = [
              SplitActivityPage(entries: [_amountChangeEntry()], nextCursor: null),
              SplitActivityPage(entries: [_amountChangeEntry()], nextCursor: null),
            ];

          await expectNoLayoutErrors(() async {
            await tester.pumpWidget(_changeLogScreen(repo, locale: locale));
            await tester.pump();
            await tester.pump();
            await tester.pump();

            repo.failNextActivity = const SplitFetchFailure();
            await tester.fling(
              find.byKey(const Key('split-activity-list')),
              const Offset(0, 300),
              1000,
            );
            await tester.pump();
            for (var i = 0; i < 8; i++) {
              await tester.pump(const Duration(milliseconds: 300));
            }
          });

          // Present, and actually reachable — a notice that renders off the
          // right edge raises no `FlutterError` and would pass a bare
          // `findsOneWidget`.
          final notice = find.byKey(const Key('stale-notice-row'));
          expect(notice, findsOneWidget, reason: 'the notice was not rendered at all');
          final rect = tester.getRect(notice);
          expect(
            rect.left >= 0 && rect.right <= 320,
            isTrue,
            reason: 'the notice spans ${rect.left}..${rect.right} on a 320dp screen',
          );

          final loc = lookupAppLocalizations(locale);
          expect(
            find.descendant(of: notice, matching: find.text(loc.retry)).hitTestable(),
            findsOneWidget,
            reason: 'the retry control is present but cannot be tapped',
          );
        },
      );
    }
  });
}
