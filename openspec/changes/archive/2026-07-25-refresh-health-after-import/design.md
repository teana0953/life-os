# Design — refresh the health screens after a chaodays import

## Problem

After running a chaodays import the 總覽 (overview) still shows the pre-import data;
the user has to restart the app to see it. Root cause: `HealthScaffold._load()` — which
loads all twelve health controllers (overview cards, today, trackers, trends, calendar)
— runs **only once, in `initState`**. `/import/chaodays` is a **sibling top-level route**
pushed on top of `/health`, so returning from it never rebuilds the scaffold's state, and
nothing tells the already-loaded controllers their data is stale. There is no
pull-to-refresh or any other reload path in the app today.

## Decision

Introduce a tiny shared **data-revision signal** that write flows bump and the health
shell listens to:

- `lib/shared/data_revision.dart`: `class DataRevision extends ChangeNotifier { int
  get revision; void bump(); }` — a counter + `notifyListeners()`.
- `ChaodaysImportController` takes a `DataRevision` and bumps it when an import run
  ends **having written anything** — i.e. at least one type reached success. Bumping on
  partial success matters: a run that fails midway (e.g. chaodays goes away after weight
  and diet succeeded) has still changed lifeos data.
- `HealthScaffold` listens to the `DataRevision`; when the revision changes it re-runs
  `_load()` (its existing all-controllers load). Constructed in `main.dart` and passed
  to both, so neither context depends on the other's controller — both depend only on
  `shared/`, matching the repo's `shared/theme`, `shared/i18n` precedent.

Why a shared signal rather than the alternatives:

- **`context.push` return value** — unreliable here: this is a web/PWA where the browser
  back button (and a deep-link refresh) bypasses a `pop(result)`, a class of bug this
  repo has already been bitten by (go_router nested-routes fix, #70/#71).
- **Reload on every route re-entry** (RouteAware) — reloads far more often than needed
  and adds route-observer plumbing.
- **Let the import screen call the health controllers directly** — would inject twelve
  controllers into the import context and couple the two contexts.

The signal is deliberately generic but is wired for exactly one producer (the chaodays
import) and one consumer (the health shell) — no speculative fan-out.

## UI/UX

- The user runs an import, goes back to 總覽, and sees the imported data **without
  restarting** — that is the entire visible change. No new screens, controls, or copy.
- **Reload must not blank the overview.** Each controller's `load()` resets its status
  to `loading`. Two overview cards already tolerate that by keeping their content while
  reloading (`HealthCalendarCard` renders its skeleton only when `loading && calendar ==
  null`; `TrendCard` likewise on `range == null`), but two do not: `GoalCard` collapses
  to a short spinner card whenever `status == loading`, and `CareTodaySummaryCard`
  renders `SizedBox.shrink()` for any non-loaded status — so a refresh would make the top
  of 總覽 vanish and the layout jump. Fix those two cards to follow the same
  keep-content-while-reloading condition as the other two (a one-condition change each,
  not a silent-load path through twelve controllers). A first-ever load still shows the
  loading state, because there is no content to keep.
- The refresh happens while the import screen is still in front (the scaffold is alive
  underneath), so by the time the user navigates back the data is typically already
  updated.

## Behavior

- Import fully succeeds → revision bumps once → health shell reloads once.
- Import fails partway with ≥1 type imported → still bumps (data did change).
- No type completes successfully (e.g. wrong credentials, the first type fails) → no
  bump, no pointless reload. The predicate is "at least one type reached success", not
  "rows were written": re-running an already-imported range succeeds with everything
  skipped and still refreshes, which is harmless and keeps the rule derivable from the
  controller's per-type state.
- The bump happens once per import run, not per type, so the shell reloads once. It is
  emitted from a `try/finally` around the per-type loop that is placed **after** the
  "already importing" re-entrancy guard — wrapping the whole method would make a
  swallowed concurrent call bump again off the in-flight run's successes.
- **Reloads coalesce, they are not dropped.** A bump arriving while a `_load()` is in
  flight must schedule one more load after it finishes (a `_loading` flag plus a
  `_reloadPending` flag), never be ignored: the in-flight load may have issued its
  requests before the import wrote, so dropping the bump would leave exactly the stale
  overview this change fixes. Coalescing also keeps two `_load()` runs from overlapping —
  the twelve controllers are not re-entrancy-safe and concurrent runs could land out of
  order and pin stale data. Any state touched after the awaited load must respect
  `mounted`.
- Nothing else in the app listens to the revision, so no other screen changes behavior.

## Scope

Frontend only: the shared `DataRevision`, the import controller's bump, the health
shell's listen-and-reload (coalescing), the two overview cards' keep-content-while-
reloading fix, `main.dart` wiring, and tests. No backend change, no new
copy, no l10n. Gate = `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test`.

## Testing

- `DataRevision.bump()` increments and notifies.
- Import controller bumps once on a fully successful run; bumps on a partially
  successful run; does **not** bump when nothing was imported.
- `HealthScaffold` re-runs its load when the revision changes (widget test: fake
  controllers record a second load after a bump), and does not reload on an unrelated
  rebuild.
