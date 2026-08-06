import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/async_state_scaffold.dart';
import '../../../shared/widgets/card_error_retry.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/stale_notice.dart';
import 'split_activity_controller.dart';
import 'split_activity_row.dart';

/// The 變更紀錄 (change log) section of the split tab: what has *happened*,
/// including deletions and edits, newest first — as opposed to the tab's
/// 最近活動 list, which shows what currently exists and is left untouched.
///
/// Built only once its section is selected, and loads its first page from
/// `initState`: this timeline grows without bound, so fetching it at app
/// start (or alongside the overview) would be work nobody asked for.
class SplitActivitySection extends StatefulWidget {
  /// Owns the entries **and** the reader's id — see
  /// [SplitActivityController.selfUserId] for why the latter is not passed in
  /// from the overview's controller.
  final SplitActivityController controller;

  final VoidCallback onSignInAgain;

  /// Passed through to each row so a test can pin the zone.
  final DateTime Function(DateTime)? toLocalTime;

  const SplitActivitySection({
    super.key,
    required this.controller,
    required this.onSignInAgain,
    this.toLocalTime,
  });

  @override
  State<SplitActivitySection> createState() => _SplitActivitySectionState();
}

class _SplitActivitySectionState extends State<SplitActivitySection> {
  /// How close to the bottom counts as "the reader reached the end".
  static const _loadMoreThreshold = 200.0;

  final ScrollController _scrollController = ScrollController();

  /// A refresh **this section's own retry button** started is in flight.
  ///
  /// Lives here rather than on the controller: the controller deliberately
  /// keeps a non-loading refresh invisible in [SplitActivityController.status]
  /// (the entries must stay), and this is only ever about what the retry
  /// button under the reader's finger should look like. It is the `loading`
  /// half of [StaleNotice]'s pair — without it the notice's button would go
  /// dead-silent for the whole request, which is the same lie in miniature.
  bool _retryingRefresh = false;

  /// How many end-in-view re-reports to make while the list is not growing.
  ///
  /// The re-report in [_onChanged] is not a reader's gesture, and so nothing
  /// outside this widget stops it: a backend answering every cursor with an
  /// empty-but-cursored page notifies on every response, each notify
  /// re-reports the end, and each re-report asks for another page — the exact
  /// request storm [SplitActivityController]'s own chase bound exists to
  /// prevent, restarted from up here once that bound is spent.
  ///
  /// A budget rather than no re-report at all, because the case it was added
  /// for is real (a `loadMore` refused under a first-page load gets no second
  /// scroll notification). It is refilled by the list actually growing, and by
  /// the reader scrolling again — so only a list that is going nowhere on its
  /// own ever runs out.
  static const _maxReportsWithoutGrowth = 5;

  int _reportsWithoutGrowth = 0;

  /// The entry count at the last budget refill, so growth can be told from a
  /// notify that changed nothing this widget can act on. `-1` because an empty
  /// list is a real count.
  int _lastReportedEntryCount = -1;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _scrollController.addListener(_onScroll);
    // Post-frame rather than straight from `initState`: the controller's
    // first synchronous `notifyListeners` must not land inside this widget's
    // own build.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(widget.controller.loadFirstPage()),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    final entryCount = widget.controller.entries.length;
    if (entryCount != _lastReportedEntryCount) {
      _lastReportedEntryCount = entryCount;
      _reportsWithoutGrowth = 0;
    }
    if (_reportsWithoutGrowth >= _maxReportsWithoutGrowth) return;
    _reportsWithoutGrowth++;
    // The end of the list being in view is *state*, not just an event: a
    // `loadMore` refused because a first-page load was in flight (see the
    // invariant on [SplitActivityController]) gets no second scroll
    // notification, and the reader would sit at the bottom of a list that
    // stopped growing. Re-reported after the frame the controller's change
    // produced, when the list has its new extent — every stop condition is
    // still the controller's.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reportEndInView();
    });
  }

  void _reportEndInView() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      unawaited(widget.controller.loadMore());
    }
  }

  Future<void> _retryRefresh() async {
    setState(() => _retryingRefresh = true);
    try {
      await widget.controller.refresh();
    } finally {
      if (mounted) setState(() => _retryingRefresh = false);
    }
  }

  // Every stop condition lives in the controller — this only reports that the
  // end came into view.
  void _onScroll() {
    // The reader moved: refill the re-report budget above. A gesture is
    // evidence somebody is still reading, which is the thing the budget is
    // rationing requests in the absence of.
    _reportsWithoutGrowth = 0;
    _reportEndInView();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final controller = widget.controller;

    return AsyncStateScaffold(
      isLoading:
          controller.status == SplitActivityStatus.initial ||
          controller.status == SplitActivityStatus.loading,
      isReauth: controller.status == SplitActivityStatus.needsReauth,
      reauthMessage: loc.pleaseSignInAgain,
      onSignInAgain: widget.onSignInAgain,
      builder: (context) {
        if (controller.status == SplitActivityStatus.error) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: CardErrorRetry(
                message: loc.splitActivityLoadFailedMessage,
                messageKey: const Key('split-activity-error'),
                retryKey: const Key('split-activity-retry'),
                onRetry: () => unawaited(controller.retry()),
              ),
            ),
          );
        }

        // The footer is a **load-in-flight or failed-load** indicator, never
        // a "there is more" one: shown on `hasMore` it spun for ever on any
        // list that does not overflow the viewport, because nothing was
        // loading and nothing ever would.
        final showFooter = controller.loadingMore || controller.loadMoreFailed;

        // The empty guide is one more item of the same list, not a branch
        // that replaces it. As a branch it had no [ScrollController] and no
        // pull-to-refresh attached, so "No changes yet" reached with a live
        // cursor (see [SplitActivityController.refresh]) was a dead end the
        // reader could not page or refresh their way out of.
        final showEmptyGuide = controller.entries.isEmpty && !showFooter;

        // A failed *refresh* over kept entries is exactly the case the four
        // overview cards' 沒有更新到 row was designed for, so it is that same
        // [StaleNotice] here rather than a third variant of the idea: the
        // content on screen is still good, it is only older than the reader
        // thinks, and the one thing they can do about it is ask again.
        // [CardErrorRetry] is the other half of that pair and the wrong half —
        // it *replaces* content, which is what the `status == error` branch
        // above already does for a first page that has nothing to fall back
        // on.
        //
        // Pinned above the list, not appended as a list item, because a
        // refresh can be triggered by a write elsewhere in the split tab
        // ([SplitActivityController.refreshIfLoaded]) with the reader
        // scrolled anywhere; as row 0 of a lazily-built list the notice would
        // be off-screen exactly when nobody pulled to refresh and so nobody
        // is looking at the top.
        //
        // It composes with the footer's `loadMoreFailed` retry rather than
        // competing with it: the two failures are about opposite ends of the
        // timeline (the newest page vs. the next older one), each sits at the
        // end it is about, each carries its own copy, and each retry re-issues
        // only its own request. Both at once is a legible pair, not two
        // buttons for one thing.
        final showRefreshFailed = controller.refreshFailed || _retryingRefresh;

        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  // Kept mounted for as long as *either* flag is set — see
                  // [StaleNotice], which throws away the memory of the press
                  // if it is unmounted mid-flight.
                  if (showRefreshFailed)
                    StaleNotice(
                      failed: controller.refreshFailed,
                      loading: _retryingRefresh,
                      subject: loc.splitSectionChangeLog,
                      onRetry: () => unawaited(_retryRefresh()),
                    ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: controller.refresh,
                      child: ListView.builder(
                        key: const Key('split-activity-list'),
                        controller: _scrollController,
                        // So an empty or short change log still accepts the
                        // overscroll pull that triggers the refresh (the shape
                        // `health_scaffold.dart` and `TrackerDayNav.refreshable`
                        // use).
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        itemCount:
                            controller.entries.length + (showFooter || showEmptyGuide ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == controller.entries.length) {
                            return showEmptyGuide
                                ? const _EmptyGuide()
                                : _Footer(
                                    failed: controller.loadMoreFailed,
                                    onRetry: () => unawaited(controller.retryLoadMore()),
                                  );
                          }
                          final entry = controller.entries[index];
                          return LedgeCard(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: SplitActivityRow(
                              entry: entry,
                              selfUserId: controller.selfUserId,
                              toLocalTime: widget.toLocalTime ?? (instant) => instant.toLocal(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The "nothing has happened yet" guide, rendered as the sole item of the
/// list rather than in place of it — so the pull-to-refresh and the scroll
/// listener stay attached (see the `showEmptyGuide` comment at its call site).
class _EmptyGuide extends StatelessWidget {
  const _EmptyGuide();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    // Tier 1: the change log is the whole screen and it has nothing in it.
    // Gains the icon; the heading steps down from `titleLarge` to the
    // standard `titleMedium` and the body picks up the muted colour it
    // lacked. No action — there is nothing to do here but use the app.
    // Rendered as the list's sole item, so no scroll of its own.
    return Padding(
      padding: const EdgeInsets.all(24),
      child: EmptyStateGuide(
        stateKey: const Key('split-activity-empty'),
        icon: Icons.history,
        title: loc.splitActivityEmptyTitle,
        body: loc.splitActivityEmptyBody,
      ),
    );
  }
}

/// The bottom of the list: a small indicator while a further page is on its
/// way, or a retry when one failed. A failed page never replaces the list —
/// the reader keeps what they were already reading.
class _Footer extends StatelessWidget {
  final bool failed;
  final VoidCallback onRetry;

  const _Footer({required this.failed, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: failed
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(loc.splitActivityLoadMoreFailed, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const Key('split-activity-load-more-retry'),
                    onPressed: onRetry,
                    child: Text(loc.retry),
                  ),
                ],
              )
            : const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
      ),
    );
  }
}
