# Design

## Why go_router (not raw Navigator 2.0)

The fix requires `MultiEntriesBrowserHistory`, which the engine only selects when
the app drives navigation through the Router API. `go_router` is the lightest
standard way to adopt that API; a hand-rolled `RouterDelegate`/`RouteInformation
Parser` would be strictly more code for the same result.

## Route table

Each `push` becomes one browser-history entry.

```
/login                         (unauthenticated)
/register
/                              your-spaces grid (home)
/settings
/health                        HealthScaffold (bottom-nav tabs stay internal)
/health/water | vitals | bowel | exercise | menstrual | diet
/health/diet/target
/health/diet/food-search       returns a portion result
```

The `HealthScaffold` bottom-nav (總覽 / 記錄 / 趨勢 / 更多) remains an internal
`IndexedStack` + `setState`. Tab switches are deliberately NOT routes/history
entries — this matches native tab UX and keeps the change small; the bug was about
*pushed* screens, not tabs.

## Auth: redirect + refreshListenable

Replace the `home:` `StreamBuilder<bool>` with:

- `AuthRouterNotifier` — a `ChangeNotifier` subscribing to
  `AuthRepository.authStateChanges` (`Stream<bool>`), exposing
  `{loading, error, signedIn}` and calling `notifyListeners` on each change. Used
  as the `GoRouter.refreshListenable`.
- `GoRouter.redirect`:
  - `error` → `/auth-error` (the existing retry screen, now a route).
  - `loading` (auth not yet known) → `/splash` (the existing centered spinner).
  - signed out and not on `/login|/register` → `/login`.
  - signed in and on `/login|/register|/splash` → `/`.
  - otherwise no redirect.

`retry` re-subscribes the stream (as `_retryAuthStateChanges` did) via the
notifier.

## Dependency injection

`App` already receives every controller/use case. The `GoRouter` is built once in
`_AppState` (memoized in `initState`, or a `late final`) and its route `builder`
closures capture `widget.*`. No changes to `main.dart`'s composition root; DI stays
manual (no framework), per repo convention.

## Value-returning routes

`go_router`'s `context.push<T>()` completes with the value passed to
`context.pop(value)` on the pushed route.

- `food-search`: diet calls `context.push<(...)>('/health/diet/food-search',
  extra: <meal target args>)`; the search screen returns the picked portion via
  `context.pop(result)`. Args ride in `extra` (in-memory object; we do not need the
  route to be deep-linkable).
- `daily-target`: pushed via `context.push`; its existing `onSaved` callback is
  passed through `extra`; it closes with `context.pop`.
- `diet → today confirm` dialogs and the calendar day-picker stay `showDialog` +
  `Navigator.pop` (modals, unchanged).

## URL strategy

Keep the default hash strategy (no `usePathUrlStrategy`) to avoid touching web
server / base-href config; go_router fixes the history behavior regardless of hash
vs path. Clean path URLs can be a later, separate change.

## Test impact

- `app_test.dart`: rebuilt around the router (pump `App`, assert redirect to login
  when signed out / grid when signed in, and that a pushed route is a new entry).
- Screens asserting go_router navigation (`food_search`, `daily_target`,
  `register`, `home`, `settings`): wrap the unit under test in a minimal `GoRouter`
  so `context.push/pop` resolve. Add a regression test that pushing two routes then
  popping twice returns to the base (the behavior the bug violated), exercised at
  the widget level.
- The other ~122 single-screen tests are unaffected (their internal navigation is
  `showDialog`/`Navigator.pop`, still valid).
