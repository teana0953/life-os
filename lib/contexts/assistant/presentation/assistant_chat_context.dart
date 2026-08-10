import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';

/// What the user was looking at when they opened the assistant — carried in
/// `/assistant`'s query string (`ctx`/`tab`/`month`) so a web refresh
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
  /// One of `overview`/`transactions`/`networth`/`split`, or `null` when the
  /// query carried no recognizable tab.
  final String? tab;

  /// The viewed month as `YYYY-MM`, or `null` when the query carried no
  /// well-formed month (the split tab has no month at all).
  final String? month;

  const AssistantChatContext({this.tab, this.month});

  static const _tabs = {'overview', 'transactions', 'networth', 'split'};

  static final _monthPattern = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$');

  /// Parses `/assistant`'s query parameters. Returns `null` unless
  /// `ctx=finance` — no context row, no prefix. A garbage `tab` or `month`
  /// (hand-edited URL, stale bookmark) is *dropped field-by-field* rather
  /// than crashing or being echoed: a context line repeating `month=banana`
  /// to the model would be a fabricated view no screen ever showed.
  ///
  /// Cross-field, not just per-field: 分帳 has no month to show (no screen
  /// ever sends `tab=split&month=...`, see `FinanceScaffold._openAssistant`),
  /// so a hand-typed `tab=split&month=2025-11` still drops the month even
  /// though `2025-11` alone is well-formed — otherwise the row/wire would
  /// claim a "財務 分帳 2025-11" view no screen has ever shown.
  static AssistantChatContext? fromQuery(Map<String, String> query) {
    if (query['ctx'] != 'finance') return null;
    final tab = query['tab'];
    final month = query['month'];
    final resolvedTab = _tabs.contains(tab) ? tab : null;
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

  /// The one human/model-readable form, e.g. 「進入時檢視:財務 明細
  /// 2025年11月」. Painted in the transcript's context row and prepended to
  /// the first outgoing message — see the class doc for why both must call
  /// this. Takes a [BuildContext] (not just [AppLocalizations]) because the
  /// month is rendered through [monthYearLabel], the same locale-aware
  /// "2026年7月"/"Jul 2026" convention every other month header in the app
  /// uses — a raw `YYYY-MM` here would be the one place in the app that
  /// still spells it out.
  String label(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final tabLabel = switch (tab) {
      'overview' => loc.financeTabOverview,
      'transactions' => loc.financeTabTransactions,
      'networth' => loc.financeTabNetWorth,
      'split' => loc.financeTabSplit,
      _ => null,
    };
    // `month` is already regex-validated by `fromQuery` (`^\d{4}-(0[1-9]|
    // 1[0-2])$`), so the parse below cannot fail.
    final rawMonth = month;
    final monthLabel = rawMonth == null
        ? null
        : monthYearLabel(
            context,
            DateTime(
              int.parse(rawMonth.substring(0, 4)),
              int.parse(rawMonth.substring(5, 7)),
            ),
          );
    final view = [
      loc.spaceFinance,
      if (tabLabel != null) tabLabel,
      if (monthLabel != null) monthLabel,
    ].join(' ');
    return loc.assistantContextViewing(view);
  }
}
