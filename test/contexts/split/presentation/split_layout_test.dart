import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/finance/presentation/finance_scaffold.dart';
import 'package:life_os/contexts/social/application/friend_use_cases.dart';
import 'package:life_os/contexts/social/domain/friend.dart';
import 'package:life_os/contexts/split/application/balance_use_cases.dart';
import 'package:life_os/contexts/split/application/expense_use_cases.dart';
import 'package:life_os/contexts/split/application/group_use_cases.dart';
import 'package:life_os/contexts/split/domain/balance.dart';
import 'package:life_os/contexts/split/domain/group_member.dart';
import 'package:life_os/contexts/split/domain/split_expense.dart';
import 'package:life_os/contexts/split/domain/split_group.dart';
import 'package:life_os/contexts/split/domain/split_share.dart';
import 'package:life_os/contexts/split/presentation/group_detail_screen.dart';
import 'package:life_os/contexts/split/presentation/split_controller.dart';
import 'package:life_os/contexts/split/presentation/split_expense_sheet.dart';
import 'package:life_os/contexts/split/presentation/split_tab.dart';
import 'package:life_os/contexts/split/presentation/split_tab_dependencies.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/date/day_format.dart';

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
    )
    ..status = SplitStatus.loaded
    ..selfUserId = _self
    ..balances = balances
    ..groups = groups
    ..expenses = expenses;
}

Widget _splitTabScreen({required SplitController controller}) => Scaffold(
  body: SplitTab(
    onAddFriend: () {},
    controller: controller,
    onRetry: () {},
    onRecordExpense: () {},
    onOpenGroup: (_) {},
    onCreateGroup: () {},
    onEditExpense: (_) {},
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
      ),
      idToken: 'tok',
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
        onOpenGroup: (_, __) async {},
      ),
      clock: () => DateTime(2026, 8, 2),
    ),
  );
}

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
}
