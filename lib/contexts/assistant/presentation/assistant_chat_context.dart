import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/routing/health_tab.dart';

/// The module the user came from. An explicit field rather than something
/// derived from which period happens to be set: 健康趨勢 (a health context with
/// no day) and 財務分帳 (a finance context with no month) are both
/// "tab, no period", and deriving the space from the period would make
/// [AssistantChatContext.label] name the wrong one.
enum AssistantContextSpace { finance, health }

/// What the user was looking at when they opened the assistant — carried in
/// `/assistant`'s query string (`ctx`/`tab`/`month`/`day`) so a web refresh
/// reconstructs it, parsed by [fromQuery], and rendered by [label].
///
/// **[label] is deliberately the only way to turn this into text.** The same
/// string is painted at the top of the transcript *and* prepended into the
/// first message's content (the backend body is `{messages}` only — there is
/// no context field, so the context can only travel inside content). Two
/// call sites, one function: if rendering and sending ever composed their
/// own strings, the screen would show A while the model reads B — the
/// display-vs-data split this repo keeps regrowing.
class AssistantChatContext {
  /// Which module's screen the user entered from — the one field that is
  /// never dropped, because an unrecognized `ctx` yields no context at all.
  final AssistantContextSpace space;

  /// The entering module's own tab slug — one of `FinanceTab`'s or
  /// [HealthTab]'s, depending on [space] — or `null` when the query carried
  /// no recognizable tab.
  final String? tab;

  /// The viewed month as `YYYY-MM` (finance only), or `null` when the query
  /// carried no well-formed month (the split tab has no month at all).
  final String? month;

  /// The viewed calendar day as `YYYY-MM-DD` (health only), or `null` when
  /// the query carried no real calendar day (記錄/趨勢/更多 show no date).
  final String? day;

  const AssistantChatContext({
    this.space = AssistantContextSpace.finance,
    this.tab,
    this.month,
    this.day,
  });

  static const _financeTabs = {
    'overview',
    'transactions',
    'networth',
    'split',
  };

  static final _monthPattern = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$');

  /// Parses `/assistant`'s query parameters. Returns `null` unless `ctx` names
  /// a module the app can enter from (`finance` or `health`) — no context row,
  /// no prefix. A garbage `tab`, `month` or `day` (hand-edited URL, stale
  /// bookmark) is *dropped field-by-field* rather than crashing or being
  /// echoed: a context line repeating `day=banana` to the model would be a
  /// fabricated view no screen ever showed.
  ///
  /// Cross-field, not just per-field: 分帳 has no month to show and
  /// 記錄/趨勢/更多 have no day (no screen ever sends them — see
  /// `FinanceScaffold`/`HealthScaffold._openAssistant`), so a hand-typed
  /// `tab=record&day=2026-08-22` still drops the day even though the day
  /// itself is a real date — otherwise the row/wire would claim a
  /// "健康 記錄 2026年8月22日" view no screen has ever shown.
  static AssistantChatContext? fromQuery(Map<String, String> query) {
    return switch (query['ctx']) {
      'finance' => _finance(query),
      'health' => _health(query),
      _ => null,
    };
  }

  static AssistantChatContext _finance(Map<String, String> query) {
    final tab = query['tab'];
    final month = query['month'];
    final resolvedTab = _financeTabs.contains(tab) ? tab : null;
    return AssistantChatContext(
      tab: resolvedTab,
      month:
          resolvedTab != 'split' &&
              month != null &&
              _monthPattern.hasMatch(month)
          ? month
          : null,
    );
  }

  static AssistantChatContext _health(Map<String, String> query) {
    final tab = HealthTab.fromSlug(query['tab']);
    final day = query['day'];
    // NOT a shape regex: `^\d{4}-\d{2}-\d{2}$` accepts `2026-02-31` and
    // `0000-00-00`, which `DateTime`'s constructor then silently rolls over
    // into a wrong-but-plausible date the context line would state as fact.
    // `tryParseDayString` round-trips against `dayString` and rejects those.
    final dayIsReal = day != null && tryParseDayString(day) != null;
    // 總覽 is the only health tab that paints a date. 記錄 is a hub of
    // buttons, and 趨勢/更多 are not day-keyed at all. An unreadable slug is
    // NOT in this set: the module was still stated, exactly as finance keeps
    // its month when the tab is unreadable.
    final tabShowsNoDay = tab != null && tab != HealthTab.overview;
    return AssistantChatContext(
      space: AssistantContextSpace.health,
      tab: tab?.slug,
      day: dayIsReal && !tabShowsNoDay ? day : null,
    );
  }

  /// The one human/model-readable form, e.g. 「進入時檢視:健康 記錄
  /// 2026年8月22日」. Painted in the transcript's context row and prepended to
  /// the first outgoing message — see the class doc for why both must call
  /// this. Takes a [BuildContext] (not just [AppLocalizations]) because the
  /// period is rendered through [monthYearLabel]/[mediumDateLabel], the same
  /// locale-aware convention every other date header in the app uses — a raw
  /// `YYYY-MM`/`YYYY-MM-DD` here would be the one place in the app that still
  /// spells it out.
  ///
  /// The tab names are the nav bars' own strings, so the line names the tab
  /// with the same word the user just tapped.
  String label(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    // Total over the enum on purpose: a third module later must fail to
    // compile here rather than silently render an empty view string.
    final (spaceLabel, tabLabel) = switch (space) {
      AssistantContextSpace.finance => (
        loc.spaceFinance,
        switch (tab) {
          'overview' => loc.financeTabOverview,
          'transactions' => loc.financeTabTransactions,
          'networth' => loc.financeTabNetWorth,
          'split' => loc.financeTabSplit,
          _ => null,
        },
      ),
      AssistantContextSpace.health => (
        loc.spaceHealth,
        switch (tab) {
          'overview' => loc.dashboardTitle,
          'record' => loc.healthTabRecord,
          'trends' => loc.trendCardTitle,
          'more' => loc.dietTabMore,
          _ => null,
        },
      ),
    };
    // `month` is already regex-validated by `fromQuery` (`^\d{4}-(0[1-9]|
    // 1[0-2])$`) and `day` round-trip-validated by `tryParseDayString`, so
    // neither parse below can fail.
    final rawMonth = month;
    final rawDay = day;
    final periodLabel = rawMonth != null
        ? monthYearLabel(
            context,
            DateTime(
              int.parse(rawMonth.substring(0, 4)),
              int.parse(rawMonth.substring(5, 7)),
            ),
          )
        : rawDay != null
        ? mediumDateLabel(context, parseDayString(rawDay))
        : null;
    final view = [
      spaceLabel,
      if (tabLabel != null) tabLabel,
      if (periodLabel != null) periodLabel,
    ].join(' ');
    return loc.assistantContextViewing(view);
  }
}
