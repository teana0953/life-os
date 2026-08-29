import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/build_info.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/privacy/privacy_mask_controller.dart';
import '../../../shared/routing/finance_tab.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/cycle_badge.dart';
import '../../../shared/widgets/last_loaded_label.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../../shared/widgets/stale_notice.dart';
import '../../finance/domain/finance_money.dart';
import '../../health/domain/daily_target.dart';
import '../../health/domain/portions.dart';
import '../../menstrual/domain/next_period_status.dart';
import '../../menstrual/presentation/cycle_badge_style.dart';
import '../../split/domain/balance.dart';
import 'home_controller.dart';
import 'home_dashboard_controller.dart';

const _contentMaxWidth = 960.0;

/// The `_DashboardSection` `LayoutBuilder`'s **inner** width (screen width
/// minus 20+20 page padding, 2+2 `LedgeCard` border, 14+14 `LedgeCard`
/// padding = 72) below which a section's tiles stack into a single column
/// instead of two. **Both** sections use it.
///
/// Measured (not guessed): at inner 258, the zh-Hant tile labels (e.g.
/// 最新體重, 生理週期預測 — CJK glyphs beside the 44pt privacy eye) still fit on
/// one line and the value on at most two, with zero layout errors. At
/// inner 256 the labels break to two lines; at inner 254 the value also
/// breaks to three. So 258 is the measured legibility floor — the tile
/// itself cannot overflow until inner ≈150, far narrower, so this is a
/// readability threshold, not an overflow threshold. +2px margin for
/// font-metric drift across Flutter/Noto Sans versions.
///
/// **Why finance no longer has its own, higher threshold.** It used to be
/// 330, on the reasoning that a narrow finance tile doesn't just cramp, it
/// corrupts: a `Text` too narrow for a thousands-grouped amount hard-wraps
/// it mid-digit (`456,70` / `0` on its own line), which reads as a
/// *different* number (issue #189). Keeping the section single-column was
/// only ever a way to avoid ever producing such a tile — and it did not
/// hold: from screen 402dp up (inner ≥ 330) the section went two columns
/// anyway, with tiles (160–171px) below the 171.5px a 7-digit amount needs,
/// so `9,999,999` split again on iPhone 16 Pro and Pixel 8/9 widths (issue
/// #190). The gap could only be closed by pushing the threshold to 356 and
/// giving up two-column finance on ordinary phones.
///
/// `_SnapshotTile._tileValue` removes the failure at its source instead:
/// the figure is one line that shrinks to fit, at any tile width. With no
/// wrap left to avoid, finance has no reason to hold a different breakpoint
/// from health, so both now use this one legibility floor.
///
/// Measured shrink (painted scale of the value `Text`, zh-Hant) at the
/// tightest layout this produces — screen 332dp, inner 260, tileWidth 125,
/// the narrowest two-column tile that exists:
///
/// - `剩餘 456,700` 0.613×, `9,999,999` 0.681×, `-9,999,999` 0.613×
/// - the deliberately over-long `剩餘 9,999,999` 0.511× — the worst case
///   among these fixture amounts, not a claim about every string the app can
///   print (a longer real balance shrinks further still)
/// - the health prose value `再記錄一次即可預測` 0.681×
///
/// At the widths the two issues actually named it is far milder for these
/// same fixture amounts: the worst of them is 0.700× at 360dp, 0.830× at
/// 402dp, 0.916× at 430dp.
const _sectionTwoColumnMinWidth = 260.0;

enum GreetingPeriod { morning, afternoon, evening }

GreetingPeriod greetingPeriodFor(DateTime time) {
  if (time.hour < 12) return GreetingPeriod.morning;
  if (time.hour < 18) return GreetingPeriod.afternoon;
  return GreetingPeriod.evening;
}

class HomeScreen extends StatefulWidget {
  final HomeController controller;
  final HomeDashboardController? dashboardController;

  /// Which snapshot figures the signed-in user chose to hide.
  ///
  /// Required, not nullable: a nullable one turns a forgotten wire-up in
  /// `app.dart` into "the eyes just aren't there", which every widget test
  /// here would still pass. There are three construction sites.
  final PrivacyMaskController privacyMaskController;
  final DateTime Function() clock;
  final Future<String> Function()? idToken;

  const HomeScreen({
    super.key,
    required this.controller,
    required this.privacyMaskController,
    this.dashboardController,
    this.clock = DateTime.now,
    this.idToken,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    widget.dashboardController?.addListener(_onControllerChanged);
    widget.privacyMaskController.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    if (oldWidget.dashboardController != widget.dashboardController) {
      oldWidget.dashboardController?.removeListener(_onControllerChanged);
      widget.dashboardController?.addListener(_onControllerChanged);
    }
    if (oldWidget.privacyMaskController != widget.privacyMaskController) {
      oldWidget.privacyMaskController.removeListener(_onControllerChanged);
      widget.privacyMaskController.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.dashboardController?.removeListener(_onControllerChanged);
    widget.privacyMaskController.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  /// Whether a reload can actually run — the same pair `_refreshDashboard`
  /// checks before doing anything, so no control is offered that it would
  /// silently drop.
  bool get _canRefresh =>
      widget.dashboardController != null && widget.idToken != null;

  void _openSettings() => context.push('/settings');
  void _openHealth() => context.push('/health');
  void _openFinance() => context.push(FinanceTab.financeLocation);
  void _openAssistant() => context.push('/assistant');
  void _openVitals() => context.push('/health/vitals');
  void _openMenstrual() => context.push('/health/menstrual');
  void _openFoodDictionary() => context.push('/health/diet/dictionary');

  /// Opens the finance shell on a specific destination. A snapshot tile has to
  /// land on the tab that shows the number it just displayed — 總資產/總負債 on
  /// 淨值, 分帳總覽 on 分帳. The destination rides on the location rather than on
  /// `extra` so that the same string also works as a deep link, a PWA shortcut
  /// or a pasted URL. (In-app this is a `push`, which — like every other
  /// pushed screen in this app — does not put its location in the address bar;
  /// see `FinanceScaffold._selectTab`.) 預算 keeps plain [_openFinance]: its
  /// number lives on 總覽, which is the shell's default.
  void _openFinanceTab(FinanceTab tab) => context.push(tab.location.toString());

  void _showComingSoon() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.spaceComingSoon)),
      );
  }

  /// Reloads the **whole** dashboard — the pull-to-refresh handler, the app
  /// bar's refresh button, the page-level `StaleNotice` and the
  /// whole-dashboard error card, which are all the same seven-arm round. Only
  /// the dashboard: the profile is a name and an admin flag, and reloading it
  /// would add another request and another failure mode to the gesture.
  ///
  /// Not this path: a single tile's retry marker, which refetches one arm via
  /// [_retryArm] and deliberately leaves the page-level state (spinner,
  /// "updated HH:mm", stale notice) alone.
  ///
  /// A fresh token per reload (issue #106): home stays mounted for the whole
  /// session, so a token captured at mount goes stale under it.
  Future<void> _refreshDashboard() async {
    final dashboard = widget.dashboardController;
    final token = widget.idToken;
    if (dashboard == null || token == null) return;
    final loc = AppLocalizations.of(context)!;
    final direction = Directionality.of(context);
    var failed = false;
    try {
      await dashboard.load(await token(), widget.clock());
    } catch (_) {
      // `load` swallows its own errors, so this only catches a token renewal
      // that throws — and it must not escape: the future this returns is what
      // RefreshIndicator awaits, and an error there leaves the pull spinner
      // turning with nothing left to finish it. It is still a failed refresh,
      // though: without this flag the announcement below would read the
      // untouched `lastLoadedAt` and report the OLD time as fresh news.
      failed = true;
    }
    if (!mounted) return;
    // The whole outcome of the gesture is otherwise conveyed by two silent
    // repaints — a timestamp that moved and a row that appeared. A screen
    // reader user pulls, hears nothing, and cannot tell a slow refresh from a
    // finished one.
    final lastLoadedAt = dashboard.lastLoadedAt;
    if (failed ||
        dashboard.status == HomeDashboardStatus.error ||
        lastLoadedAt == null) {
      SemanticsService.announce(loc.cardRefreshFailed, direction);
    } else if (dashboard.data?.hasAnyFailure ?? false) {
      // A round that lands six figures and loses one is neither outcome the
      // page had words for. "Couldn't refresh" is the same lie in the audio
      // channel that a failed tile painting 無資料 was in the visual one —
      // the timestamp moved and six numbers changed while it was spoken.
      SemanticsService.announce(loc.homeRefreshPartial, direction);
    } else {
      // Same 24-hour rendering as the `LastLoadedLabel` this repeats aloud.
      SemanticsService.announce(
        loc.lastUpdatedAt(DateFormat('HH:mm').format(lastLoadedAt)),
        direction,
      );
    }
  }

  /// Retries the profile load — the error state's primary action. A profile
  /// fetch failure is often a transient timeout (backend merely slow, not
  /// down), not proof the account/token is broken, so sign-out must not be
  /// the only exit offered.
  Future<void> _retryProfile() async {
    final token = widget.idToken;
    if (token == null) return;
    await widget.controller.load(await token());
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: controller.status == HomeStatus.loaded
          ? AppBar(
              title: Text(loc.appTitle),
              actions: [
                // Pull-to-refresh has no keyboard/mouse equivalent (Flutter's
                // default `ScrollBehavior` doesn't drag on mouse input, and
                // there is nothing to Tab to inside the gesture), so this is
                // the only reachable refresh control for those users. Wired
                // to the same `_refreshDashboard` as the pull and the retry
                // button.
                //
                // Shown on exactly the condition `_refreshDashboard` acts on
                // — a controller AND a token provider. The looser
                // `dashboardController != null` put a button on screen that
                // the guard turns into a no-op, i.e. one that can never
                // respond to a press.
                //
                // It stays ENABLED mid-round and says so with a spinner in
                // place of its icon. Nulling `onPressed` takes the button out
                // of the focus traversal while it is the focused node, and
                // focus does not come back when the round ends: a keyboard
                // user who presses it loses their place and has to Tab the
                // whole page again. Nothing is protected by disabling it —
                // `HomeDashboardController.load` already returns the running
                // round instead of starting a second fan-out.
                if (_canRefresh)
                  IconButton(
                    key: const Key('home-refresh-button'),
                    tooltip: loc.homeRefreshTooltip,
                    onPressed: () => unawaited(_refreshDashboard()),
                    icon:
                        widget.dashboardController!.status ==
                            HomeDashboardStatus.loading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                  ),
                IconButton(
                  key: const Key('settings-icon-button'),
                  tooltip: loc.settingsIconTooltip,
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings_outlined),
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.clamp(0, _contentMaxWidth);
            return Center(
              child: SizedBox(
                width: width.toDouble(),
                child: _buildBody(controller),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(HomeController controller) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    switch (controller.status) {
      case HomeStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case HomeStatus.loaded:
        final name = controller.profile?.displayName?.trim() ?? '';
        return RefreshIndicator(
          onRefresh: _refreshDashboard,
          semanticsLabel: loc.homeRefreshTooltip,
          child: SingleChildScrollView(
            // Always scrollable so a short home on a tall screen still accepts
            // the overscroll pull that triggers the refresh.
            physics: const AlwaysScrollableScrollPhysics(),
            // Vertical only. The horizontal inset moves onto the content
            // below, because `StaleNotice` carries its own horizontal padding
            // (see its doc: a screen whose padding sits on the scroll view
            // must move it onto the content, or the notice inherits it twice
            // and sits indented past every other line on the page).
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: LastLoadedLabel(
                    lastLoadedAt: widget.dashboardController?.lastLoadedAt,
                  ),
                ),
                // Right beside the timestamp it qualifies, and above the fold
                // on a phone screen — appended after the whole dashboard (as
                // every other card-level StaleNotice does after its own
                // card) leaves it several screens below where a pull started
                // at the top of the page, so a failed refresh reads as
                // silence instead of a failure. `dashboard.data != null` only:
                // the no-data-yet case already shows `_DashboardUnavailable`.
                //
                // It is keyed off the PAGE status, which now means "the last
                // round lost every arm" — a round that lost only some arms
                // leaves this row quiet and is reported by the markers on the
                // tiles that actually failed. Deliberate: a page-wide "not
                // updated" over seven figures that were updated says the
                // wrong thing, and the per-arm truth is not expressible here.
                // The two notices also do different work — this one's retry
                // reloads all seven arms, a tile's reloads one.
                if (widget.dashboardController != null &&
                    widget.dashboardController!.data != null)
                  StaleNotice(
                    failed:
                        widget.dashboardController!.status ==
                        HomeDashboardStatus.error,
                    loading:
                        widget.dashboardController!.status ==
                        HomeDashboardStatus.loading,
                    subject: loc.homeDashboardTitle,
                    onRetry: () => unawaited(_refreshDashboard()),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _greeting(loc, widget.clock(), name),
                        key: const Key('home-greeting'),
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        loc.homeHubPrompt,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _AssistantEntry(onTap: _openAssistant),
                      const SizedBox(height: 18),
                      _buildDashboard(),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _FutureEntry(
                              entryKey: const Key('tasks-tile'),
                              icon: Icons.task_alt_outlined,
                              label: loc.spaceTasks,
                              comingSoon: loc.spaceComingSoon,
                              onTap: _showComingSoon,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _FutureEntry(
                              entryKey: const Key('journal-tile'),
                              icon: Icons.menu_book_outlined,
                              label: loc.spaceJournal,
                              comingSoon: loc.spaceComingSoon,
                              onTap: _showComingSoon,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          buildLabel,
                          key: const Key('build-label'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      case HomeStatus.error:
        final errorText = controller.error == ProfileError.fetchFailed
            ? loc.errorProfileLoadFailed
            : loc.errorSomethingWentWrong;
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                errorText,
                key: const Key('error-message'),
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 16),
              // Primary action is retry, not sign-out: a failed profile
              // fetch is often a transient timeout, and sign-out (which
              // wipes per-user state, e.g. #156) must not be the only exit
              // from a slow backend.
              if (widget.idToken != null) ...[
                FilledButton(
                  key: const Key('profile-retry-button'),
                  onPressed: _retryProfile,
                  child: Text(loc.retry),
                ),
                const SizedBox(height: 8),
              ],
              TextButton(
                key: const Key('sign-out-button'),
                onPressed: controller.signOut,
                child: Text(loc.signOut),
              ),
            ],
          ),
        );
      case HomeStatus.needsReauth:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loc.pleaseSignInAgain, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('sign-in-again-button'),
                onPressed: controller.signOut,
                child: Text(loc.signInAgain),
              ),
            ],
          ),
        );
    }
  }

  /// Refetches the one arm behind a single tile, from that tile's own retry
  /// marker. Not [_refreshDashboard]: the other seven tiles keep their
  /// figures, no page-level spinner turns and "updated HH:mm" does not move —
  /// see `HomeDashboardController`'s Invariant P.
  ///
  /// A fresh token per press, for the same reason [_refreshDashboard] takes
  /// one (issue #106).
  ///
  /// [label] is the pressed tile's own name, and the announcement is prefixed
  /// with it for the same reason the marker's semantics label is: on a screen
  /// where eight tiles can each fail, "Couldn't refresh" alone does not say
  /// which one just answered.
  Future<void> _retryArm(DashboardArm arm, String label) async {
    final dashboard = widget.dashboardController;
    final token = widget.idToken;
    if (dashboard == null || token == null) return;
    final loc = AppLocalizations.of(context)!;
    final direction = Directionality.of(context);
    try {
      await dashboard.retryArm(arm, await token(), widget.clock());
    } catch (_) {
      // `retryArm` swallows the arm's own error (it becomes the tile's failed
      // state), so this only catches a token renewal that throws — and the
      // tile is already showing the previous failure, which is the honest
      // rendering of "still not loaded".
    }
    if (!mounted) return;
    // A retry that fails again repaints *nothing*: same figure, same marker,
    // same semantics label. Without this a screen-reader user presses the
    // button and cannot tell a slow request from a finished one, and pressing
    // it a second time is indistinguishable from the first.
    // ...and the same is true with the sound off. A sighted user pressing a
    // marker that fails again sees *no* pixel change at all, so the SnackBar
    // is the visible half of the announcement below, not a second feature:
    // the same two outcomes, the same two strings, the same tile prefix. It
    // floats above the page, so it cannot move a tile's height — the
    // invariant that rules out saying this inside the tile itself.
    //
    // Seven markers pressed in a row overwrite one another rather than queue.
    // `_refreshDashboard` deliberately has no SnackBar of its own, so nothing
    // else on this page competes for the slot.
    void say(String message) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$label: $message')));
    }

    final slot = dashboard.data?.slotOf(arm);
    if (slot == null || slot.status == ArmStatus.failed) {
      SemanticsService.announce('$label: ${loc.cardRefreshFailed}', direction);
      say(loc.cardRefreshFailed);
    } else if (slot.status == ArmStatus.loaded) {
      SemanticsService.announce('$label: ${loc.homeTileRefreshed}', direction);
      say(loc.homeTileRefreshed);
    }
    // Still loading: a newer request for the same arm is in flight and will
    // make its own announcement. Two would race and the loser would be the
    // one describing the state actually on screen.
  }

  /// The one builder behind every snapshot tile, in both dashboard branches
  /// (eleven call sites), so the masking wiring — and now the per-arm
  /// status/retry wiring — cannot be right in one branch and missing in the
  /// other.
  ///
  /// [arm] and [slot] travel together: the slot says what to paint, and the
  /// arm is what a retry from this tile refetches.
  Widget _snapshotTile({
    required String tileId,
    required AppLocalizations loc,
    required DashboardArm arm,
    required ArmSlot<Object?> slot,
    required String label,
    required String value,
    required VoidCallback onTap,
    String? shorterValue,
    String? valueSemanticLabel,
    Widget? badge,
    String? secondLine,
    Color? outlineColor,
    Key? actionIconKey,
    IconData? actionIcon,
    String? actionIconTooltip,
    VoidCallback? onActionIcon,
    PrivacyMaskItem? maskItem,
  }) {
    final mask = widget.privacyMaskController;
    return _SnapshotTile(
      tileKey: Key(tileId),
      label: label,
      value: value,
      shorterValue: shorterValue,
      valueSemanticLabel: valueSemanticLabel,
      badge: badge,
      secondLine: secondLine,
      outlineColor: outlineColor,
      actionIconKey: actionIconKey,
      actionIcon: actionIcon,
      actionIconTooltip: actionIconTooltip,
      onActionIcon: onActionIcon,
      onTap: onTap,
      armStatus: slot.status,
      hasValue: slot.hasValue,
      retryKey: Key('$tileId-retry'),
      // Offered on exactly the condition `_retryArm` acts on, for the same
      // reason the app bar's refresh button is: a marker the guard turns into
      // a no-op is a control that can never respond to a press.
      onRetry: _canRefresh ? () => unawaited(_retryArm(arm, label)) : null,
      loadFailedLabel: loc.homeTileLoadFailed,
      retryLabel: loc.retry,
      refreshingLabel: loc.cardRefreshing,
      maskItem: maskItem,
      isHidden: maskItem != null && mask.isHidden(maskItem),
      onToggleMask: maskItem == null
          ? null
          : () => unawaited(mask.toggle(maskItem)),
      maskedValue: loc.homeMaskedValue,
      hiddenSemanticLabel: loc.homeValueHidden,
      hideLabel: maskItem == null ? '' : loc.homeMaskHide(label),
      showLabel: maskItem == null ? '' : loc.homeMaskShow(label),
    );
  }

  /// The 食物份量 tile.
  ///
  /// It has no "no data" rendering at all, and that absence is the fix for the
  /// bug this whole model exists for: the backend always answers with a
  /// default target, so an empty figure here was never an empty *record* —
  /// it was a failed request printing 無資料. See
  /// `HomeDashboardData.dailyTarget`.
  Widget _foodPortionTile(
    AppLocalizations loc,
    ArmSlot<DailyTargetWithRemaining> slot,
  ) {
    final target = slot.value;
    return _snapshotTile(
      tileId: 'home-food-dictionary',
      loc: loc,
      arm: DashboardArm.dailyTarget,
      slot: slot,
      label: loc.homeFoodPortion,
      value: target == null
          ? ''
          : _portionTargetValue(loc, target.effective, withVeg: true),
      shorterValue: target == null
          ? null
          : _portionTargetValue(loc, target.effective, withVeg: false),
      // Whatever the tile ends up *painting*, assistive tech is told the
      // whole figure, spelled out with each group's NAME rather than its
      // one-glyph icon — the painted string's own icons (in English, bare
      // letters S/M/F/V) don't decode when read aloud, so re-using the full
      // string here would not actually compensate for the visual elision.
      valueSemanticLabel: target == null
          ? null
          : loc.homeFoodPortionTargetSemantics(
              _compactNumber(target.effective.staple),
              _compactNumber(target.effective.meat),
              _compactNumber(target.effective.fruit),
              _compactNumber(target.effective.veg),
            ),
      actionIconKey: const Key('home-food-portion-search'),
      actionIcon: Icons.search,
      actionIconTooltip: loc.homeFoodPortionButton,
      onActionIcon: _openFoodDictionary,
      onTap: _openFoodDictionary,
    );
  }

  Widget _buildDashboard() {
    final loc = AppLocalizations.of(context)!;
    final dashboard = widget.dashboardController;
    // `dashboard == null` ONLY — deliberately not `status == idle`. `idle`
    // means "nobody has asked for the figures yet", and since the fan-out was
    // deferred to the moment home becomes the visible page, that state now
    // outlives the first frame of every return to home: the listener fires,
    // then waits on `idToken()` (which reaches the network whenever the token
    // is close to expiring). Painting the no-data layout during that gap tells
    // a user who has records that they have none.
    //
    // Fed all-loading slots rather than 無資料, for exactly that reason: "not
    // fetched yet" and "you have no record" are two different things, and this
    // branch is the first one. It is the same tile code as every other branch,
    // so a destination, a privacy eye or an arm wired on one path cannot be
    // missing on the other.
    if (dashboard == null) {
      return _dashboardTiles(loc, const HomeDashboardData.allLoading());
    }
    // Both fallbacks below are gated on `data == null`, i.e. on there being
    // nothing to show — never on the status alone. A pull-to-refresh sets
    // `loading` and then possibly `error` with the previous figures still
    // held, and swapping the whole dashboard for a spinner (which also
    // shrinks the scrollable under the user's finger mid-gesture) or for the
    // "couldn't load" card would throw away data that is still perfectly
    // displayable. A failed reload keeps the figures, marks the arms that
    // failed on their own tiles, and marks the page stale below.
    //
    // `data == null` after a round now means all seven arms failed with
    // nothing to fall back on — total failure, which is the one case the
    // single whole-dashboard card with a single retry was always right for.
    final data = dashboard.data;
    if (data == null) {
      if (dashboard.status == HomeDashboardStatus.idle ||
          dashboard.status == HomeDashboardStatus.loading) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(36),
            child: CircularProgressIndicator(),
          ),
        );
      }
      return _DashboardUnavailable(
        text: loc.homeDashboardLoadFailed,
        retryLabel: loc.retry,
        onRetry: _refreshDashboard,
      );
    }
    return _dashboardTiles(loc, data);
  }

  /// The 生理週期預測 tile: the one tile whose figure is a *state*, so it is
  /// the one that leads with a badge and names the date that state is about.
  ///
  /// The date is what makes it a snapshot rather than a riddle: "day 4"
  /// without a start date, or "3 days late" without the date it is late for,
  /// sends the user into the tracker to recover a date the client already
  /// holds. The badge appearance, the label and the ongoing start date all
  /// come from the menstrual presentation helpers the overview card uses, so
  /// the two surfaces cannot depict one state differently.
  Widget _menstrualTile(AppLocalizations loc, ArmSlot<NextPeriodStatus> slot) {
    final status = slot.value;
    final scheme = Theme.of(context).colorScheme;
    final badgeStyle = status == null
        ? null
        : cycleBadgeStyleFor(status.state, scheme);
    final badgeLabel = status == null ? null : cycleBadgeLabel(loc, status);
    final now = widget.clock();
    final start = status == null ? null : ongoingPeriodStart(status, now);
    final predicted = status?.predictedNextStart;
    // The date the state is about — the derived start date while a period is
    // ongoing, the prediction otherwise. `upcoming` is absent on purpose: its
    // value line already *is* the predicted date, and repeating it underneath
    // would print the same date twice.
    final dateLine = switch (status?.state) {
      NextPeriodState.ongoing when start != null =>
        loc.homeMenstrualOngoingStart(shortYearDateLabel(context, start)),
      NextPeriodState.overdue when predicted != null =>
        loc.homeMenstrualExpected(shortYearDateLabel(context, predicted)),
      // No "= today" suffix: the value line above already says it is today.
      NextPeriodState.today when predicted != null =>
        shortYearDateLabel(context, predicted),
      _ => null,
    };
    final semanticDate = start ?? predicted;
    return _snapshotTile(
      tileId: 'home-menstrual-prediction',
      loc: loc,
      arm: DashboardArm.menstrual,
      slot: slot,
      label: loc.homeMenstrualPrediction,
      value: status == null
          ? loc.homeNoData
          : _menstrualValue(context, loc, status),
      valueSemanticLabel: status == null
          ? null
          : cycleStatusSemanticLabel(
              loc,
              status,
              semanticDate == null
                  ? null
                  : shortYearDateLabel(context, semanticDate),
            ),
      badge: badgeStyle == null || badgeLabel == null
          ? null
          : CycleBadge(
              key: const Key('home-menstrual-badge'),
              filled: badgeStyle.filled,
              color: badgeStyle.color,
              textColor: badgeStyle.textColor,
              label: badgeLabel,
            ),
      secondLine: dateLine,
      // The only tile that ever changes its outline colour, and only in the
      // one state where something is wrong. Colour is never the only signal:
      // the badge and the value both spell the overage out in words.
      outlineColor: status?.state == NextPeriodState.overdue
          ? financeBudgetWarningColor(scheme)
          : null,
      onTap: _openMenstrual,
    );
  }

  /// The eight tiles, for any [data] — including the all-loading placeholder.
  ///
  /// Each tile is handed the slot of the arm that feeds it, so "this figure"
  /// and "how that figure's request went" arrive together and cannot disagree.
  /// 淨值 and 總負債 share `netWorth`: one request answers both, so they fail
  /// and retry together.
  ///
  /// The `loc.homeNoData` fallbacks below are still evaluated for a slot with
  /// no value — that is the cold-failure case — but never *painted* in it:
  /// `_SnapshotTile._valueArea` swaps the whole value area for the status
  /// line whenever `hasValue` is false, which is what stops a failed fetch
  /// from reading as an empty record. Do not "simplify" them into `!`: for
  /// the non-nullable arms (`netWorth`, `menstrualStatus`, `splitBalances`,
  /// `dailyTarget`) the value really is null while nothing has been fetched,
  /// and the unwrap would throw on exactly the state this change is about.
  Widget _dashboardTiles(AppLocalizations loc, HomeDashboardData data) {
    final weightKg = data.weightGoal.value?.currentWeightKg;
    final bloodPressure = data.bloodPressure.value;
    final overallBudget = data.overallBudget.value;
    final netWorth = data.netWorth.value;
    final splitBalances = data.splitBalances.value;
    return Column(
      children: [
        _DashboardSection(
          sectionKey: const Key('health-dashboard-section'),
          openKey: const Key('health-tile'),
          title: loc.spaceHealth,
          openLabel: loc.homeOpenHealth,
          onOpen: _openHealth,
          twoColumnMinWidth: _sectionTwoColumnMinWidth,
          children: [
            _snapshotTile(
              tileId: 'home-latest-weight',
              loc: loc,
              arm: DashboardArm.weightGoal,
              slot: data.weightGoal,
              maskItem: PrivacyMaskItem.latestWeight,
              label: loc.homeLatestWeight,
              value: weightKg == null
                  ? loc.homeNoData
                  : loc.homeWeightValue(_compactNumber(weightKg)),
              onTap: _openVitals,
            ),
            _foodPortionTile(loc, data.dailyTarget),
            _snapshotTile(
              tileId: 'home-latest-blood-pressure',
              loc: loc,
              arm: DashboardArm.vitals,
              slot: data.bloodPressure,
              label: loc.homeLatestBloodPressure,
              value: bloodPressure == null
                  ? loc.homeNoData
                  : '${_compactNumber(bloodPressure.systolic)} / '
                        '${_compactNumber(bloodPressure.diastolic)}',
              onTap: _openVitals,
            ),
            _menstrualTile(loc, data.menstrualStatus),
          ],
        ),
        const SizedBox(height: 14),
        _DashboardSection(
          sectionKey: const Key('finance-dashboard-section'),
          openKey: const Key('finance-tile'),
          title: loc.spaceFinance,
          openLabel: loc.homeOpenFinance,
          onOpen: _openFinance,
          twoColumnMinWidth: _sectionTwoColumnMinWidth,
          children: [
            _snapshotTile(
              tileId: 'home-budget',
              loc: loc,
              arm: DashboardArm.budgets,
              slot: data.overallBudget,
              maskItem: PrivacyMaskItem.budget,
              label: loc.homeBudget,
              value: overallBudget == null
                  ? loc.homeNoData
                  : loc.homeBudgetRemaining(
                      formatMinorUnitsForDisplay(
                        overallBudget.remaining,
                        defaultCurrency,
                      ),
                    ),
              onTap: _openFinance,
            ),
            _snapshotTile(
              tileId: 'home-net-worth',
              loc: loc,
              arm: DashboardArm.netWorth,
              slot: data.netWorth,
              maskItem: PrivacyMaskItem.netWorth,
              label: loc.homeNetWorth,
              value: netWorth == null
                  ? loc.homeNoData
                  : formatNetMinorUnitsForDisplay(
                      netWorth.netWorth,
                      defaultCurrency,
                    ),
              onTap: () => _openFinanceTab(FinanceTab.networth),
            ),
            _snapshotTile(
              tileId: 'home-total-liabilities',
              loc: loc,
              arm: DashboardArm.netWorth,
              slot: data.netWorth,
              maskItem: PrivacyMaskItem.totalLiabilities,
              label: loc.homeTotalLiabilities,
              value: netWorth == null
                  ? loc.homeNoData
                  : formatMinorUnitsForDisplay(
                      netWorth.totalLiability,
                      defaultCurrency,
                    ),
              onTap: () => _openFinanceTab(FinanceTab.networth),
            ),
            _snapshotTile(
              tileId: 'home-split-overview',
              loc: loc,
              arm: DashboardArm.balances,
              slot: data.splitBalances,
              label: loc.homeSplitOverview,
              value: splitBalances == null
                  ? loc.homeNoData
                  : _splitValue(loc, splitBalances),
              onTap: () => _openFinanceTab(FinanceTab.split),
            ),
          ],
        ),
      ],
    );
  }
}

String _greeting(AppLocalizations loc, DateTime now, String name) {
  final period = greetingPeriodFor(now);
  if (name.isEmpty) {
    return switch (period) {
      GreetingPeriod.morning => loc.greetingMorning,
      GreetingPeriod.afternoon => loc.greetingAfternoon,
      GreetingPeriod.evening => loc.greetingEvening,
    };
  }
  return switch (period) {
    GreetingPeriod.morning => loc.greetingMorningName(name),
    GreetingPeriod.afternoon => loc.greetingAfternoonName(name),
    GreetingPeriod.evening => loc.greetingEveningName(name),
  };
}

String _compactNumber(num value) =>
    value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);

/// Today's effective portion target as count + one-glyph icon per food group
/// — all four groups, or the first three when [withVeg] is false. The
/// separators and the group order live in the ARB, not here.
///
/// Each count binds to its own group glyph with no space (`10主`), and only
/// the group-to-group gap is a space. That is not cosmetic: it is what takes
/// the four-group string's natural width from 258.40 to 193.80 on this build
/// and so moves the width at which 菜 survives from 470dp to 386dp — but
/// 332–385.5dp, which includes ordinary widths like 360dp and 375dp, still
/// elides it. See the measured tables in `home_screen_responsive_test.dart`'s
/// 食物份量 group.
///
/// **Known, not fixed here: fractional (half-portion) targets.** `Portions`
/// fields are `double` and the portion stepper's step is 0.5, so
/// `_compactNumber` can print e.g. `10.5` instead of `10`. A string with even
/// one `.5` group is wider than this doc's integer-only measurements assume,
/// and can paint below `_portionValueMinScale` — even below
/// `_minValueScaleAtNarrowestTile` in `home_screen_responsive_test.dart` — on
/// ordinary phone widths. See the characterization test for it in the
/// 食物份量 group. Redesigning the candidate strings (or the boundary
/// numbers this file documents) to also hold that floor for fractional
/// targets is out of scope for issue #196.
///
/// The short rendering carries a bare trailing `…` (no leading space) as a
/// visible elision marker, so "today has no 菜 target" and "菜 was dropped
/// for space" don't look identical. Remeasured after the tightening: the
/// short string is 161.50 natural with the marker and 145.35 without, and at
/// the narrowest two-column tile (332dp, value box 99.00) it paints at
/// 0.6130× — above the 0.45 floor that corner is held to. The full figure
/// also reaches assistive tech through the tile's semantics label — see
/// `_SnapshotTile.valueSemanticLabel`.
String _portionTargetValue(
  AppLocalizations loc,
  Portions portions, {
  required bool withVeg,
}) {
  final staple = _compactNumber(portions.staple);
  final meat = _compactNumber(portions.meat);
  final fruit = _compactNumber(portions.fruit);
  if (!withVeg) {
    return loc.homeFoodPortionTargetShort(
      staple,
      loc.dietCategoryIconStaple,
      meat,
      loc.dietCategoryIconMeat,
      fruit,
      loc.dietCategoryIconFruit,
    );
  }
  return loc.homeFoodPortionTargetFull(
    staple,
    loc.dietCategoryIconStaple,
    meat,
    loc.dietCategoryIconMeat,
    fruit,
    loc.dietCategoryIconFruit,
    _compactNumber(portions.veg),
    loc.dietCategoryIconVeg,
  );
}

String _menstrualValue(
  BuildContext context,
  AppLocalizations loc,
  NextPeriodStatus status,
) {
  switch (status.state) {
    case NextPeriodState.ongoing:
      return loc.homeMenstrualOngoing(status.days!);
    case NextPeriodState.noRecords:
      return loc.homeNoData;
    case NextPeriodState.needsOneMore:
      return loc.homeMenstrualNeedsMore;
    case NextPeriodState.upcoming:
      return loc.homeMenstrualExpected(
        shortYearDateLabel(context, status.predictedNextStart!),
      );
    case NextPeriodState.today:
      return loc.homeMenstrualToday;
    case NextPeriodState.overdue:
      return loc.homeMenstrualOverdue(status.days!);
  }
}

String _splitValue(AppLocalizations loc, List<Balance> splitBalances) {
  var receivable = 0;
  var payable = 0;
  for (final person in splitBalances) {
    for (final balance in person.balances) {
      if (balance.currency != defaultCurrency) continue;
      if (balance.amount > 0) receivable += balance.amount;
      if (balance.amount < 0) payable += -balance.amount;
    }
  }
  if (receivable == 0 && payable == 0) return loc.homeSplitSettled;
  if (receivable > 0) {
    return loc.homeSplitReceivable(
      formatMinorUnitsForDisplay(receivable, defaultCurrency),
    );
  }
  return loc.homeSplitPayable(
    formatMinorUnitsForDisplay(payable, defaultCurrency),
  );
}

class _AssistantEntry extends StatelessWidget {
  final VoidCallback onTap;

  const _AssistantEntry({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return LedgeCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        key: const Key('home-assistant-bar'),
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.smart_toy_outlined),
              const SizedBox(width: 12),
              Expanded(child: Text(loc.homeAssistantBarLabel)),
              const Icon(Icons.arrow_forward),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardSection extends StatelessWidget {
  final Key sectionKey;
  final Key openKey;
  final String title;
  final String openLabel;
  final VoidCallback onOpen;
  final List<Widget> children;

  /// Inner-width breakpoint below which this section's tiles stack into a
  /// single column. Caller-supplied rather than read from the file-level
  /// constant directly, so each call site still names the threshold it wants
  /// — today every one of them passes `_sectionTwoColumnMinWidth`, but the
  /// parameter is what let health and finance hold different values while
  /// #189/#190 were open, and what keeps this widget reusable by a section
  /// with different content.
  final double twoColumnMinWidth;

  const _DashboardSection({
    required this.sectionKey,
    required this.openKey,
    required this.title,
    required this.openLabel,
    required this.onOpen,
    required this.children,
    required this.twoColumnMinWidth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LedgeCard(
      key: sectionKey,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
              TextButton(
                key: openKey,
                onPressed: onOpen,
                child: Text(openLabel),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final singleColumn = constraints.maxWidth < twoColumnMinWidth;
              final tileWidth = singleColumn
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final child in children)
                    SizedBox(width: tileWidth, child: child),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SnapshotTile extends StatelessWidget {
  final Key tileKey;
  final String label;
  final String? value;

  /// A shorter rendering of the same figure, printed instead of [value] when
  /// [value] would have to shrink below [_portionValueMinScale] to fit.
  /// `null` on every tile that has only one rendering — and then the tile
  /// measures nothing and behaves exactly as it did before this existed.
  final String? shorterValue;

  /// What assistive tech is told the value is, when that must not depend on
  /// which rendering happened to fit. `null` leaves the painted text to speak
  /// for itself, which is right for every tile whose value has one rendering.
  final String? valueSemanticLabel;

  /// A leading status badge (currently only the menstrual tile's
  /// [CycleBadge]) painted beside the value. `null` on every other tile.
  final Widget? badge;

  /// An optional second line under the value — the date a state names (e.g.
  /// "7月2日 開始"). `null` on every tile that has nothing to add.
  final String? secondLine;

  /// Overrides the tile's outline colour (currently only the menstrual
  /// tile's `overdue` state, via `financeBudgetWarningColor`). `null` keeps
  /// the default `colorScheme.outline`.
  final Color? outlineColor;

  final VoidCallback onTap;

  /// An optional action button on the label row (today: the portion-guide
  /// search icon). Mutually exclusive with the privacy eye in practice — the
  /// tile that has one is not maskable — but written as two independent
  /// `if`s rather than an either/or, so adding a second one is a layout
  /// question, not a silently-dropped widget.
  final Key? actionIconKey;
  final IconData? actionIcon;
  final String? actionIconTooltip;
  final VoidCallback? onActionIcon;

  /// Non-null on the tiles the user is allowed to hide — and the only thing
  /// that puts an eye on a tile.
  final PrivacyMaskItem? maskItem;
  final bool isHidden;
  final VoidCallback? onToggleMask;

  /// How the request behind **this tile's** figure went.
  ///
  /// [ArmStatus.failed] is never rendered as [value]: a failed fetch that
  /// paints the same 無資料 as an empty record is the bug this whole state
  /// exists to remove.
  final ArmStatus armStatus;

  /// Whether [value] is a real figure. False while nothing has been fetched
  /// yet and after a failure with nothing to fall back on — the two cases
  /// where the value area is replaced rather than annotated.
  final bool hasValue;

  /// Refetches this tile's arm alone. `null` where no reload is possible at
  /// all, and then no retry affordance is drawn.
  final VoidCallback? onRetry;
  final Key? retryKey;

  /// Already-localized strings. The tile never looks up [AppLocalizations]
  /// itself, matching every other string it is handed.
  final String maskedValue;
  final String hiddenSemanticLabel;
  final String hideLabel;
  final String showLabel;
  final String loadFailedLabel;
  final String retryLabel;
  final String refreshingLabel;

  const _SnapshotTile({
    required this.tileKey,
    required this.label,
    this.value,
    this.shorterValue,
    this.valueSemanticLabel,
    this.badge,
    this.secondLine,
    this.outlineColor,
    this.actionIconKey,
    this.actionIcon,
    this.actionIconTooltip,
    this.onActionIcon,
    required this.onTap,
    this.maskItem,
    this.isHidden = false,
    this.onToggleMask,
    this.maskedValue = '',
    this.hiddenSemanticLabel = '',
    this.hideLabel = '',
    this.showLabel = '',
    this.armStatus = ArmStatus.loaded,
    this.hasValue = true,
    this.onRetry,
    this.retryKey,
    this.loadFailedLabel = '',
    this.retryLabel = '',
    this.refreshingLabel = '',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maskItem = this.maskItem;
    return InkWell(
      key: tileKey,
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        // 110, not the original 92: the eye grows the title row from ~16 to a
        // 44pt tap target, and `Wrap` does not stretch a short tile to match a
        // tall one — leaving the eyeless tiles visibly shorter beside them.
        constraints: const BoxConstraints(minHeight: 132),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: outlineColor ?? theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // The eye rides the TITLE row, not the value row: the title is a
            // short `bodySmall`, while the value can be as long as
            // "剩餘 NT$123,456" — an eye beside that is the first thing to
            // overflow in the 320dp single-column layout.
            Row(
              // Top-aligned so the title sits at the same offset in every
              // tile: the eye makes this row 48dp tall (its 44pt tap target
              // plus Material's tap-target padding), far taller than the
              // `bodySmall` title, and centering pushed the titles of the
              // tiles that have an eye 8–16dp down from the ones that don't
              // (16 for a one-line title, 8 once it wraps to two). The icons
              // themselves keep their full row height and tap area — only the
              // title moves.
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
                if (maskItem != null)
                  IconButton(
                    key: Key('home-mask-toggle-${maskItem.name}'),
                    icon: Icon(
                      isHidden
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 44,
                      height: 44,
                    ),
                    tooltip: isHidden ? showLabel : hideLabel,
                    onPressed: onToggleMask,
                  ),
                if (actionIcon case final icon?)
                  IconButton(
                    key: actionIconKey,
                    icon: Icon(icon),
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 44,
                      height: 44,
                    ),
                    tooltip: actionIconTooltip,
                    onPressed: onActionIcon,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _valueArea(context, theme),
          ],
        ),
      ),
    );
  }

  /// The bottom half of the tile: the figure, or — when this tile's own
  /// request is in flight or failed with nothing to show — what happened to
  /// it instead, plus the retry that refetches this arm alone.
  ///
  /// The empty [Text] leading the row is a **line-height pin**, not a stray
  /// widget: everything else here sits under a `BoxFit.scaleDown` `FittedBox`
  /// and so is painted *shorter* the more it has to shrink, which would make
  /// a tile change height between loaded / loading / failed — and this repo's
  /// record is that a page that grows or shrinks under the user is how a tap
  /// silently lands on the wrong thing. Pinned to one line of the value's own
  /// style, the row is the same height in all three states at every text
  /// scale.
  ///
  /// No `CircularProgressIndicator` anywhere in here, deliberately: an
  /// animation that never settles turns every `pumpAndSettle` on a screen
  /// holding one of these tiles into a hang, and eight of them ship in the
  /// placeholder branch. The page-level spinner (app bar, pull-to-refresh)
  /// stays where it is.
  Widget _valueArea(BuildContext context, ThemeData theme) {
    final showFigure = armStatus == ArmStatus.loaded || hasValue;
    final marker = showFigure ? _valueMarker(context, theme) : null;
    final row = Row(
      children: [
        // Only drawn once the figure itself is — a badge beside a loading
        // or cold-failure status line would claim a state the request
        // hasn't actually returned yet.
        if (badge != null && showFigure) ...[
          badge!,
          const SizedBox(width: 8),
        ],
        ExcludeSemantics(child: Text('', style: theme.textTheme.titleMedium)),
        Flexible(
          child: showFigure
              ? _figure(context, theme)
              : _statusLine(
                  theme,
                  armStatus == ArmStatus.failed
                      ? loadFailedLabel
                      : refreshingLabel,
                  failed: armStatus == ArmStatus.failed,
                ),
        ),
        if (marker != null) marker,
      ],
    );
    // Second line reserves its row even when there's nothing to print for
    // this state (needsOneMore / noRecords), so the tile's height doesn't
    // change between menstrual states — see R3 in
    // home_screen_responsive_test.dart.
    final line = secondLine;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        const SizedBox(height: 4),
        Text(
          showFigure ? (line ?? '') : '',
          key: line == null ? null : const Key('home-menstrual-date'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _figure(BuildContext context, ThemeData theme) {
    if (isHidden) {
      // A screen reader hears "Hidden", not four bullet characters read out
      // one by one — and, more importantly, never the figure itself, which is
      // still in the widget tree of a naive implementation that only
      // repaints.
      return Semantics(
        label: hiddenSemanticLabel,
        child: ExcludeSemantics(
          child: _tileValue(context, theme, maskedValue),
        ),
      );
    }
    if (valueSemanticLabel != null) {
      // Deliberately the same shape as the masked branch above: what is
      // painted may be a shortened rendering, so assistive tech is handed the
      // whole figure instead of whichever candidate fit.
      return Semantics(
        label: valueSemanticLabel,
        child: ExcludeSemantics(
          child: _tileValue(
            context,
            theme,
            value ?? '',
            shorterText: shorterValue,
          ),
        ),
      );
    }
    return _tileValue(context, theme, value ?? '', shorterText: shorterValue);
  }

  /// The small badge beside a figure that is on screen but *not* the result of
  /// this tile's latest request — the whole point of keeping the figure at
  /// all. Tappable only when failed **and** a reload is possible: while one is
  /// in flight there is nothing to ask for again, and with [onRetry] `null`
  /// there is nothing to ask at all. The reloading rendering comes only from a
  /// single-arm retry: a page-wide round deliberately leaves every arm's
  /// status alone (see `HomeDashboardController._load`), so a tile never shows
  /// it during a refresh.
  ///
  /// Drawn whether or not it can be tapped. A stale figure with no marker is
  /// pixel-identical to a fresh one, which is the "user reads the old number
  /// as the current one" failure this state exists to prevent — losing the
  /// *retry* because the screen has no token must not also lose the *notice*.
  ///
  /// Two things carry that notice, because one of them is nearly free and the
  /// other is not:
  ///
  /// - `colorScheme.error`, not the `onSurfaceVariant` of the rest of the
  ///   tile chrome. Colour costs no pixels, and a neutral 16px icon beside a
  ///   full-strength figure is the weakest signal available. This is louder
  ///   than the *colder* start failure in [_statusLine], on purpose — see the
  ///   note there for why the more severe state is drawn the quieter one.
  /// - The icon grows with the text scaler (capped at 1.5×, i.e. 16→24). At a
  ///   fixed 16px the one cue separating stale from current gets *relatively
  ///   smaller* exactly for the users who asked for larger text. The box
  ///   below shares that cap, so the two grow together.
  ///
  /// 32 wide × 24 tall **at 1×**, not the 44×44 a primary control (the privacy
  /// eye, and `home_screen_responsive_test.dart`'s R3 guard) gets — a
  /// deliberate deviation. The width stays fixed (R3b pins it, and 320dp has
  /// no horizontal room to gamble with); the height rides the text scaler on
  /// the same 1.5× cap as the icon inside it.
  ///
  /// What makes growing the height safe is a *ratio*, not the constant 24.
  /// What sets a tile's height is the empty `Text(style: titleMedium)` in
  /// [_valueArea], and that line box grows with the text scaler itself, so the
  /// marker can ride along without ever becoming the tallest thing in the row.
  /// Measured by forcing an oversized marker and reading the tile back (test
  /// font, so these are placeholder-font numbers): the row is **26** at 1× and
  /// **48** at 2×, against a marker of 24 and 36 — 2px and 12px of headroom.
  /// A marker pinned to a constant instead would shrink *relative* to the row
  /// exactly for the users who asked for larger text, which is the same reason
  /// the icon inside it scales.
  ///
  /// That 2px at 1× is why this is a ratio to preserve and not slack to
  /// spend, and it has been overspent once already: a flat 28 was measured
  /// pushing a tile from 110 to 112, i.e. making a failed tile taller than the
  /// same tile loaded — the height-change false green this value area exists
  /// to avoid.
  ///
  /// Do not lean on the equal-height guards in
  /// `home_screen_responsive_test.dart` to catch a regression here. Dropping
  /// the 1.5× cap makes this 48 at 2×, which is *exactly* the row height, so
  /// the tile does not move and those guards stay green — 49 is the first
  /// value that reds them. R3c asserts the marker's size directly, which is
  /// the reason it exists.
  ///
  /// A full-size retry stays available for the whole dashboard (`StaleNotice`,
  /// the app bar), so what this smaller target costs is convenience on one
  /// arm, not the ability to reload.
  Widget? _valueMarker(BuildContext context, ThemeData theme) {
    if (armStatus == ArmStatus.loaded) return null;
    final failed = armStatus == ArmStatus.failed;
    final tappable = failed && onRetry != null;
    return Semantics(
      container: true,
      button: tappable,
      enabled: tappable,
      // Named after the tile: eight tiles failing at once otherwise offer a
      // screen-reader user eight identically labelled "Retry" buttons with
      // nothing to tell them apart. Same composition as `StaleNotice`, whose
      // vocabulary this reuses rather than inventing a second one. The retry
      // half is dropped when there is nothing to press, rather than promising
      // an action that is not there.
      label: failed
          ? (tappable
                ? '$label: $loadFailedLabel. $retryLabel'
                : '$label: $loadFailedLabel')
          : '$label: $refreshingLabel',
      onTap: tappable ? onRetry : null,
      // The tile is itself an `InkWell` that navigates: without this the
      // marker's node merges into it and the reader is offered one node that
      // does two different things.
      excludeSemantics: true,
      // The only words a *sighted* user can get out of this state. The cold
      // start failure below is an icon **plus** "Couldn't load"; here the same
      // condition is an icon alone, so a user who has only ever hit the
      // partial case never meets the sentence that teaches the icon.
      //
      // Known gap, not a fix: Flutter shows this on hover, and on touch only
      // on long-press. On a 32-wide target that reads as "tap to retry",
      // long-press discovery is ~0 — so on phones this buys nothing on its
      // own, and the tap path is answered by the SnackBar in
      // `_HomeScreenState._retryArm` instead. Inside `excludeSemantics` on
      // purpose: the hand-written label above already says this, and letting
      // `Tooltip` add its own would say it twice.
      child: Tooltip(
        message: failed ? loadFailedLabel : refreshingLabel,
        child: InkWell(
          key: retryKey,
          onTap: tappable ? onRetry : null,
          child: SizedBox(
            width: 32,
            height: MediaQuery.textScalerOf(
              context,
            ).clamp(maxScaleFactor: 1.5).scale(24),
            child: Icon(
              failed ? Icons.cloud_off_outlined : Icons.sync,
              size: MediaQuery.textScalerOf(
                context,
              ).clamp(maxScaleFactor: 1.5).scale(16),
              color: failed
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  /// What a tile with no figure at all says instead of one. When it says the
  /// request failed, the line **is** the retry — there is nothing else in the
  /// value area to compete with the tap.
  ///
  /// This icon is drawn `onSurfaceVariant` while [_valueMarker], the *more*
  /// serious state, is drawn `colorScheme.error`. Painting the worse state
  /// quieter is deliberate: this line **has words**, so colour has nothing
  /// left to say; the marker is **an icon alone**, so colour is the entire
  /// signal. The rule is to spend colour where text does not fit. Both were
  /// measured against their backgrounds (5.07–6.22:1, AA).
  Widget _statusLine(ThemeData theme, String text, {required bool failed}) {
    final line = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            failed ? Icons.cloud_off_outlined : Icons.hourglass_empty,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            maxLines: 1,
            softWrap: false,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
    if (!failed || onRetry == null) return line;
    return Semantics(
      container: true,
      button: true,
      label: '$label: $loadFailedLabel. $retryLabel',
      onTap: onRetry,
      excludeSemantics: true,
      child: InkWell(key: retryKey, onTap: onRetry, child: line),
    );
  }

  /// A snapshot figure: **one line, never wrapped, never truncated**, shrunk
  /// to fit the tile when it is too narrow for the figure at full size.
  ///
  /// This is what replaced the two-column breakpoint as the answer to
  /// issues #189/#190. A plain `Text` hard-wraps a thousands-grouped amount
  /// mid-digit (`456,70` / `0` on the next line), and a wrap inside a number
  /// does not merely cramp it — it reads as a *different* number. Keeping
  /// the section single-column until the tile is wide enough only postponed
  /// that (it re-appeared as soon as two columns kicked in, #190); shrinking
  /// the glyphs removes it at every width.
  ///
  /// Two details that are load-bearing, not style:
  ///
  /// - `maxLines: 1` **and** `softWrap: false`. Both are belt-and-braces for
  ///   whoever later removes the `FittedBox`: measured by mutation, deleting
  ///   either one — or both — leaves every test in
  ///   `home_screen_responsive_test.dart` green, because a `FittedBox` lays
  ///   its child out at unbounded width and nothing can wrap there anyway.
  ///   Deleting the `FittedBox` too is what turns the line-count assertions
  ///   red. Kept, but do not read them as guarded.
  /// - No `overflow: TextOverflow.ellipsis`. The requirement is "not
  ///   truncated"; an ellipsis would satisfy the layout and corrupt the
  ///   figure exactly like the wrap did.
  ///
  /// `alignment: AlignmentDirectional.centerStart` below is kept for the
  /// same reason but is currently *not* load-bearing: measured by mutation,
  /// removing it leaves every test green, because the enclosing `Column`
  /// (`CrossAxisAlignment.start`) gives the `FittedBox` a loose constraint
  /// that shrink-wraps to its scaled child — `alignment` only becomes
  /// observable once a `FittedBox` is stretched to fill a wider box than its
  /// child. It is documentation of intent for whoever changes that
  /// surrounding layout, not a guarded property today.
  ///
  /// Known and deliberately not fixed here: because `BoxFit.scaleDown` shrinks
  /// whatever the text scaler grew, a user at 2× text scale can end up with a
  /// *smaller* painted figure than at 1×. That is the existing behaviour of
  /// all eight snapshot tiles, recorded on PR #197; undoing it means
  /// re-laying-out the whole row, which is out of scope for #196.
  ///
  /// [shorterText], when given, is a shorter rendering of the same figure to
  /// fall back to. The choice is made by **measuring** the candidates, not by
  /// letting the `FittedBox` decide: under `BoxFit.scaleDown` every string
  /// "fits" — it just gets smaller — so a fallback conditioned on the
  /// `FittedBox` giving up would never fire, and an unconditional fallback
  /// would throw away a group on screens wide enough to show it. See
  /// [_portionValueMinScale].
  Widget _tileValue(
    BuildContext context,
    ThemeData theme,
    String text, {
    String? shorterText,
  }) {
    // A figure left over from an earlier request is printed in the muted ink
    // the rest of the tile chrome uses, not the full-strength `onSurface` a
    // current one gets. The marker beside it is 24 logical pixels at most;
    // the figure is the whole width of the tile, so it is the larger half of
    // "this number is not the answer to the request you are looking at".
    final style = armStatus == ArmStatus.loaded
        ? theme.textTheme.titleMedium
        : theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          );
    if (shorterText == null) return _fittedValue(text, style);
    return LayoutBuilder(
      builder: (context, constraints) => _fittedValue(
        _widestFitting(context, style, constraints.maxWidth, [
          text,
          shorterText,
        ]),
        style,
      ),
    );
  }

  Widget _fittedValue(String text, TextStyle? style) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: AlignmentDirectional.centerStart,
    child: Text(text, maxLines: 1, softWrap: false, style: style),
  );
}

/// The smallest scale the shrink-to-fit snapshot value may be painted at
/// before a tile with a shorter rendering of the same figure switches to it.
///
/// Deliberately the same number as `_minValueScale` in
/// `home_screen_responsive_test.dart`, which is the measured legibility floor
/// the finance figures are held to — "too small to read" should not mean two
/// different things on two tiles of the same row. Change one and the other
/// has to move with it.
///
/// **A known, accepted consequence.** The tile
/// is (screen − 82) / 2 wide in the two-column layout and the whole width in
/// the single-column one, so the seam at 332dp *inverts*: 331dp is
/// single-column and wide enough for all four groups, 332dp is two-column and
/// is not. Widening a phone by one logical pixel therefore elides 菜. This is
/// the user's decision after seeing it — guaranteeing 主/肉/果 on one line is
/// worth 菜 being elided — and it is pinned by a characterization test
/// (`CHARACTERIZATION: widening the phone from 331dp to 332dp REMOVES 菜`) in
/// `home_screen_responsive_test.dart`, not left to be re-discovered as a bug.
///
/// Measured on this build after the separator tightening: 菜 comes back at
/// **386dp** and stays for every wider screen, so the elision band is
/// 332–385.5dp. It is *not* "essentially every phone" any more — that wording
/// described the pre-tightening 470dp threshold and would be wrong now — but
/// the band still contains 360dp and 375dp, two ordinary phone widths, not
/// only small-screen edge cases.
const _portionValueMinScale = 0.65;

/// The first of [candidates] whose text, laid out at its natural width, still
/// fits [maxWidth] without being shrunk below [_portionValueMinScale] — or the
/// last one when none does (it is then handed to the `FittedBox`, which
/// shrinks it the rest of the way; the candidate list is ordered longest
/// first and deliberately has no third, even shorter, entry).
///
/// The [TextPainter] carries this context's [TextScaler] and text direction:
/// without them a user at 200% text scale would be measured as if at 100% and
/// keep a rendering that no longer fits.
String _widestFitting(
  BuildContext context,
  TextStyle? style,
  double maxWidth,
  List<String> candidates,
) {
  final budget = maxWidth / _portionValueMinScale;
  final scaler = MediaQuery.textScalerOf(context);
  final direction = Directionality.of(context);
  for (final candidate in candidates) {
    final painter = TextPainter(
      text: TextSpan(text: candidate, style: style),
      maxLines: 1,
      textScaler: scaler,
      textDirection: direction,
    )..layout();
    final width = painter.width;
    painter.dispose();
    if (width <= budget) return candidate;
  }
  return candidates.last;
}

class _FutureEntry extends StatelessWidget {
  final Key entryKey;
  final IconData icon;
  final String label;
  final String comingSoon;
  final VoidCallback onTap;

  const _FutureEntry({
    required this.entryKey,
    required this.icon,
    required this.label,
    required this.comingSoon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      key: entryKey,
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label),
                  Text(comingSoon, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardUnavailable extends StatelessWidget {
  final String text;
  final String? retryLabel;
  final VoidCallback? onRetry;

  const _DashboardUnavailable({
    required this.text,
    this.retryLabel,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return LedgeCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(text, textAlign: TextAlign.center),
          if (onRetry != null && retryLabel != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: Text(retryLabel!)),
          ],
        ],
      ),
    );
  }
}
