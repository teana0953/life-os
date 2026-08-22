/// The 健康 shell's four destinations, as a single vocabulary shared by the
/// writer and the reader of `?tab=`.
///
/// Lives beside [FinanceTab] for the same reason that one does: the shell
/// composes `/assistant?ctx=health&tab=<slug>` and
/// `AssistantChatContext.fromQuery` parses it back, and two hand-written
/// copies of these four strings would drift silently — a renamed slug parses
/// to `null`, the tab quietly disappears from the assistant's context line,
/// and nothing goes red.
///
/// **Declaration order is the nav-bar / `IndexedStack` order** of
/// `HealthScaffold`, which still tracks its selection as an `int`:
/// `HealthTab.values[_index]` is what turns that index into a slug.
/// `health_tab_test.dart` pins both the order and the indices so a reorder
/// cannot happen by accident.
///
/// Deliberately no `location` getter: nothing deep-links `/health?tab=…`
/// today, and an unused URL builder is a second naming scheme waiting to
/// drift.
enum HealthTab {
  overview('overview'),
  record('record'),
  trends('trends'),
  more('more');

  const HealthTab(this.slug);

  /// The tab's wire name, in `/assistant?ctx=health&tab=<slug>`.
  final String slug;

  /// Parses a `?tab=` value. Exact and case-sensitive: `'Record'`, `'2'`,
  /// `''` and `null` are all unknown and answered with `null`.
  ///
  /// Returns nullable rather than defaulting to [overview] on purpose — a
  /// context line that named 總覽 because the slug was unreadable would be
  /// describing a view the user was never on.
  static HealthTab? fromSlug(String? slug) {
    for (final tab in values) {
      if (tab.slug == slug) return tab;
    }
    return null;
  }
}
