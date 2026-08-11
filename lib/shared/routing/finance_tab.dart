/// The 財務 shell's four destinations, as a single vocabulary shared by the
/// three places that need to agree on them.
///
/// Lives here rather than in `contexts/finance/presentation` because it is not
/// finance's alone: `HomeScreen` (the *user* context) builds `/finance?tab=…`
/// links with it, `app.dart` parses the query parameter back, and
/// `FinanceScaffold` orders its `IndexedStack`/`NavigationBar` by it. Putting
/// it under finance would make `contexts/user/presentation` import
/// `contexts/finance/presentation` directly — a cross-context presentation
/// dependency. It sits next to `app_locations.dart` for the same reason that
/// file exists: URL vocabulary with more than one reader belongs in one place,
/// because the failure mode of two copies is silent (a link that opens the
/// wrong screen, with nothing to go red).
///
/// **Declaration order is the nav-bar / `IndexedStack` order.** Reordering
/// these values moves the tabs; `finance_tab_test.dart` pins both the order
/// and the indices so that cannot happen by accident.
///
/// The slugs are deliberately the same wire strings `/assistant` already uses
/// (`AssistantChatContext.fromQuery`), so there is exactly one naming scheme
/// for a finance tab across the whole app.
enum FinanceTab {
  overview('overview'),
  transactions('transactions'),
  networth('networth'),
  split('split');

  const FinanceTab(this.slug);

  /// The tab's wire name, in `/finance?tab=<slug>` and `/assistant?…&tab=<slug>`.
  final String slug;

  /// The query parameter carrying [slug] on `/finance`.
  static const queryParameter = 'tab';

  /// The finance shell's own location, without a tab.
  static const financeLocation = '/finance';

  /// Parses a `?tab=` value. Exact and case-sensitive: `'NetWorth'`, `'2'`,
  /// `''` and `null` are all unknown and answered with `null`.
  ///
  /// Returns nullable rather than defaulting to [overview] on purpose — the
  /// fallback belongs to the caller (the route builder), so this stays a
  /// parse that can be tested for what it *rejects*.
  static FinanceTab? fromSlug(String? slug) {
    for (final tab in values) {
      if (tab.slug == slug) return tab;
    }
    return null;
  }

  /// The deep link that opens the shell on this tab — the one place the URL
  /// is composed, so that today's only caller (the home tiles) and anything
  /// added later (a PWA shortcut, a pushed notification, a hand-typed
  /// address) cannot drift into two different shapes.
  ///
  /// One-way, on purpose: this is only ever *read* into
  /// `FinanceScaffold.initialTab`. The shell never writes the visible tab back
  /// to the router — see `FinanceScaffold._selectTab` for the measurements
  /// behind that.
  Uri get location => Uri(
    path: financeLocation,
    queryParameters: {queryParameter: slug},
  );
}
