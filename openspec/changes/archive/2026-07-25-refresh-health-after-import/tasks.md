# Tasks

## 1. Shared DataRevision (TDD)
- [x] `lib/shared/data_revision.dart`: `class DataRevision extends ChangeNotifier` with `int get revision` (starts 0) and `void bump()` (increments + `notifyListeners()`).
- [x] Test: `bump()` increments the revision and notifies listeners.

## 2. Import controller bumps on writes (TDD)
- [x] `ChaodaysImportController`: accept a `DataRevision` (constructor arg) and, when an import run ends, bump it exactly ONCE if at least one type reached `TypeStatus.success` — including runs that abort partway (authFailed/unavailable/needsReauth) after some types succeeded. No bump when no type succeeded. Emit it from a `try/finally` around the per-type loop placed **AFTER** the `if (status == ImportStatus.importing) return;` re-entrancy guard — wrapping the whole method body would let a swallowed concurrent call bump again off the in-flight run's successes.
- [x] Tests: bumps once on a fully successful run; bumps on a partial run (one type succeeded, then a failure aborts); does NOT bump when the first type fails with no type succeeding; bumps at most once per run; **a second concurrent `import()` swallowed by the re-entrancy guard does NOT bump**.

## 3. Health shell reloads on revision change (TDD)
- [x] `HealthScaffold`: accept the `DataRevision`, listen to it in `initState` (remove the listener in `dispose`), and re-run `_load()` when the revision changes.
- [x] **Coalesce, never drop:** keep a `_loading` flag and a `_reloadPending` flag — a bump arriving while a load is in flight sets `_reloadPending` and re-runs `_load()` ONCE after the current one finishes. Do NOT ignore such a bump: the in-flight load may have issued its requests before the import wrote, which would leave the stale overview this change exists to fix. Never run two `_load()`s concurrently (the twelve controllers are not re-entrancy-safe and could land out of order). Respect `mounted` for anything touched after the awaited load.
- [x] Widget test: after a bump, the fake controllers record a second `load` call; an unrelated rebuild does not reload; a bump during an in-flight load results in exactly one extra load afterwards (coalesced, not dropped and not doubled).

## 4. Overview cards must keep their content while reloading (TDD)
- [x] `GoalCard`: it currently collapses to a short spinner card whenever `status == loading`. Show the spinner only when there is nothing to show yet (no goal data held) and otherwise keep rendering the current content during a reload — matching `HealthCalendarCard` (`loading && calendar == null`) and `TrendCard` (`loading && range == null`).
- [x] `CareTodaySummaryCard`: it currently returns `SizedBox.shrink()` for any non-loaded status, so it disappears during a reload; keep showing the last loaded summary while reloading (still shrink when there has never been one).
- [x] Widget tests: each card keeps its previously loaded content when its controller goes back to `loading` with data still held, and still shows the empty/loading state on a first-ever load.

## 5. Wiring
- [x] `lib/main.dart`: construct one `DataRevision`; pass it to `ChaodaysImportController` and `HealthScaffold` (via `App`, following how the other controllers are threaded).
- [x] Update every construction site the new constructor args break — `ChaodaysImportController` in `test/app_test.dart`, `test/contexts/import/presentation/chaodays_import_controller_test.dart`, `test/contexts/import/presentation/chaodays_import_screen_test.dart` (2 sites); `HealthScaffold` wherever tests build it (find them all; analyze will flag).

## 6. Gate
- [x] `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test` green.
