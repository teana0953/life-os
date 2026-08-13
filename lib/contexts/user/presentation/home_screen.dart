import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/build_info.dart';
import '../../../shared/privacy/privacy_mask_controller.dart';
import '../../../shared/routing/finance_tab.dart';
import '../../../shared/widgets/last_loaded_label.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../../shared/widgets/stale_notice.dart';
import '../../finance/domain/finance_money.dart';
import '../../menstrual/domain/next_period_status.dart';
import 'home_controller.dart';
import 'home_dashboard_controller.dart';

const _contentMaxWidth = 960.0;

/// The `_DashboardSection` `LayoutBuilder`'s **inner** width (screen width
/// minus 20+20 page padding, 2+2 `LedgeCard` border, 14+14 `LedgeCard`
/// padding = 72) below which the **health** section's tiles stack into a
/// single column instead of two.
///
/// Health-only: its tile labels/values are short (a weight, a blood
/// pressure pair), so there is nothing in them that a hard line break can
/// corrupt — see `_financeTwoColumnMinWidth` for why the finance section
/// does not share this value.
///
/// Measured (not guessed): at inner 258, the zh-Hant tile labels (e.g.
/// 最新體重, 生理週期預測 — CJK glyphs beside the 44pt privacy eye) still fit on
/// one line and the value on at most two, with zero layout errors. At
/// inner 256 the labels break to two lines; at inner 254 the value also
/// breaks to three. So 258 is the measured legibility floor — the tile
/// itself cannot overflow until inner ≈150, far narrower, so this is a
/// readability threshold, not an overflow threshold. +2px margin for
/// font-metric drift across Flutter/Quicksand versions.
const _healthTwoColumnMinWidth = 260.0;

/// The finance section's own version of `_healthTwoColumnMinWidth` — kept far
/// above health's 260, because a narrow finance tile doesn't just cramp, it
/// corrupts.
///
/// Finance tiles print money (e.g. 456,700 / 9,999,999), and a two-column
/// tile that's too narrow forces `Text` to hard-wrap a thousands-grouped
/// number mid-digit (`456,70` / `0` on its own line) — a wrap that turns the
/// figure into a different, misread number rather than merely a cramped one.
/// This constant (330) removes that failure for the Samsung Flip7 width the
/// bug was actually filed against (issue #189: inner 288–359, screen
/// 360–431dp) *only up to where the section goes two columns* — inner 330
/// keeps the section single-column through screen 332–401dp, so there is no
/// two-column tile at those widths to split anything.
///
/// It does **not** hold once the section actually goes two columns. Measured
/// (not guessed): a two-column finance tile only holds `9,999,999` on one
/// line from tile width 171.5 up (170.75 still splits it) — tileWidth =
/// (inner-10)/2, inner = screenWidth-72. At screen 402–424dp (inner
/// 330–352, tileWidth 160–171 — ordinary widths: iPhone 16 Pro at 402,
/// Pixel 8/9 at 412) the section is two columns *and* the tile is narrower
/// than that floor, so `9,999,999` splits mid-digit again. The floor isn't
/// reached until inner 353 (tileWidth 171.5), i.e. screen 425dp (inner 353).
/// Raising this constant to 356 would close that gap by keeping finance
/// single-column through it, but at the cost of losing two-column finance
/// entirely on 402–424dp phones — out of scope for #189 (which is about the
/// 360/361dp regression, not density on other widths) and tracked
/// separately as **issue #190**.
const _financeTwoColumnMinWidth = 330.0;

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

  /// Reloads the dashboard — the pull-to-refresh handler and the error card's
  /// retry, which are the same request. Only the dashboard: the profile is a
  /// name and an admin flag, and reloading it would add a seventh request and
  /// another failure mode to the gesture.
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
    } else {
      // Same 24-hour rendering as the `LastLoadedLabel` this repeats aloud.
      SemanticsService.announce(
        loc.lastUpdatedAt(DateFormat('HH:mm').format(lastLoadedAt)),
        direction,
      );
    }
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
              FilledButton(
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

  /// A snapshot tile the user is allowed to hide. One builder for all four
  /// maskable tiles in both dashboard branches (eight call sites), so the
  /// masking wiring cannot be right in one branch and missing in the other.
  Widget _maskableTile({
    required Key tileKey,
    required AppLocalizations loc,
    required PrivacyMaskItem item,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final mask = widget.privacyMaskController;
    return _SnapshotTile(
      tileKey: tileKey,
      label: label,
      value: value,
      onTap: onTap,
      maskItem: item,
      isHidden: mask.isHidden(item),
      onToggleMask: () => unawaited(mask.toggle(item)),
      maskedValue: loc.homeMaskedValue,
      hiddenSemanticLabel: loc.homeValueHidden,
      hideLabel: loc.homeMaskHide(label),
      showLabel: loc.homeMaskShow(label),
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
    // a user who has records that they have none. It gets the same placeholder
    // as `loading` below, because that is exactly what it is.
    if (dashboard == null) {
      return Column(
        children: [
          _DashboardSection(
            sectionKey: const Key('health-dashboard-section'),
            openKey: const Key('health-tile'),
            title: loc.spaceHealth,
            openLabel: loc.homeOpenHealth,
            onOpen: _openHealth,
            twoColumnMinWidth: _healthTwoColumnMinWidth,
            children: [
              _maskableTile(
                tileKey: const Key('home-latest-weight'),
                loc: loc,
                item: PrivacyMaskItem.latestWeight,
                label: loc.homeLatestWeight,
                value: loc.homeNoData,
                onTap: _openVitals,
              ),
              _SnapshotTile(
                tileKey: const Key('home-food-dictionary'),
                label: loc.homeFoodPortionTool,
                actionLabel: loc.homeFoodPortionButton,
                onTap: _openFoodDictionary,
              ),
              _SnapshotTile(
                tileKey: const Key('home-latest-blood-pressure'),
                label: loc.homeLatestBloodPressure,
                value: loc.homeNoData,
                onTap: _openVitals,
              ),
              _SnapshotTile(
                tileKey: const Key('home-menstrual-prediction'),
                label: loc.homeMenstrualPrediction,
                value: loc.homeNoData,
                onTap: _openMenstrual,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _DashboardSection(
            sectionKey: const Key('finance-dashboard-section'),
            openKey: const Key('finance-tile'),
            title: loc.spaceFinance,
            openLabel: loc.homeOpenFinance,
            onOpen: _openFinance,
            twoColumnMinWidth: _financeTwoColumnMinWidth,
            children: [
              // The destination is part of the tuple, not a shared `_openFinance`
              // for the whole loop: this placeholder block is the state a
              // cold-start user actually taps, so it has to send each tile to
              // the same tab the loaded block does.
              // The maskable item is part of the tuple for the same reason the
              // destination is: 分帳總覽 prints money too but is deliberately
              // NOT maskable, so a shared value for the whole loop would give
              // it an eye.
              for (final entry
                  in <(Key, String, void Function(), PrivacyMaskItem?)>[
                (
                  const Key('home-budget'),
                  loc.homeBudget,
                  _openFinance,
                  PrivacyMaskItem.budget,
                ),
                (
                  const Key('home-net-worth'),
                  loc.homeNetWorth,
                  () => _openFinanceTab(FinanceTab.networth),
                  PrivacyMaskItem.netWorth,
                ),
                (
                  const Key('home-total-liabilities'),
                  loc.homeTotalLiabilities,
                  () => _openFinanceTab(FinanceTab.networth),
                  PrivacyMaskItem.totalLiabilities,
                ),
                (
                  const Key('home-split-overview'),
                  loc.homeSplitOverview,
                  () => _openFinanceTab(FinanceTab.split),
                  null,
                ),
              ])
                if (entry.$4 case final item?)
                  _maskableTile(
                    tileKey: entry.$1,
                    loc: loc,
                    item: item,
                    label: entry.$2,
                    value: loc.homeNoData,
                    onTap: entry.$3,
                  )
                else
                  _SnapshotTile(
                    tileKey: entry.$1,
                    label: entry.$2,
                    value: loc.homeNoData,
                    onTap: entry.$3,
                  ),
            ],
          ),
        ],
      );
    }
    // Both placeholders are gated on `data == null`, i.e. on there being
    // nothing to show — never on the status alone. A pull-to-refresh sets
    // `loading` and then possibly `error` with the previous figures still
    // held, and swapping the whole dashboard for a spinner (which also
    // shrinks the scrollable under the user's finger mid-gesture) or for the
    // "couldn't load" card would throw away data that is still perfectly
    // displayable. A failed reload keeps the figures and marks them stale
    // below instead.
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
    return Column(
      children: [
        _DashboardSection(
          sectionKey: const Key('health-dashboard-section'),
          openKey: const Key('health-tile'),
          title: loc.spaceHealth,
          openLabel: loc.homeOpenHealth,
          onOpen: _openHealth,
          twoColumnMinWidth: _healthTwoColumnMinWidth,
          children: [
            _maskableTile(
              tileKey: const Key('home-latest-weight'),
              loc: loc,
              item: PrivacyMaskItem.latestWeight,
              label: loc.homeLatestWeight,
              value: data.weightGoal.currentWeightKg == null
                  ? loc.homeNoData
                  : loc.homeWeightValue(
                      _compactNumber(data.weightGoal.currentWeightKg!),
                    ),
              onTap: _openVitals,
            ),
            _SnapshotTile(
              tileKey: const Key('home-food-dictionary'),
              label: loc.homeFoodPortionTool,
              actionLabel: loc.homeFoodPortionButton,
              onTap: _openFoodDictionary,
            ),
            _SnapshotTile(
              tileKey: const Key('home-latest-blood-pressure'),
              label: loc.homeLatestBloodPressure,
              value: data.bloodPressure == null
                  ? loc.homeNoData
                  : '${_compactNumber(data.bloodPressure!.systolic)} / '
                        '${_compactNumber(data.bloodPressure!.diastolic)}',
              onTap: _openVitals,
            ),
            _SnapshotTile(
              tileKey: const Key('home-menstrual-prediction'),
              label: loc.homeMenstrualPrediction,
              value: _menstrualValue(context, loc, data.menstrualStatus),
              onTap: _openMenstrual,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _DashboardSection(
          sectionKey: const Key('finance-dashboard-section'),
          openKey: const Key('finance-tile'),
          title: loc.spaceFinance,
          openLabel: loc.homeOpenFinance,
          onOpen: _openFinance,
          twoColumnMinWidth: _financeTwoColumnMinWidth,
          children: [
            _maskableTile(
              tileKey: const Key('home-budget'),
              loc: loc,
              item: PrivacyMaskItem.budget,
              label: loc.homeBudget,
              value: data.overallBudget == null
                  ? loc.homeNoData
                  : loc.homeBudgetRemaining(
                      formatMinorUnitsForDisplay(
                        data.overallBudget!.remaining,
                        defaultCurrency,
                      ),
                    ),
              onTap: _openFinance,
            ),
            _maskableTile(
              tileKey: const Key('home-net-worth'),
              loc: loc,
              item: PrivacyMaskItem.netWorth,
              label: loc.homeNetWorth,
              value: formatNetMinorUnitsForDisplay(
                data.netWorth.netWorth,
                defaultCurrency,
              ),
              onTap: () => _openFinanceTab(FinanceTab.networth),
            ),
            _maskableTile(
              tileKey: const Key('home-total-liabilities'),
              loc: loc,
              item: PrivacyMaskItem.totalLiabilities,
              label: loc.homeTotalLiabilities,
              value: formatMinorUnitsForDisplay(
                data.netWorth.totalLiability,
                defaultCurrency,
              ),
              onTap: () => _openFinanceTab(FinanceTab.networth),
            ),
            _SnapshotTile(
              tileKey: const Key('home-split-overview'),
              label: loc.homeSplitOverview,
              value: _splitValue(loc, data),
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
        MaterialLocalizations.of(
          context,
        ).formatShortDate(status.predictedNextStart!),
      );
    case NextPeriodState.today:
      return loc.homeMenstrualToday;
    case NextPeriodState.overdue:
      return loc.homeMenstrualOverdue(status.days!);
  }
}

String _splitValue(AppLocalizations loc, HomeDashboardData data) {
  var receivable = 0;
  var payable = 0;
  for (final person in data.splitBalances) {
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
  /// single column. Caller-supplied (not a shared file-level constant) so
  /// each call site names which threshold it wants — see
  /// `_healthTwoColumnMinWidth`/`_financeTwoColumnMinWidth`.
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
  final String? actionLabel;
  final VoidCallback onTap;

  /// Non-null on the tiles the user is allowed to hide — and the only thing
  /// that puts an eye on a tile.
  final PrivacyMaskItem? maskItem;
  final bool isHidden;
  final VoidCallback? onToggleMask;

  /// Already-localized strings. The tile never looks up [AppLocalizations]
  /// itself, matching every other string it is handed.
  final String maskedValue;
  final String hiddenSemanticLabel;
  final String hideLabel;
  final String showLabel;

  const _SnapshotTile({
    required this.tileKey,
    required this.label,
    this.value,
    this.actionLabel,
    required this.onTap,
    this.maskItem,
    this.isHidden = false,
    this.onToggleMask,
    this.maskedValue = '',
    this.hiddenSemanticLabel = '',
    this.hideLabel = '',
    this.showLabel = '',
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
        constraints: const BoxConstraints(minHeight: 110),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
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
              ],
            ),
            const SizedBox(height: 10),
            if (actionLabel != null)
              Text(actionLabel!, style: theme.textTheme.labelLarge)
            else if (isHidden)
              // A screen reader hears "Hidden", not four bullet characters
              // read out one by one — and, more importantly, never the figure
              // itself, which is still in the widget tree of a naive
              // implementation that only repaints.
              Semantics(
                label: hiddenSemanticLabel,
                child: ExcludeSemantics(
                  child: Text(maskedValue, style: theme.textTheme.titleMedium),
                ),
              )
            else
              Text(value ?? '', style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
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
