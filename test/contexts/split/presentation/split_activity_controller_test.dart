import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/split/application/activity_use_cases.dart';
import 'package:life_os/contexts/split/domain/split_activity.dart';
import 'package:life_os/contexts/split/domain/split_exceptions.dart';
import 'package:life_os/contexts/split/presentation/split_activity_controller.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';

import '../support/fake_split_repository.dart';
import '../support/split_presentation_fakes.dart';

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
  description: 'Dinner',
  createdAt: '2026-08-01T10:30:00.000Z',
);

SplitActivityPage _page(List<String> ids, String? cursor) =>
    SplitActivityPage(entries: [for (final id in ids) _entry(id)], nextCursor: cursor);

/// A provider handing out a *different* token each call, so a controller that
/// captured one at construction is distinguishable from one that resolves it
/// per request.
({Future<String> Function() provider, List<String> issued}) _tokens() {
  final issued = <String>[];
  return (
    provider: () async {
      issued.add('tok-${issued.length}');
      return issued.last;
    },
    issued: issued,
  );
}

SplitActivityController _controller(
  FakeSplitRepository repo, {
  Future<String> Function()? idToken,
  GetProfile? getProfile,
}) => SplitActivityController(
  listActivity: ListActivity(repo),
  getProfile:
      getProfile ??
      GetProfile(FakeProfileRepository()..profileToReturn = testProfile(id: 'u-self')),
  idToken: idToken ?? () async => 'tok',
);

void main() {
  group('SplitActivityController — the first page', () {
    test('is not loaded until it is asked for', () async {
      final repo = FakeSplitRepository();
      final controller = _controller(repo);

      expect(controller.status, SplitActivityStatus.initial);
      expect(repo.activityCalls, isEmpty);
    });

    test('requests a bounded page with no cursor', () async {
      final repo = FakeSplitRepository()
        ..activityPagesToReturn = [_page(['a1'], 'c1')];
      final controller = _controller(repo);

      await controller.loadFirstPage();

      expect(repo.activityCalls.single.cursor, isNull);
      expect(repo.activityCalls.single.limit, SplitActivityController.pageSize);
      expect(SplitActivityController.pageSize, lessThanOrEqualTo(100));
      expect(controller.entries.map((e) => e.id), ['a1']);
      expect(controller.status, SplitActivityStatus.loaded);
    });

    test('loads once, however many times it is opened', () async {
      final repo = FakeSplitRepository()
        ..activityPagesToReturn = [_page(['a1'], 'c1')];
      final controller = _controller(repo);

      await controller.loadFirstPage();
      await controller.loadFirstPage();

      expect(repo.activityCalls, hasLength(1));
    });

    test('a failure is retryable and a 401 is a reauth', () async {
      final repo = FakeSplitRepository()
        ..failNextActivity = const SplitFetchFailure()
        ..activityPagesToReturn = [_page(['a1'], null)];
      final controller = _controller(repo);

      await controller.loadFirstPage();
      expect(controller.status, SplitActivityStatus.error);

      await controller.retry();
      expect(controller.status, SplitActivityStatus.loaded);
      expect(controller.entries.map((e) => e.id), ['a1']);

      final reauthRepo = FakeSplitRepository()
        ..failNextActivity = const SplitReauthenticationRequired();
      final reauthController = _controller(reauthRepo);
      await reauthController.loadFirstPage();
      expect(reauthController.status, SplitActivityStatus.needsReauth);
    });

    test('resolves a fresh token per request rather than capturing one', () async {
      final repo = FakeSplitRepository()
        ..activityPagesToReturn = [
          _page(['a1'], 'c1'),
          _page(['a2'], null),
        ];
      final tokens = _tokens();
      final controller = _controller(repo, idToken: tokens.provider);

      await controller.loadFirstPage();
      await controller.loadMore();

      expect(repo.activityCalls.map((c) => c.idToken), ['tok-0', 'tok-1']);
    });
  });

  group('SplitActivityController — refreshing', () {
    test('refresh re-fetches from the top and replaces what was loaded', () async {
      final repo = FakeSplitRepository()
        ..activityPagesToReturn = [
          _page(['a1'], 'c1'),
          _page(['a2', 'a1'], 'c2'),
        ];
      final controller = _controller(repo);
      await controller.loadFirstPage();

      await controller.refresh();

      // From the top — a cursored request would fetch *older* entries, and
      // the newest one is the entry the reader is refreshing to see.
      expect(repo.activityCalls.map((c) => c.cursor), [null, null]);
      expect(controller.entries.map((e) => e.id), ['a2', 'a1']);
    });

    test('refresh keeps the entries on screen while it runs and if it fails', () async {
      final repo = FakeSplitRepository()
        ..activityPagesToReturn = [_page(['a1'], null)];
      final controller = _controller(repo);
      await controller.loadFirstPage();

      repo.failNextActivity = const SplitFetchFailure();
      await controller.refresh();

      // Not an error page: the reader is looking at this list, and a failed
      // background re-fetch is no reason to take it away from them.
      expect(controller.status, SplitActivityStatus.loaded);
      expect(controller.entries.map((e) => e.id), ['a1']);
    });

    test('a split write refreshes the log once opened, and never opens it early', () async {
      // The 記一筆 FAB stays on the change-log section, so a reader can
      // record an expense while looking straight at the log that promises to
      // hold everything that happened. It has to move.
      final repo = FakeSplitRepository()
        ..activityPagesToReturn = [
          _page(['a1'], null),
          _page(['a2', 'a1'], null),
        ];
      final controller = _controller(repo);

      await controller.refreshIfLoaded();
      expect(repo.activityCalls, isEmpty, reason: 'not opened yet — nothing to refresh');

      await controller.loadFirstPage();
      await controller.refreshIfLoaded();

      expect(repo.activityCalls, hasLength(2));
      expect(controller.entries.map((e) => e.id), ['a2', 'a1']);
    });

    test('a 401 on a refresh still routes to reauth', () async {
      final repo = FakeSplitRepository()
        ..activityPagesToReturn = [_page(['a1'], null)];
      final controller = _controller(repo);
      await controller.loadFirstPage();

      repo.failNextActivity = const SplitReauthenticationRequired();
      await controller.refresh();

      expect(controller.status, SplitActivityStatus.needsReauth);
    });
  });

  group('SplitActivityController — paging', () {
    test('the next page is requested with the previous page\'s cursor and appended', () async {
      final repo = FakeSplitRepository()
        ..activityPagesToReturn = [
          _page(['a1'], 'c1'),
          _page(['a2'], 'c2'),
        ];
      final controller = _controller(repo);

      await controller.loadFirstPage();
      await controller.loadMore();

      expect(repo.activityCalls.map((c) => c.cursor), [null, 'c1']);
      expect(controller.entries.map((e) => e.id), ['a1', 'a2']);
    });

    test('each further page advances the cursor', () async {
      // Not advancing it is the other infinite loop: the same page comes
      // back for ever, and with only two requests in a test the second one
      // looks correct because it uses the *first* page's cursor either way.
      final repo = FakeSplitRepository()
        ..activityPagesToReturn = [
          _page(['a1'], 'c1'),
          _page(['a2'], 'c2'),
          _page(['a3'], null),
        ];
      final controller = _controller(repo);

      await controller.loadFirstPage();
      await controller.loadMore();
      await controller.loadMore();

      expect(repo.activityCalls.map((c) => c.cursor), [null, 'c1', 'c2']);
      expect(controller.entries.map((e) => e.id), ['a1', 'a2', 'a3']);
    });

    test('stops requesting once the server reports no further page', () async {
      final repo = FakeSplitRepository()
        ..activityPagesToReturn = [_page(['a1'], null)];
      final controller = _controller(repo);

      await controller.loadFirstPage();
      expect(controller.hasMore, isFalse);

      await controller.loadMore();
      await controller.loadMore();

      expect(repo.activityCalls, hasLength(1));
    });

    test('never sends the same cursor twice, even from overlapping calls', () async {
      final repo = FakeSplitRepository()
        ..activityPagesToReturn = [
          _page(['a1'], 'c1'),
          _page(['a2'], 'c2'),
        ];
      final controller = _controller(repo);
      await controller.loadFirstPage();

      // Two scroll notifications arriving before the first response lands is
      // the ordinary case, and re-sending `c1` is the infinite loop.
      final first = controller.loadMore();
      final second = controller.loadMore();
      await Future.wait([first, second]);

      expect(repo.activityCalls.map((c) => c.cursor), [null, 'c1']);
    });

    test('an empty final page keeps what is loaded and is not an error', () async {
      // `next_cursor` is not a has-more flag: a last page that is exactly
      // `limit` long still carries one, so the terminal state is an empty
      // page, reached by one extra request.
      final repo = FakeSplitRepository()
        ..activityPagesToReturn = [
          _page(['a1'], 'c1'),
          _page([], null),
        ];
      final controller = _controller(repo);

      await controller.loadFirstPage();
      await controller.loadMore();

      expect(controller.entries.map((e) => e.id), ['a1']);
      expect(controller.status, SplitActivityStatus.loaded);
      expect(controller.hasMore, isFalse);
      expect(controller.loadMoreFailed, isFalse);

      await controller.loadMore();
      expect(repo.activityCalls, hasLength(2));
    });

    test('a failed next page keeps the loaded entries and is retryable', () async {
      final repo = FakeSplitRepository()
        ..activityPagesToReturn = [
          _page(['a1'], 'c1'),
          _page(['a2'], null),
        ];
      final controller = _controller(repo);
      await controller.loadFirstPage();

      repo.failNextActivity = const SplitFetchFailure();
      await controller.loadMore();

      expect(controller.status, SplitActivityStatus.loaded);
      expect(controller.entries.map((e) => e.id), ['a1']);
      expect(controller.loadMoreFailed, isTrue);

      await controller.retryLoadMore();
      expect(controller.entries.map((e) => e.id), ['a1', 'a2']);
      expect(controller.loadMoreFailed, isFalse);
      // The retry re-sends the *same* cursor — the failed page was never
      // consumed, so this is not the repeated-cursor loop.
      expect(repo.activityCalls.map((c) => c.cursor), [null, 'c1', 'c1']);
    });

    test('scrolling does not erase a page failure the reader has not acted on', () async {
      // The footer is showing "Couldn't load more entries" and a Retry. A
      // scroll notification arriving underneath it used to swap that message
      // back to a spinner — the reader's failure notice gone, replaced by an
      // indicator for a request they never asked for.
      final repo = FakeSplitRepository()
        ..activityPagesToReturn = [
          _page(['a1'], 'c1'),
          _page(['a2'], null),
        ];
      final controller = _controller(repo);
      await controller.loadFirstPage();

      repo.failNextActivity = const SplitFetchFailure();
      await controller.loadMore();
      expect(controller.loadMoreFailed, isTrue);

      await controller.loadMore();
      await controller.loadMore();

      expect(controller.loadMoreFailed, isTrue);
      expect(controller.loadingMore, isFalse);
      expect(repo.activityCalls, hasLength(2));

      // Only the reader's own tap clears it.
      await controller.retryLoadMore();
      expect(controller.loadMoreFailed, isFalse);
      expect(controller.entries.map((e) => e.id), ['a1', 'a2']);
    });

    test('an empty first page that still carries a cursor is walked past, not settled on', () async {
      // The backend never sends one (a short page ends the cursor), but
      // nothing here enforces that — and the section renders "No changes
      // yet" for an empty list, which no scroll can page out of because
      // there is nothing to scroll.
      final repo = FakeSplitRepository()
        ..activityPagesToReturn = [
          _page([], 'c1'),
          _page(['a1'], null),
        ];
      final controller = _controller(repo);

      await controller.loadFirstPage();

      expect(repo.activityCalls.map((c) => c.cursor), [null, 'c1']);
      expect(controller.entries.map((e) => e.id), ['a1']);
    });

    test('a backend that only ever returns empty cursored pages costs a bounded number of requests', () async {
      final repo = FakeSplitRepository()..activityPagesToReturn = [_page([], 'c1')];
      final controller = _controller(repo);

      await controller.loadFirstPage();

      // The first page plus the five the chase is allowed. Pinned exactly
      // rather than as an upper bound: lowering the ceiling reddens this,
      // whereas `lessThan(n)` would hold for every ceiling below n. (Removing
      // the ceiling altogether hangs this test rather than reddening it —
      // which is the one failure mode this project has learned to read as a
      // failure, not as silence.)
      expect(repo.activityCalls, hasLength(6));
      expect(controller.entries, isEmpty);
    });

    test('a 401 on a further page still routes to reauth', () async {
      final repo = FakeSplitRepository()
        ..activityPagesToReturn = [_page(['a1'], 'c1')];
      final controller = _controller(repo);
      await controller.loadFirstPage();

      repo.failNextActivity = const SplitReauthenticationRequired();
      await controller.loadMore();

      expect(controller.status, SplitActivityStatus.needsReauth);
    });
  });

  group('SplitActivityController — overlapping loads', () {
    test('a refresh landing during a scroll loses no entry and skips no cursor', () async {
      // The ordinary interaction that used to lose an entry for good: scroll
      // to the end (page 2 goes out), then record an expense (the write's
      // refresh goes out). Both paths assign `entries` *and* the cursor.
      final repo = _GatedSplitRepository();
      final controller = _controller(repo);

      unawaited(controller.loadFirstPage());
      await repo.awaitCall(1);
      await repo.release(0, _page(['a1', 'a2', 'a3'], 'c1'));

      unawaited(controller.loadMore());
      await repo.awaitCall(2);
      unawaited(controller.refreshIfLoaded());
      await repo.awaitCall(3);

      // The refresh lands first, then the page-2 response it superseded.
      await repo.release(2, _page(['a0', 'a1', 'a2'], 'c1prime'));
      await repo.release(1, _page(['a4', 'a5', 'a6'], 'c2'));

      expect(controller.entries.map((e) => e.id), ['a0', 'a1', 'a2']);

      // And the cursor the refresh handed back is the one actually spent —
      // spending `c2` here is how a3 became unreachable by any amount of
      // scrolling.
      unawaited(controller.loadMore());
      await repo.awaitCall(4);
      expect(repo.cursors, [null, 'c1', null, 'c1prime']);

      await repo.release(3, _page(['a3'], null));
      expect(controller.entries.map((e) => e.id), ['a0', 'a1', 'a2', 'a3']);
    });

    test('a scroll landing during a refresh loses no entry and skips no cursor', () async {
      // The mirror of the test above, and the order that survived the last
      // fix: the refresh goes out *first* (a write elsewhere in the tab), and
      // the scroll to the end lands while it is still in flight — which it
      // can, because a non-loading refresh deliberately leaves
      // `status == loaded`, `loadingMore == false` and a live cursor so the
      // reader keeps seeing entries.
      //
      // `c1` belongs to the list the refresh is replacing. Spending it and
      // then overwriting the refresh's `c1prime` with its successor is how
      // `a2`/`a3` became unreachable by any amount of scrolling, refreshing
      // or retrying — permanent loss, from recording an expense and then
      // scrolling on.
      final repo = _GatedSplitRepository();
      final controller = _controller(repo);

      unawaited(controller.loadFirstPage());
      await repo.awaitCall(1);
      await repo.release(0, _page(['a1', 'a2', 'a3'], 'c1'));

      unawaited(controller.refreshIfLoaded());
      await repo.awaitCall(2);
      unawaited(controller.loadMore());
      await repo.settle();

      // Refused outright rather than sent and discarded on arrival: a stale
      // cursor spent is a page of the timeline nobody will ask for again.
      expect(
        repo.cursors,
        [null, null],
        reason: 'page 2 was requested with a cursor belonging to the list being replaced',
      );

      await repo.release(1, _page(['a0', 'a00', 'a1'], 'c1prime'));
      expect(controller.entries.map((e) => e.id), ['a0', 'a00', 'a1']);

      // And the next page comes from the *refresh's* cursor, so nothing the
      // old cursor covered is stranded behind it.
      unawaited(controller.loadMore());
      await repo.awaitCall(3);
      expect(repo.cursors, [null, null, 'c1prime']);

      await repo.release(2, _page(['a2', 'a3'], null));
      expect(controller.entries.map((e) => e.id), ['a0', 'a00', 'a1', 'a2', 'a3']);
    });

    test('the same overlap in the other order does not shrink the list', () async {
      // Page 2 lands first and appends; the refresh then assigned
      // `entries = page.entries`, wiping it — the list shrank under a reader
      // mid-scroll.
      final repo = _GatedSplitRepository();
      final controller = _controller(repo);
      final lengths = <int>[];

      unawaited(controller.loadFirstPage());
      await repo.awaitCall(1);
      await repo.release(0, _page(['a1', 'a2', 'a3'], 'c1'));
      controller.addListener(() => lengths.add(controller.entries.length));

      unawaited(controller.loadMore());
      await repo.awaitCall(2);
      unawaited(controller.refreshIfLoaded());
      await repo.awaitCall(3);

      await repo.release(1, _page(['a4', 'a5', 'a6'], 'c2'));
      await repo.release(2, _page(['a0', 'a1', 'a2'], 'c1prime'));

      expect(controller.entries.map((e) => e.id), ['a0', 'a1', 'a2']);
      for (var i = 1; i < lengths.length; i++) {
        expect(
          lengths[i],
          greaterThanOrEqualTo(lengths[i - 1]),
          reason: 'entry count went $lengths — the list shrank while the reader was reading it',
        );
      }
    });

    test('a failed refresh keeps the entries, says so, and keeps a page failure', () async {
      final repo = FakeSplitRepository()
        ..activityPagesToReturn = [_page(['a1'], 'c1')];
      final controller = _controller(repo);
      await controller.loadFirstPage();

      repo.failNextActivity = const SplitFetchFailure();
      await controller.loadMore();
      expect(controller.loadMoreFailed, isTrue);

      repo.failNextActivity = const SplitFetchFailure();
      await controller.refresh();

      expect(controller.entries.map((e) => e.id), ['a1']);
      expect(controller.status, SplitActivityStatus.loaded);
      // Otherwise the refresh failure is completely invisible: the list just
      // does not move, and nothing anywhere says why.
      expect(controller.refreshFailed, isTrue);
      // And the footer's Retry must still be there — the reader has not
      // acted on that failure.
      expect(controller.loadMoreFailed, isTrue);

      // A successful refresh does clear both.
      await controller.refresh();
      expect(controller.refreshFailed, isFalse);
      expect(controller.loadMoreFailed, isFalse);
    });

    test('a write during a refresh is coalesced into a second refresh, not dropped', () async {
      // Two back-to-back writes used to issue exactly one request: the
      // second was dropped by the in-flight guard, so the newer write's row
      // could be missing indefinitely.
      final repo = _GatedSplitRepository();
      final controller = _controller(repo);

      unawaited(controller.loadFirstPage());
      await repo.awaitCall(1);
      await repo.release(0, _page(['a1'], null));

      unawaited(controller.refreshIfLoaded());
      await repo.awaitCall(2);
      unawaited(controller.refreshIfLoaded());
      // Coalesced while the first is out — not a second concurrent request.
      expect(repo.cursors, hasLength(2));

      await repo.release(1, _page(['a2', 'a1'], null));

      await repo.awaitCall(3);
      expect(repo.cursors, [null, null, null]);
      await repo.release(2, _page(['a3', 'a2', 'a1'], null));
      expect(controller.entries.map((e) => e.id), ['a3', 'a2', 'a1']);
    });

    test('a pull-to-refresh landing on a load already in flight is not reported as done', () async {
      // It used to return immediately, having issued nothing and set nothing:
      // the pull's indicator retracted exactly as it does after a successful
      // refresh, telling the reader the list is current when nobody had even
      // asked. It joins the identical request instead.
      final repo = _GatedSplitRepository();
      final controller = _controller(repo);

      unawaited(controller.loadFirstPage());
      await repo.awaitCall(1);
      await repo.release(0, _page(['a1'], null));

      unawaited(controller.refreshIfLoaded());
      await repo.awaitCall(2);

      var pullFinished = false;
      final pull = controller.refresh().then((_) => pullFinished = true);
      await repo.settle();

      expect(pullFinished, isFalse, reason: 'the pull ended before any answer came back');
      // Joined, not duplicated — the same page with no cursor either way.
      expect(repo.cursors, hasLength(2));

      await repo.releaseError(1, const SplitFetchFailure());
      await pull;

      expect(pullFinished, isTrue);
      // And it ends reporting what the load it joined actually did.
      expect(controller.refreshFailed, isTrue);
      expect(controller.entries.map((e) => e.id), ['a1']);
    });

    test('a write-triggered refresh keeps a stale notice the reader has not acted on', () async {
      // `refreshFailed` was cleared at the start of *every* first-page load,
      // so a refresh triggered by a write unmounted the section's
      // `StaleNotice` and remounted it a moment later — and the notice
      // forgets the reader's Retry press when it is unmounted mid-flight.
      final repo = _GatedSplitRepository();
      final controller = _controller(repo);

      unawaited(controller.loadFirstPage());
      await repo.awaitCall(1);
      await repo.release(0, _page(['a1'], null));

      unawaited(controller.refresh());
      await repo.awaitCall(2);
      await repo.releaseError(1, const SplitFetchFailure());
      expect(controller.refreshFailed, isTrue);

      final seen = <bool>[];
      controller.addListener(() => seen.add(controller.refreshFailed));

      unawaited(controller.refreshIfLoaded());
      await repo.awaitCall(3);

      expect(controller.refreshFailed, isTrue);
      expect(
        seen,
        everyElement(isTrue),
        reason: 'the notice blinked off while the write\'s refresh was still in flight',
      );

      // Only actually succeeding clears it.
      await repo.release(2, _page(['a2', 'a1'], null));
      expect(controller.refreshFailed, isFalse);
    });

    test('the empty-page chase cannot be clobbered by a refresh', () async {
      final repo = _GatedSplitRepository();
      final controller = _controller(repo);

      unawaited(controller.loadFirstPage());
      await repo.awaitCall(1);
      // Empty but cursored: the chase walks past it.
      await repo.release(0, _page([], 'c1'));
      await repo.awaitCall(2);

      unawaited(controller.refreshIfLoaded());
      // The chase is still out, so the refresh waits its turn rather than
      // starting underneath it.
      await repo.settle();
      expect(repo.cursors, hasLength(2));

      await repo.release(1, _page(['a1'], null));
      expect(controller.entries.map((e) => e.id), ['a1']);

      await repo.awaitCall(3);
      expect(repo.cursors, [null, 'c1', null]);
    });

    test('a retry pressed during a first-page load is not swallowed', () async {
      // The press cleared `loadMoreFailed` and then `_loadMore` refused at
      // entry (piece 1 of the invariant): the footer's message and its Retry
      // button left the screen and no request went out, so the reader had
      // neither the page they asked for nor a way to ask again.
      final repo = _GatedSplitRepository();
      final controller = _controller(repo);

      unawaited(controller.loadFirstPage());
      await repo.awaitCall(1);
      await repo.release(0, _page(['a1'], 'c1'));

      unawaited(controller.loadMore());
      await repo.awaitCall(2);
      await repo.releaseError(1, const SplitFetchFailure());
      expect(controller.loadMoreFailed, isTrue);

      // A write elsewhere in the split tab refreshes the log, and the reader
      // presses Retry while that refresh is still out.
      unawaited(controller.refreshIfLoaded());
      await repo.awaitCall(3);
      unawaited(controller.retryLoadMore());
      await repo.settle();

      expect(repo.cursors, [null, 'c1', null], reason: 'nothing could be asked for yet');
      expect(
        controller.loadMoreFailed,
        isTrue,
        reason: 'the failure was cleared for a request that was never made',
      );

      // Once the refresh lands, the press it was waiting on issues its page.
      await repo.release(2, _page(['a1'], 'c1'));
      await repo.awaitCall(4);
      expect(repo.cursors, [null, 'c1', null, 'c1']);
      expect(controller.loadMoreFailed, isFalse);
    });

    test('the empty-page chase stops on dispose', () async {
      final repo = _GatedSplitRepository();
      final controller = _controller(repo);

      unawaited(controller.loadFirstPage());
      await repo.awaitCall(1);
      await repo.release(0, _page([], 'c1'));
      await repo.awaitCall(2);

      controller.dispose();
      await repo.release(1, _page([], 'c2'));

      // Without the dispose check the chase keeps walking to its ceiling,
      // requesting pages for a section nobody is looking at any more.
      expect(repo.cursors, [null, 'c1']);
    });
  });
}

/// A [FakeSplitRepository] whose `listActivity` responses are released by
/// hand, so an interleaving is *constructed* rather than hoped for.
class _GatedSplitRepository extends FakeSplitRepository {
  final List<Completer<SplitActivityPage>> _pending = [];

  /// The cursor of every request, in order — including ones still in flight.
  final List<String?> cursors = [];

  @override
  Future<SplitActivityPage> listActivity(
    String idToken, {
    required int limit,
    String? cursor,
  }) {
    cursors.add(cursor);
    final completer = Completer<SplitActivityPage>();
    _pending.add(completer);
    return completer.future;
  }

  /// Lets pending microtasks run so the controller reaches its next await.
  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Waits until [count] requests have been issued (fails rather than hangs).
  Future<void> awaitCall(int count) async {
    for (var i = 0; i < 20 && cursors.length < count; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(cursors, hasLength(count), reason: 'expected $count requests by now');
  }

  Future<void> release(int index, SplitActivityPage page) async {
    _pending[index].complete(page);
    await settle();
  }

  Future<void> releaseError(int index, Object error) async {
    _pending[index].completeError(error);
    await settle();
  }
}
