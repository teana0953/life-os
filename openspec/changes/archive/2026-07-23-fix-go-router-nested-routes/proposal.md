## Why

Adopting go_router (#70) fixed the "back exits the app too early" bug but
introduced a new one: on the web, pressing the browser/system back button from a
deep diet screen (food search / daily target) jumped straight to the "your
spaces" grid instead of returning one level.

Root cause: #70 used **flat top-level routes** (`/health`, `/health/diet/target`,
…) and carried the already-built screen in `extra`. A web browser back / refresh
reconstructs the page stack **from the URL**; with flat routes that rebuilds only
the leaf page (a single-page stack), so a pop collapses to `/`. And `extra` is a
per-navigation value that a URL-driven rebuild does not have, so the intermediate
pages had nothing to render. (Confirmed with a probe: `go('/health/diet/target')`
builds 1 page with flat routes, 3 with nested.)

## What Changes

- **Nested routes**: `/health` → `diet` → `target` / `food-search`, plus
  `/health/:name` for the other trackers. The URL hierarchy now implies the full
  stack, so a URL-driven rebuild recreates every ancestor and back steps up one
  level.
- **Router builds screens from injected controllers** (not `extra`), so a
  URL-driven rebuild can reconstruct them. `AuthRouterNotifier` resolves and holds
  the id-token (awaited before it notifies), so the builders have it synchronously.
- Only genuine per-navigation args stay in `extra`: food search's `(meal, day)`
  and the target's `day` (the diet screen may be browsing a past day). A rebuild
  with no `extra` redirects to the diet day.
- Call sites simplified to push a path only (`context.push('/health')`, etc.).
  `HomeScreen` drops the ~17 controller params it only forwarded (now dead);
  `_AuthenticatedHome` and the record hub shrink accordingly.
- `showDialog` / bottom-sheet pops are unchanged (modals need no history).

Frontend-only. No visual change — the browser/system back button now returns
through the screens in order.

## Capabilities

### Modified Capabilities

- `web-navigation-history`: pushed screens are nested routes built from injected
  dependencies, so a URL-driven (browser back / refresh) stack rebuild recreates
  the full ancestor chain rather than collapsing to the base.
