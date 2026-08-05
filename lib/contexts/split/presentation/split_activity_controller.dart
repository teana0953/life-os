import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../shared/auth/id_token_provider.dart';
import '../../user/application/get_profile.dart';
import '../application/activity_use_cases.dart';
import '../domain/split_activity.dart';
import '../domain/split_exceptions.dart';

enum SplitActivityStatus {
  /// Nothing asked for yet — the change log is only fetched once its section
  /// is opened, never at app start: this timeline only grows.
  initial,
  loading,
  loaded,
  error,
  needsReauth,
}

/// Drives the split change log: one page at a time, newest first.
///
/// Holds an [IdTokenProvider] rather than a token string (PR #126): it issues
/// requests of its own accord as the reader scrolls, potentially long after
/// the section was built, and a captured token would be an hour stale by
/// then.
class SplitActivityController extends ChangeNotifier {
  /// Deliberately small. The backend defaults to 50 and clamps at 100, but
  /// this timeline grows without bound and the reader is looking for the
  /// most recent change, not all of them.
  static const pageSize = 20;

  final ListActivity _listActivity;
  final GetProfile _getProfile;
  final IdTokenProvider _idToken;

  SplitActivityController({
    required ListActivity listActivity,
    required GetProfile getProfile,
    required IdTokenProvider idToken,
  }) : _listActivity = listActivity,
       _getProfile = getProfile,
       _idToken = idToken;

  SplitActivityStatus status = SplitActivityStatus.initial;
  List<SplitActivity> entries = [];

  /// The reader, for "you" and for a repayment's direction.
  ///
  /// Resolved **here**, from this section's own `/api/me` request, and not
  /// borrowed from `SplitController`: the change log and the overview are two
  /// independent sets of data (design D1 — which is why the section switch
  /// sits above the overview's loading/error branches), and a borrowed id
  /// couples them again where it is least visible. While the overview was
  /// still loading, or after its `SplitError.profileFailed`, a repayment made
  /// *to* the reader rendered as "Amy paid Me" — their own display name, in
  /// the third person. The direction was right; the person was not.
  ///
  /// A failure resolving it leaves this `null`, which every consumer already
  /// treats as "nobody" (never as the actor) — it does not fail the section,
  /// because the entries are what the section exists to show.
  String? selfUserId;

  /// The cursor to send next, or `null` for the first page.
  String? _cursor;

  /// Whether a further request is worth making.
  ///
  /// Derived from the cursor rather than tracked alongside it: the two can
  /// only ever disagree by mistake, and a duplicated terminal condition is
  /// one that no test can hold to account (removing either copy leaves the
  /// other one still stopping the loop).
  ///
  /// It is false once a response comes back with `next_cursor == null` —
  /// which, on the backend, only happens on a **short** page. A last page
  /// that is exactly [pageSize] long carries a cursor, so the ordinary
  /// terminal state costs one extra request that returns nothing. That empty
  /// page is not an error and not an empty change log.
  bool get hasMore => _cursor != null;

  bool loadingMore = false;

  /// A further page failed. Kept apart from [status] on purpose: turning the
  /// whole section into an error state would throw away entries the reader
  /// is already looking at.
  bool loadMoreFailed = false;

  /// The last re-fetch of the newest page failed while entries were on
  /// screen. Kept apart from [status] for the same reason as
  /// [loadMoreFailed] — the entries stay — but it must exist: without it a
  /// failed [refresh]/[refreshIfLoaded] left no trace anywhere, so the list
  /// simply did not move and nothing said why.
  ///
  /// Cleared by a first page that *replaces* the list (a loading one), and on
  /// success — but **not** at the start of a non-loading refresh. It used to
  /// be cleared by every first-page load, so a write-triggered refresh
  /// unmounted and remounted the section's `StaleNotice` (which forgets the
  /// reader's Retry press when it is unmounted mid-flight): a failure the
  /// reader has not acted on flickering off and back on again.
  bool refreshFailed = false;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  /// THE INVARIANT, and the only thing keeping this class's two writers off
  /// each other:
  ///
  /// > A further-page load never runs while a first-page load is in flight,
  /// > and a first-page load invalidates every further-page load already out.
  ///
  /// Both [_loadFirstPage] and [_loadMore] assign [entries] **and** [_cursor],
  /// and a non-loading refresh deliberately leaves `status == loaded`,
  /// `loadingMore == false` and a live cursor so the reader keeps seeing the
  /// list — which means [loadMore] is reachable for a refresh's whole
  /// duration, by design. Two attempts at this hazard each fixed the ordering
  /// in front of them and left its mirror losing entries for good:
  ///
  ///  - page 2 out, *then* a refresh → the refresh replaced [entries] and the
  ///    stale page 2 appended to them and overwrote the fresh cursor;
  ///  - a refresh out, *then* page 2 → page 2 recorded the already-bumped
  ///    generation, passed its own check, and overwrote the refresh's cursor
  ///    with the pre-refresh page's. The entries only the discarded cursor
  ///    covered were then unreachable by any amount of scrolling, refreshing
  ///    or retrying.
  ///
  /// So the two are kept from interleaving at all rather than by enumerating
  /// orders. Three pieces, each carrying one direction (see
  /// [_loadGeneration]):
  ///
  ///  1. [_loadMore] refuses at entry while this flag is set — no
  ///     further-page load can *start* under a first-page load;
  ///  2. a first-page load bumps [_loadGeneration] before its first await —
  ///     invalidating every further-page load already out;
  ///  3. [_loadMore] re-checks its ticket on resume, and touches nothing if
  ///     it has moved.
  ///
  /// One per direction, plus the check that makes 2 mean anything. Each of
  /// the three reddens a test on its own when removed; the two directions
  /// have a test each, both constructed with a hand-released fake rather than
  /// hoped for by timing.
  ///
  /// This flag also coalesces the three first-page entry points into one
  /// request: a write-triggered [refreshIfLoaded] landing on top of a
  /// pull-to-refresh would otherwise issue a second identical request.
  bool _loadingFirstPage = false;

  /// Monotonic ticket, bumped by every first-page load before its first
  /// await. A [_loadMore] records it at entry and refuses to touch [entries]
  /// or [_cursor] on resume if it has moved since — one condition covering
  /// every further-page load in flight, rather than one per pair of paths.
  ///
  /// Not sufficient on its own, which is what the second attempt at this
  /// hazard got wrong: a ticket only invalidates loads that were **already
  /// out** when the first page started. A [_loadMore] that starts *after* the
  /// bump records the new value, passes its own check, and wins — with the
  /// pre-refresh cursor. Hence piece 1 of the invariant above.
  int _loadGeneration = 0;

  /// Completes when the first-page load currently in flight has finished, so
  /// [refresh] can join it instead of vanishing. Replaced by each load.
  Completer<void>? _firstPageDone;

  /// A write arrived while a first-page load was already in flight. The
  /// newer write's row is not in the response now being awaited, so the
  /// refresh is re-armed to run once more afterwards — coalescing two writes
  /// into one *later* request, rather than dropping the second and leaving
  /// its row missing until something else happens to refresh.
  bool _pendingWriteRefresh = false;

  /// Loads the first page the first time the section is opened. A no-op
  /// afterwards, so re-selecting the section does not refetch — [refresh]
  /// and [refreshIfLoaded] are how fresh entries are asked for.
  Future<void> loadFirstPage() async {
    if (status != SplitActivityStatus.initial) return;
    await _loadFirstPage(showLoading: true);
  }

  /// Retries after a failed first page.
  Future<void> retry() => _loadFirstPage(showLoading: true);

  /// Re-fetches the newest page at the reader's request (pull-to-refresh).
  ///
  /// Keeps the entries on screen while the request is out, and keeps them if
  /// it fails: this is a list the reader is currently reading, and swapping
  /// it for a spinner (or an error page) because a re-fetch is in progress
  /// loses more than it tells. The pull's own indicator is the feedback.
  ///
  /// Landing on a first-page load already in flight, it **joins** that load
  /// rather than returning: a pull that completes immediately retracts its
  /// indicator as though it had refreshed, having issued no request and set
  /// no [refreshFailed] — the reader is told the list is current when nothing
  /// was even asked. Joining coalesces the identical request (same page, no
  /// cursor) and still reports whatever that load ends in.
  Future<void> refresh() async {
    if (_loadingFirstPage) {
      await _firstPageDone?.future;
      return;
    }
    await _loadFirstPage(showLoading: false);
  }

  /// Re-fetches because something *else* in the split tab wrote.
  ///
  /// The change log's whole promise is that everything that happened is in
  /// it, and the 記一筆 FAB is deliberately kept on this section — so a
  /// reader who records an expense while standing here must not watch the
  /// list not move. A no-op before the first open: the section fetches on
  /// its own when it is opened, and pre-loading it there is exactly the work
  /// [loadFirstPage]'s laziness exists to avoid.
  Future<void> refreshIfLoaded() async {
    if (status == SplitActivityStatus.initial) return;
    if (_loadingFirstPage) {
      // Coalesced, not dropped — see [_pendingWriteRefresh].
      _pendingWriteRefresh = true;
      return;
    }
    await _loadFirstPage(showLoading: false);
  }

  Future<void> _loadFirstPage({required bool showLoading}) async {
    if (_loadingFirstPage) return;
    final done = Completer<void>();
    _firstPageDone = done;
    // Piece 1 of the invariant: for as long as this is set, no [_loadMore]
    // starts. Set before the first await, cleared only in the `finally`.
    _loadingFirstPage = true;
    // Piece 2: bumping invalidates every further-page load already out.
    //
    // Nothing re-checks this value on the way back down, and nothing can:
    // [_loadingFirstPage] is set across every await below, so the only bump
    // that could happen underneath this one comes from [_chaseEmptyFirstPage]
    // — which runs *after* the assignments. A ticket check here would be a
    // condition no test can falsify, and this class already carries one such
    // note (see [_chaseEmptyFirstPage]) rather than a check.
    ++_loadGeneration;
    if (showLoading) status = SplitActivityStatus.loading;
    // A first page that is *replacing* the list makes a stale page failure
    // meaningless. A refresh only clears these once it has actually succeeded
    // (below): a failed refresh must not erase a footer failure the reader
    // has not acted on, taking their Retry with it, and a *succeeding* one
    // must not blink the stale notice off and on again on its way there.
    if (showLoading) {
      loadMoreFailed = false;
      refreshFailed = false;
    }
    _notify();
    try {
      final token = await _idToken();
      // Before the page, and never repeated once it is known: the rows that
      // say "you" are rendered from it, so resolving it after the entries
      // land would paint them in the third person first.
      selfUserId ??= await _resolveSelfUserId(token);
      final page = await _listActivity(token, limit: pageSize);
      // Assigned unconditionally, and deliberately so — see the note on
      // [generation] above: nothing can have moved [_loadGeneration] while
      // this load was out, and a first page that *did* stand aside for
      // someone else would be a refresh that changed nothing and reported no
      // failure, which is the other half of what this round fixed.
      entries = page.entries;
      _cursor = page.nextCursor;
      loadMoreFailed = false;
      refreshFailed = false;
      status = SplitActivityStatus.loaded;
      _notify();
      // Inside the guarded region on purpose: run after the `finally` below
      // it would chase with [_loadingFirstPage] already down, so a refresh
      // could start underneath it and clobber the page it just walked to.
      await _chaseEmptyFirstPage();
    } on SplitReauthenticationRequired {
      status = SplitActivityStatus.needsReauth;
    } catch (_) {
      if (showLoading) {
        status = SplitActivityStatus.error;
      } else {
        // The entries stay on screen; this is the only thing that says the
        // list did not move because the re-fetch failed.
        refreshFailed = true;
      }
    } finally {
      _loadingFirstPage = false;
    }
    _notify();
    if (_pendingWriteRefresh && !_disposed) {
      _pendingWriteRefresh = false;
      await _loadFirstPage(showLoading: false);
    }
    // Last, so a [refresh] that joined this load is released only once
    // everything this load leads to has settled.
    if (!done.isCompleted) done.complete();
  }

  /// How many empty-but-cursored pages to walk past before giving up.
  static const _maxEmptyPageChase = 5;

  /// Walks past a first page that came back **empty while still carrying a
  /// cursor**.
  ///
  /// The backend does not send one (its cursor is null on any short page),
  /// but nothing in this app enforces that contract, and without this the
  /// section would settle on "No changes yet" with entries sitting behind a
  /// cursor nothing would ever spend — an empty screen that no retry, scroll
  /// or refresh can get past. Bounded, so a backend that did it forever
  /// costs a handful of requests rather than a request storm.
  /// Stops as soon as the controller is disposed — otherwise a section the
  /// reader has navigated away from keeps issuing requests until the ceiling
  /// is reached.
  ///
  /// Takes no generation ticket of its own: it is called from inside
  /// [_loadFirstPage]'s guarded region, so no other first-page load can start
  /// underneath it, and each [_loadMore] it makes carries its own ticket. A
  /// generation check here could not be false, and a condition no test can
  /// falsify is worse than no condition at all.
  Future<void> _chaseEmptyFirstPage() async {
    var chased = 0;
    while (!_disposed &&
        entries.isEmpty &&
        hasMore &&
        status == SplitActivityStatus.loaded &&
        !loadMoreFailed &&
        chased < _maxEmptyPageChase) {
      chased++;
      // The one exemption from piece 1 of the invariant, and it does not open
      // a hole: this runs *inside* [_loadFirstPage]'s guarded region, so the
      // first-page load it overlaps is the one that called it and has already
      // finished assigning. Every other first-page load is still refused.
      await _loadMore(fromFirstPageLoad: true);
    }
  }

  /// The reader's own user id, or `null` if it could not be resolved.
  ///
  /// Swallows the failure on purpose: a change log the reader can read in the
  /// third person is better than no change log, and a dead token surfaces
  /// through the page request that follows anyway.
  Future<String?> _resolveSelfUserId(String idToken) async {
    try {
      return (await _getProfile(idToken)).id;
    } catch (_) {
      return null;
    }
  }

  /// Appends the next page, as the reader reaches the end of the list.
  ///
  /// Refuses while [loadMoreFailed] is set: the footer is showing a failure
  /// the reader has not acted on, and a scroll must not silently swap their
  /// retry message back to a spinner. [retryLoadMore] is the one path that
  /// clears it, and it only runs when they ask.
  ///
  /// Also refuses while a first-page load is in flight — see the invariant on
  /// [_loadingFirstPage]. The scroll that was refused is re-reported by the
  /// section once the controller settles, so the page is delayed, not lost.
  Future<void> loadMore() async {
    if (loadMoreFailed) return;
    await _loadMore();
  }

  /// The footer's retry: the same request, after clearing the failure.
  ///
  /// Landing on a first-page load already in flight, it **waits** for it
  /// rather than clearing and returning — the same reason [refresh] joins one.
  /// Clearing first meant [_loadMore] then refused at entry (piece 1 of the
  /// invariant), so the press took the failure message and its own Retry
  /// button off screen and issued nothing: the reader left with neither the
  /// request they asked for nor the affordance to ask again.
  Future<void> retryLoadMore() async {
    if (_loadingFirstPage) {
      await _firstPageDone?.future;
      if (_disposed) return;
    }
    loadMoreFailed = false;
    await _loadMore();
  }

  /// Does nothing when there is no further page, or while one is already in
  /// flight — the two ways this becomes an infinite request loop.
  ///
  /// [fromFirstPageLoad] is [_chaseEmptyFirstPage]'s exemption from the entry
  /// refusal; nothing else may pass it.
  Future<void> _loadMore({bool fromFirstPageLoad = false}) async {
    final cursor = _cursor;
    if (cursor == null || loadingMore) return;
    if (status != SplitActivityStatus.loaded) return;
    // Piece 1 of the invariant: this cursor belongs to a list a first-page
    // load is in the middle of replacing, so spending it appends the old
    // timeline onto the new one and throws the new cursor away.
    if (_loadingFirstPage && !fromFirstPageLoad) return;

    // This load's ticket. Recorded, not bumped: the only thing a bump here
    // could invalidate is a first-page load in flight, and piece 1 above
    // means there is never one to invalidate.
    final generation = _loadGeneration;

    loadingMore = true;
    _notify();
    try {
      final page = await _listActivity(await _idToken(), limit: pageSize, cursor: cursor);
      // Piece 3: a first-page load that started while this was out has
      // already replaced [entries] and [_cursor], and appending to them (or
      // overwriting that cursor) is what loses entries for good.
      if (generation == _loadGeneration) {
        // An empty page keeps everything already loaded — it is the end of
        // the timeline, not an emptied one.
        entries = [...entries, ...page.entries];
        _cursor = page.nextCursor;
      }
    } on SplitReauthenticationRequired {
      if (generation == _loadGeneration) status = SplitActivityStatus.needsReauth;
    } catch (_) {
      // The cursor is left untouched, so the retry asks for the same page
      // that failed rather than skipping it.
      if (generation == _loadGeneration) loadMoreFailed = true;
    }
    loadingMore = false;
    _notify();
  }
}
