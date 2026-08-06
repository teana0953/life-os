import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/split/application/activity_use_cases.dart';
import 'package:life_os/contexts/split/domain/split_activity.dart';
import 'package:life_os/contexts/split/domain/split_exceptions.dart';
import 'package:life_os/contexts/split/presentation/split_activity_controller.dart';
import 'package:life_os/contexts/split/presentation/split_activity_section.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/widgets/empty_state.dart';

import '../../../support/l10n_test_app.dart';
import '../support/fake_split_repository.dart';
import '../support/split_presentation_fakes.dart';

final _loc = lookupAppLocalizations(const Locale('en'));

SplitActivity _entry(String id) => SplitActivity(
  id: id,
  type: SplitActivityType.expenseCreated,
  actorUserId: 'u-amy',
  actorDisplayName: 'Amy',
  groupId: null,
  groupName: null,
  subjectId: 'e1',
  counterpartUserId: null,
  counterpartDisplayName: null,
  amount: 900,
  previousAmount: null,
  actorIsPayer: null,
  currency: 'TWD',
  description: id,
  createdAt: '2026-08-01T10:30:00.000Z',
);

SplitActivityPage _page(List<String> ids, String? cursor) =>
    SplitActivityPage(entries: [for (final id in ids) _entry(id)], nextCursor: cursor);

/// A page big enough to overflow the test surface — without this the
/// "scrolls to the end" tests never reach the end, and every assertion about
/// what happens there is vacuous.
List<String> _fullPage(String prefix) =>
    [for (var i = 0; i < SplitActivityController.pageSize; i++) '$prefix$i'];

SplitActivityController _controller(FakeSplitRepository repo) => SplitActivityController(
  listActivity: ListActivity(repo),
  // The section resolves the reader itself — see
  // `SplitActivityController.selfUserId`.
  getProfile: GetProfile(FakeProfileRepository()..profileToReturn = testProfile(id: 'u-self')),
  idToken: () async => 'tok',
);

Widget _section(SplitActivityController controller) => l10nTestApp(
  home: Scaffold(
    body: SplitActivitySection(
      controller: controller,
      onSignInAgain: () {},
      toLocalTime: (instant) => instant.toUtc(),
    ),
  ),
);

/// Drags the list to its end. `pumpAndSettle` cannot be used anywhere near
/// this: the bottom load-more spinner never stops animating and settles never
/// arrives.
Future<void> _scrollToEnd(WidgetTester tester) async {
  await tester.drag(find.byKey(const Key('split-activity-list')), const Offset(0, -4000));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Pulls the list down far enough to trigger [RefreshIndicator], and waits
/// out its retraction. The retraction matters: until it finishes the
/// indicator ignores a further drag, so a test that pulls twice on a single
/// `pump(1s)` silently makes only one request.
Future<void> _pullToRefresh(WidgetTester tester) async {
  await tester.fling(find.byKey(const Key('split-activity-list')), const Offset(0, 300), 1000);
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  Future<void> setSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  group('SplitActivitySection — first page', () {
    testWidgets('loads when the section is opened, not before', (tester) async {
      final repo = FakeSplitRepository()..activityPagesToReturn = [_page(['a1'], null)];
      final controller = _controller(repo);

      expect(repo.activityCalls, isEmpty);

      await tester.pumpWidget(_section(controller));
      await tester.pump();

      expect(repo.activityCalls, hasLength(1));
      expect(find.byKey(const Key('split-activity-row-a1')), findsOneWidget);
    });

    testWidgets('shows the entries in the order the server gave them', (tester) async {
      final repo = FakeSplitRepository()
        ..activityPagesToReturn = [_page(['a1', 'a2', 'a3'], null)];
      await tester.pumpWidget(_section(_controller(repo)));
      await tester.pump();

      final positions = ['a1', 'a2', 'a3']
          .map((id) => tester.getTopLeft(find.byKey(Key('split-activity-row-$id'))).dy)
          .toList();
      expect(positions[0], lessThan(positions[1]));
      expect(positions[1], lessThan(positions[2]));
    });

    testWidgets('an empty change log gets a guide, not a blank page', (tester) async {
      final repo = FakeSplitRepository()..activityPagesToReturn = [_page([], null)];
      await tester.pumpWidget(_section(_controller(repo)));
      await tester.pump();

      expect(find.text(_loc.splitActivityEmptyTitle), findsOneWidget);
      expect(find.text(_loc.splitActivityEmptyBody), findsOneWidget);
    });

    testWidgets('a failed first page offers a retry that works', (tester) async {
      final repo = FakeSplitRepository()
        ..failNextActivity = const SplitFetchFailure()
        ..activityPagesToReturn = [_page(['a1'], null)];
      await tester.pumpWidget(_section(_controller(repo)));
      await tester.pump();

      expect(find.byKey(const Key('split-activity-error')), findsOneWidget);

      await tester.tap(find.byKey(const Key('split-activity-retry')));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('split-activity-row-a1')), findsOneWidget);
    });

    testWidgets('a 401 routes to the shared reauth exit', (tester) async {
      final repo = FakeSplitRepository()
        ..failNextActivity = const SplitReauthenticationRequired();
      await tester.pumpWidget(_section(_controller(repo)));
      await tester.pump();

      expect(find.text(_loc.pleaseSignInAgain), findsOneWidget);
    });
  });

  group('SplitActivitySection — refreshing', () {
    testWidgets('pulling down re-fetches from the top', (tester) async {
      await setSurface(tester);
      final repo = FakeSplitRepository()
        ..activityPagesToReturn = [
          _page(['a1'], null),
          _page(['a2', 'a1'], null),
        ];
      await tester.pumpWidget(_section(_controller(repo)));
      await tester.pump();
      expect(find.byKey(const Key('split-activity-row-a2')), findsNothing);

      await tester.fling(find.byKey(const Key('split-activity-list')), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(repo.activityCalls.map((c) => c.cursor), [null, null]);
      expect(find.byKey(const Key('split-activity-row-a2')), findsOneWidget);
    });

    testWidgets('an empty change log can still be pulled to refresh', (tester) async {
      // The guide used to be a branch with no list, no scroll controller and
      // no refresh behind it — the reader's only way back was to leave the
      // whole finance shell and come in again.
      await setSurface(tester);
      final repo = FakeSplitRepository()
        ..activityPagesToReturn = [
          _page([], null),
          _page(['a1'], null),
        ];
      await tester.pumpWidget(_section(_controller(repo)));
      await tester.pump();
      expect(find.byKey(const Key('split-activity-empty')), findsOneWidget);

      // Tier 1 (unify-empty-states): the shared full guide, keyed on its own
      // column, carrying the icon that says *which* kind of empty this is.
      expect(
        find.ancestor(
          of: find.byKey(const Key('split-activity-empty')),
          matching: find.byType(EmptyStateGuide),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(EmptyStateGuide),
          matching: find.byIcon(Icons.history),
        ),
        findsOneWidget,
      );

      await tester.fling(find.byKey(const Key('split-activity-list')), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byKey(const Key('split-activity-row-a1')), findsOneWidget);
      expect(find.byKey(const Key('split-activity-empty')), findsNothing);
    });

    testWidgets('a failed refresh is marked, keeps the entries, and clears on the next success', (
      tester,
    ) async {
      // The whole point: before this, the pull's spinner simply retracted and
      // the list did not move — which reads as "refreshed, nothing new" when
      // in fact nothing was fetched.
      await setSurface(tester);
      final repo = FakeSplitRepository()
        ..activityPagesToReturn = [
          _page(['a1'], null),
          // The failing call still consumes an index in the fake.
          _page(['a1'], null),
          _page(['a2', 'a1'], null),
        ];
      await tester.pumpWidget(_section(_controller(repo)));
      await tester.pump();

      repo.failNextActivity = const SplitFetchFailure();
      await _pullToRefresh(tester);

      expect(find.byKey(const Key('stale-notice-row')), findsOneWidget);
      expect(find.text(_loc.cardRefreshFailed), findsOneWidget);
      // The entries the reader was already reading survive the failure — the
      // section must not fall back to the full-page error state.
      expect(find.byKey(const Key('split-activity-row-a1')), findsOneWidget);
      expect(find.byKey(const Key('split-activity-error')), findsNothing);

      await _pullToRefresh(tester);

      // Three calls: the first page, the refresh that failed, the one that
      // worked. Without this the assertions below would also hold if the
      // second pull had simply never reached the controller.
      expect(repo.activityCalls, hasLength(3));
      expect(find.byKey(const Key('stale-notice-row')), findsNothing);
      expect(find.byKey(const Key('split-activity-row-a2')), findsOneWidget);
    });

    testWidgets('a failed refresh and a failed next page are two separate affordances', (
      tester,
    ) async {
      // Both flags can be set at once (a failed refresh no longer erases the
      // footer's failure). The reader must get one marking per end of the
      // timeline, not two buttons that look like they mean the same thing.
      await setSurface(tester);
      final repo = FakeSplitRepository()
        ..activityPagesToReturn = [
          _page(_fullPage('a'), 'c1'),
          _page(['b0'], null),
        ];
      final controller = _controller(repo);
      await tester.pumpWidget(_section(controller));
      await tester.pump();

      repo.failNextActivity = const SplitFetchFailure();
      await _scrollToEnd(tester);
      expect(find.text(_loc.splitActivityLoadMoreFailed), findsOneWidget);

      // Driven through the controller rather than pulled: the reader is at
      // the *bottom* of the list, which is where a write elsewhere in the tab
      // (`refreshIfLoaded`) reaches them.
      repo.failNextActivity = const SplitFetchFailure();
      await controller.refresh();
      await tester.pump();
      // The notice takes height off the list, so the footer that was at the
      // bottom edge is now below it and no longer built.
      await _scrollToEnd(tester);

      // Two markings, two retries, two keys — the newest-page one above the
      // list, the older-page one at the far end inside it.
      expect(find.text(_loc.cardRefreshFailed), findsOneWidget);
      expect(find.text(_loc.splitActivityLoadMoreFailed), findsOneWidget);
      expect(find.byKey(const Key('stale-notice-retry')), findsOneWidget);
      expect(find.byKey(const Key('split-activity-load-more-retry')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('stale-notice-row'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('split-activity-list'))).dy),
      );
      // Neither failure threw the list away.
      expect(
        find.byKey(Key('split-activity-row-a${SplitActivityController.pageSize - 1}')),
        findsOneWidget,
      );
    });
  });

  group('SplitActivitySection — paging', () {
    testWidgets('the bottom spinner shows only while a page is actually loading', (
      tester,
    ) async {
      // `hasMore` is true here — the server handed back a cursor — but
      // nothing is in flight, and a list that does not overflow never
      // triggers anything. Keyed off `hasMore`, the footer was a spinner
      // that would still be spinning tomorrow.
      final repo = FakeSplitRepository()
        ..activityPagesToReturn = [_page(['a1'], 'c1')];
      await tester.pumpWidget(_section(_controller(repo)));
      await tester.pump();

      expect(find.byKey(const Key('split-activity-row-a1')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a scroll does not swap a failed page back to a spinner', (tester) async {
      await setSurface(tester);
      final repo = FakeSplitRepository()
        ..activityPagesToReturn = [
          _page(_fullPage('a'), 'c1'),
          _page(['b0'], null),
        ];
      await tester.pumpWidget(_section(_controller(repo)));
      await tester.pump();

      repo.failNextActivity = const SplitFetchFailure();
      await _scrollToEnd(tester);
      expect(find.text(_loc.splitActivityLoadMoreFailed), findsOneWidget);

      await _scrollToEnd(tester);

      expect(find.text(_loc.splitActivityLoadMoreFailed), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(repo.activityCalls, hasLength(2));
    });


    // (a) THE POSITIVE CONTROL. Without it the termination test below passes
    // under any implementation at all, including one that never pages: in a
    // test surface the list does not overflow, so "scrolled to the end"
    // never happens and "made no further request" is vacuously true.
    testWidgets('scrolling to the end requests the next page and appends it', (tester) async {
      await setSurface(tester);
      final repo = FakeSplitRepository()
        ..activityPagesToReturn = [
          _page(_fullPage('a'), 'c1'),
          _page(['b0'], null),
        ];
      await tester.pumpWidget(_section(_controller(repo)));
      await tester.pump();
      expect(repo.activityCalls, hasLength(1));

      await _scrollToEnd(tester);

      expect(repo.activityCalls.map((c) => c.cursor), [null, 'c1']);
      await _scrollToEnd(tester);
      expect(find.byKey(const Key('split-activity-row-b0')), findsOneWidget);
    });

    // The controller refuses a further page while a first-page load is in
    // flight (see the invariant on `SplitActivityController`) — and the
    // reader who is already at the end of the list produces no second scroll
    // notification, so without the section re-reporting the end once the
    // controller settles, that page would never be asked for again.
    testWidgets('a scroll refused during a refresh still gets its page afterwards', (
      tester,
    ) async {
      await setSurface(tester);
      final repo = _GatedSplitRepository();
      final controller = _controller(repo);
      await tester.pumpWidget(_section(controller));
      await tester.pump();
      await repo.release(tester, 0, _page(_fullPage('a'), 'c1'));

      // A write elsewhere in the split tab refreshes the log.
      unawaited(controller.refreshIfLoaded());
      await tester.pump();
      expect(repo.cursors, [null, null]);

      await _scrollToEnd(tester);
      expect(
        repo.cursors,
        [null, null],
        reason: 'the cursor of the list being replaced was spent mid-refresh',
      );

      await repo.release(tester, 1, _page(_fullPage('b'), 'c1prime'));

      expect(repo.cursors, [null, null, 'c1prime']);
    });

    // (b) The termination condition, meaningful only because (a) exists.
    testWidgets('scrolling to the end makes no request once there is no further page', (
      tester,
    ) async {
      await setSurface(tester);
      final repo = FakeSplitRepository()
        ..activityPagesToReturn = [_page(_fullPage('a'), null)];
      await tester.pumpWidget(_section(_controller(repo)));
      await tester.pump();

      await _scrollToEnd(tester);
      await _scrollToEnd(tester);

      expect(repo.activityCalls, hasLength(1));
    });

    // The other half of the bound the controller's empty-page chase carries.
    // The chase gives up after five, but every response also notifies, and
    // the section re-reports the end after each notify — so the section kept
    // asking for ever once the chase had stopped, unbounded, without a single
    // gesture from the reader.
    testWidgets('an empty-but-cursored backend costs a bounded number of requests', (
      tester,
    ) async {
      await setSurface(tester);
      final repo = FakeSplitRepository()..activityPagesToReturn = [_page([], 'c1')];
      await tester.pumpWidget(_section(_controller(repo)));

      // Settling at all is half the assertion: unbounded, this times out
      // rather than failing an expectation.
      await tester.pumpAndSettle();

      // Pinned exactly rather than as an upper bound: the first page, the
      // five the controller's chase is allowed, and the one re-report the
      // section's budget still has left by the time the list exists to report
      // on. A `lessThan(n)` would hold for every smaller ceiling too,
      // including ones that no longer re-report at all.
      expect(repo.activityCalls, hasLength(7));
      expect(find.byKey(const Key('split-activity-empty')), findsOneWidget);
    });

    testWidgets('an empty final page leaves the loaded entries on screen', (tester) async {
      await setSurface(tester);
      final repo = FakeSplitRepository()
        ..activityPagesToReturn = [
          _page(_fullPage('a'), 'c1'),
          _page([], null),
        ];
      await tester.pumpWidget(_section(_controller(repo)));
      await tester.pump();

      await _scrollToEnd(tester);
      await _scrollToEnd(tester);

      expect(repo.activityCalls, hasLength(2));
      expect(find.text(_loc.splitActivityEmptyTitle), findsNothing);
      expect(find.byKey(const Key('split-activity-error')), findsNothing);
      // The last row of the page just loaded — `a0` is scrolled out of a
      // lazily-built list by now, so its absence would prove nothing.
      expect(find.byKey(Key('split-activity-row-a${SplitActivityController.pageSize - 1}')), findsOneWidget);
    });

    testWidgets('a failed next page keeps the list and offers a retry at the bottom', (
      tester,
    ) async {
      await setSurface(tester);
      final repo = FakeSplitRepository()
        ..activityPagesToReturn = [
          _page(_fullPage('a'), 'c1'),
          _page(['b0'], null),
        ];
      await tester.pumpWidget(_section(_controller(repo)));
      await tester.pump();

      repo.failNextActivity = const SplitFetchFailure();
      await _scrollToEnd(tester);

      expect(find.byKey(const Key('split-activity-error')), findsNothing);
      expect(find.text(_loc.splitActivityLoadMoreFailed), findsOneWidget);
      expect(find.byKey(Key('split-activity-row-a${SplitActivityController.pageSize - 1}')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('split-activity-load-more-retry')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('split-activity-load-more-retry')));
      await tester.pump();
      await tester.pump();

      expect(find.text(_loc.splitActivityLoadMoreFailed), findsNothing);
      expect(repo.activityCalls.map((c) => c.cursor), [null, 'c1', 'c1']);
    });
  });
}

/// A [FakeSplitRepository] whose responses are released by hand, so an
/// interleaving is *constructed* rather than hoped for from timing.
class _GatedSplitRepository extends FakeSplitRepository {
  final List<Completer<SplitActivityPage>> _pending = [];

  /// The cursor of every request, in order — including ones still in flight.
  final List<String?> cursors = [];

  @override
  Future<SplitActivityPage> listActivity(String idToken, {required int limit, String? cursor}) {
    cursors.add(cursor);
    final completer = Completer<SplitActivityPage>();
    _pending.add(completer);
    return completer.future;
  }

  Future<void> release(WidgetTester tester, int index, SplitActivityPage page) async {
    _pending[index].complete(page);
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
  }
}
