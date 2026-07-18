# Design: add-health-diet

## Context

The backend diet API is live and stable (dictionary with `base_grams`, entries
with `quantity`/`grams`/`eaten_at`, per-day targets, eaten-at ordering). This is
the Flutter front end for it. The app is Clean Architecture / DDD, context-first
(`lib/contexts/<ctx>/{domain,application,infrastructure,presentation}`), with
`ChangeNotifier` controllers, `Http*Repository` adapters authed by Firebase
id-token, a Chiikawa pastel Material 3 theme, and `gen_l10n` i18n (en + zh-Hant).
The UX/UI was reviewed and settled: three screens plus a quantity card.

## Goals / Non-Goals

**Goals**
- A working diet front end reached from the home "健康" tile: today's log,
  logging (dictionary + quantity/grams + eaten-at + snacks), daily target.
- Instant portion preview in the quantity card without a round-trip.
- Reuse the existing theme, mascot, and i18n patterns; add only the category
  colors the diet UI needs.

**Non-Goals**
- No photo logging, water/bowel/exercise/period, or auto-computed targets.
- No offline cache/optimistic UI; screens fetch on load like the profile.
- No backend change — consume the existing API.

## Decisions

### D1 — A `health` context mirroring `contexts/user`

Same four layers. Ports in `domain/`, use cases in `application/`,
`Http*Repository` in `infrastructure/`, screens + `ChangeNotifier` controllers in
`presentation/`. `main.dart` wires concrete adapters (manual DI), as today.

### D2 — Portion preview is a pure front-end domain helper; the backend stays authoritative

The quantity card must show "主食 6 = 4 × 1.5" as the user types, before saving.
So `domain/` carries a pure preview helper mirroring the backend rule: portions
and nutrients × quantity, and `grams ÷ base_grams → quantity` (guarding null
`base_grams` and non-positive input). On save, the app sends `quantity` **or**
`grams` (mutually exclusive) to the backend, which recomputes and stores the
authoritative values; the day view then renders whatever the backend returns.
The preview never becomes the source of truth — it only mirrors the formula for
immediate feedback.

### D3 — HTTP adapters mirror `HttpProfileRepository`

Each repository is an `Http*Repository` taking `baseUrl` + `http.Client`, calling
the backend with `Authorization: Bearer <idToken>`, decoding JSON into domain
entities, and throwing **typed** errors (a `DietError` enum family), never
localized strings — the owning screen maps them to copy in `build()`, per the
i18n rule. `401` surfaces the same re-auth exit as the profile flow. Endpoints:
`GET/POST /api/food-items(+/:id/favorite,/favorites)`, `POST/GET/DELETE
/api/diet-entries`, `GET/PUT /api/daily-target`.

### D4 — A diet shell with bottom navigation, pushed from the home tile

Tapping the home "健康" tile pushes a `DietShellScreen` holding a bottom
`NavigationBar` with Today · Dictionary · Target (Settings stays the existing
gear/route). Each tab is its own screen + controller; the shell owns the token
load (like `_AuthenticatedHome`) and passes it down. Logging opens from the
Today FAB / a dictionary row as a screen or bottom sheet that hosts the quantity
card.

### D5 — Category colors are new theme tokens, not hard-coded in screens

The four food-group colors (staple / meat / fruit / veg) are the only new visual
element. Per the design-system rule (tokens in `app_colors.dart`, screens read
the theme), add four `Color` tokens for light + dark to `app_colors.dart` and
expose them via a small `ThemeExtension` (`DietCategoryColors`) registered in
`app_theme.dart`, so screens read `Theme.of(context).extension<DietCategoryColors>()`
rather than hard-coding. Values derive from the pastel palette: staple = Usagi
yellow, meat = blush pink, fruit = peach/coral, veg = sage.

### D6 — Home tile becomes a real entry point; user id removed

`home_screen.dart`'s "健康" grid tile navigates to `DietShellScreen`; the other
tiles stay placeholders. The profile card drops the `profile.id` row (internal
id), keeping email + signed-in state. Existing home widget tests updated.

## Risks / Trade-offs

- **Preview vs backend divergence** (rounding, e.g. 0.66) → the day view always
  re-renders from backend values after save, so any tiny preview rounding never
  persists; the preview is display-only.
- **Bottom-sheet vs full screen for logging** → start with whichever the widget
  tests can drive cleanly (a pushed screen), keep the quantity card a separate
  widget so it can move into a sheet later without logic changes.
- **ARB churn** → add all diet keys to `app_en.arb` (template) + `app_zh_Hant.arb`
  up front and regenerate `gen_l10n` once, to avoid piecemeal regen.

## Open Questions

- Meal set: fixed early/lunch/dinner + free snack label matches the backend's
  free-text `meal`; the UI offers the three standard meals plus "add snack".
  Revisit if fully custom meal names are wanted.
