## Why

On the web (both an installed PWA and a plain mobile browser tab), the system/
browser back button leaves the app too early: from a pushed tracker screen, two
backs minimize/close the app instead of returning to the "your spaces" grid, and
the deeper you push the earlier you fall out ("each extra level exits one level
sooner").

Root cause: the app runs Navigator 1.0 (`MaterialApp(home:)` + imperative
`Navigator.push`). On the web this uses Flutter's **`SingleEntryBrowserHistory`**
— the whole app occupies a single browser-history entry, so imperative pushes do
NOT each create a browser-history entry. The number of back presses the framework
can intercept is fixed and does not scale with Navigator depth, so the back button
exhausts the real browser history before the Navigator stack is emptied. There is
no app-logic bug (no `pushReplacement`/`PopScope`/nested `Navigator`); it is purely
the web history integration.

## What Changes

- Adopt the **Router API via `go_router`**, which switches the web engine to
  `MultiEntriesBrowserHistory` — one browser-history entry per route — so the
  browser/system back button maps 1:1 to route pops and always returns to the grid
  before it can leave the app.
- `App` builds a `GoRouter` (capturing the already-injected controllers/use cases
  in its route builders — no DI rework) and renders `MaterialApp.router`. The
  existing auth `StreamBuilder` is replaced by a go_router `redirect` +
  `refreshListenable`.
- Full-screen transitions become `context.push`/`go`; screens that returned a value
  via `Navigator.pop(result)` (food search → portion, daily target) use
  `context.push<T>` + `context.pop(result)`. `showDialog`-based flows (calendar
  day-pick, amount entry, confirm dialogs) are unchanged — modals need no history.
- Bottom-nav tabs inside `HealthScaffold` stay internal `IndexedStack` state (tab
  switches are not history entries, matching native tab behavior).

Frontend-only. No visual/UX change other than the back button now behaving
correctly on the web.

## Capabilities

### Added Capabilities

- `web-navigation-history`: on the web, each pushed screen is a distinct browser-
  history entry, so the browser/system back button returns through the screens in
  order and only leaves the app from the base route.
