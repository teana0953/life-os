# CLAUDE.md — life-os

Architecture conventions for this repo. Read before adding or modifying any
frontend code (human or AI agent). Mirrors `life-os-backend/CLAUDE.md`.

## AI development: graphflow is mandatory (flow choice is the per-request judgment)

**Every AI-assisted development task in this repo runs through the graphflow
workflow engine — `/graphflow:graphflow`, plugin version v0.2.1 or later.**
Running the work by hand instead of through graphflow is not an option. The
only per-request judgment left is **which flow**: `light` or `full`.

```
/graphflow:graphflow run <graph> --flow light   # small, low-risk
/graphflow:graphflow run <graph> --flow full    # everything else
```

`--flow light` (added in v0.2.0) prunes the plan-approval gate and the
secondary review legs; script verification, at least one code review, and the
final ship gate stay in **both** flows. Light trims process overhead, never
the quality floor.

- **`--flow light`** — single file, low risk, no interface/UI change: typo
  fixes, doc edits, renames, mechanical tweaks, one-line bugfixes.
- **`--flow full`** — everything else: feature development, non-trivial
  bugfixes, refactors, anything spanning multiple files/contexts, anything
  touching a public interface or the UI.
- **Unsure → ask the user.** Do not silently pick light to save time.

State the chosen flow plus a one-line reason **before touching code**.

**The flow judgment is per user request, never per session.** An earlier
choice does not carry over. Re-judge from scratch — and restate it — every
time one of these happens:

- a new request arrives, however short the phrasing
- the scope outgrows what the last judgment covered (more files, new
  behaviour, a design question appears)
- work resumes after review, or a commit is appended to an
  already-reviewed branch/PR
- the task type changes (doc tweak → feature, one-liner → refactor)

Never reason like this:

- "this session already decided the flow"
- "same task continues, so the earlier choice stands"
- "the user didn't ask for graphflow this time"
- "this one is too small for graphflow" — too small means `--flow light`,
  not skipping the engine

User silence is not permission to skip. Making the call and stating it is
yours to do, once per request.

Reference: <https://github.com/teana0953/graphflow>. If the installed plugin
is older than v0.2.1, `--flow` is unavailable — update it (`/plugin update
graphflow`) before starting.

## Architecture: Clean Architecture + DDD (hexagonal naming, context-first structure)

```
LoginScreen/HomeScreen (presentation, driving) ──▶ use cases (application, inbound port)
                                                       └─ AuthRepository / ProfileRepository port
                                                            ◀─ FirebaseAuthRepository / HttpProfileRepository
                                                               (driven adapters) ──▶ Firebase Auth / backend API
```

### Dependency rule

- `domain` imports nothing from outer layers. It defines entities and
  **ports** (interfaces) that outer layers implement or call.
- `application` depends only on `domain` and ports. It contains use cases
  (inbound ports) that orchestrate domain logic via injected repository
  ports.
- `infrastructure` implements ports (**driven adapters**, e.g.
  `FirebaseAuthRepository`, `HttpProfileRepository`).
- `presentation` (screens + `ChangeNotifier` controllers) drives the
  application from the outside (**driving adapter**) by calling use cases.
- Dependencies always point inward:
  `presentation → application → domain ← infrastructure`. Nothing in
  `domain` or `application` may import from `infrastructure` or
  `presentation`.
- `main.dart` is the only place that wires concrete adapters into use cases
  and controllers via manual dependency injection — no DI framework.

### Bounded contexts (context-first structure)

The codebase is organized **by context first, by layer second**:

```
lib/
  contexts/
    <context>/
      domain/            # entities, repository ports (interfaces)
      application/       # use cases (inbound ports), depend only on domain
      infrastructure/    # driven adapters implementing domain ports
      presentation/       # screens + ChangeNotifier controllers (driving adapter)
  shared/
    config.dart           # cross-context technical config (API_BASE_URL, ...)
  app.dart                 # MaterialApp + auth-state routing
  main.dart                # composition root (manual DI) + runApp
```

Each product area (auth, user, and future ones) becomes its own context
under `lib/contexts/`, copying the `contexts/user/` layout. Keep the
tactical pattern set lightweight: entity + repository port + thin use case
is enough until a context needs more — don't add value objects/domain
events speculatively (YAGNI).

### Naming conventions

- Driven adapters are named **`<TechnologyPrefix><PortName>`** (e.g.
  `FirebaseAuthRepository` implements the `AuthRepository` port,
  `HttpProfileRepository` implements the `ProfileRepository` port). Do not
  use an `~Adapter` suffix.
- Ports (interfaces) live in `domain/` and are named after the capability
  they expose (e.g. `AuthRepository`, not `IAuthRepository`).

### Adding a new context

1. Copy the `lib/contexts/user/` folder layout (`domain/`, `application/`,
   `infrastructure/`, `presentation/`) for the new context name.
2. Define entities and repository ports in `domain/`.
3. Define use cases in `application/`, depending only on `domain`.
4. Implement ports in `infrastructure/` (e.g. a `Http<X>Repository`).
5. Add screens/controllers under `presentation/` and wire them from
   `main.dart`.

## Testing strategy

- **domain / application layers**: plain Dart unit tests (`flutter test`).
  Use cases are tested with a fake repository implementing the port — no
  Firebase/network involved.
- **infrastructure layer**: unit tests inject a mock `http.Client` /ports;
  never hit real Firebase or the real backend.
- **presentation layer**: widget tests inject fake repositories via the
  controllers/use cases — never call `Firebase.initializeApp` or perform
  real HTTP calls.
- Run everything with `flutter test`. Lint/type-check with `flutter
  analyze`.

## Error handling

- Sign-in rejected by the auth service → `LoginScreen` shows a user-facing
  error message without exposing internal error detail.
- `/api/me` returns non-200 → `HomeScreen` shows an error state (not a
  crash); `401` specifically surfaces a "sign in again" exit rather than a
  dead end.
- Network exceptions are caught and surfaced the same way — never crash the
  UI.

## Firebase configuration

- `lib/firebase_options.dart` is committed (not gitignored). Firebase web
  config (`apiKey`, `appId`, ...) is a public client identifier, not a
  secret. Run `flutterfire configure` to overwrite the placeholder values
  checked in here with your project's real values.
- `android/app/google-services.json` and
  `ios/Runner/GoogleService-Info.plist` remain gitignored (web-first;
  add them only when Android/iOS builds are needed).

## Design system

A Chiikawa-inspired cute pastel design language, applied via a single
Material 3 theme (light + dark, following `ThemeMode.system`). See
`openspec/changes/add-design-system/design.md` for the full token
rationale.

- **Tokens**: `lib/shared/theme/app_colors.dart` — raw color constants
  (Hachiware blue primary, blush pink / Usagi yellow accents, cream
  ground, soft-brown ink/outline, sage/honey/error semantic colors).
  Never reference these hex values directly from a screen; go through
  the theme.
- **Theme**: `lib/shared/theme/app_theme.dart` — `lightTheme` and
  `darkTheme` (`ThemeData`, `useMaterial3: true`) with an explicit
  `ColorScheme` and component themes (`CardThemeData`,
  `InputDecorationTheme`, `FilledButtonThemeData`,
  `OutlinedButtonThemeData`, `TextTheme`). Use the `*ThemeData` types,
  not the deprecated non-`Data` aliases (e.g. `CardTheme`) — Flutter
  3.35's `ThemeData` constructor expects `*Data` and the old aliases
  trip `flutter analyze`.
- **Toy-ledge shadow**: the soft, downward-offset "step" shadow under
  cards/buttons is *not* `elevation` (which is symmetric). Use
  `ledgeShadow(outlineColor)` from `app_theme.dart` inside a
  `BoxDecoration.boxShadow` on a wrapping `Container`.
- **Mascot**: `lib/shared/widgets/mascot.dart` — an original
  `CustomPaint` round face (not a reproduction of any existing
  character), themed from `Theme.of(context).colorScheme`. Sized via
  the `size` constructor parameter.
- **Design-language note**: this is a change of visual tone, not just a
  token swap. The original design spec
  (`openspec/changes/archive/2026-07-17-add-design-system/design.md`,
  now archived) named an OFL **rounded** sans (Baloo 2 or Quicksand) as
  the font carrier of the "Chiikawa-inspired cute pastel" language.
  Issue #194 supersedes that one line: Noto Sans is a neutral humanist
  grotesque, not rounded. The cute/pastel tone is still carried by the
  rest of the system unchanged — the 20–22px corner radius, the 2px
  outline border, the toy-ledge shadow, the pastel token palette and the
  mascot — the font's role in it is deliberately retired, not an
  oversight.
- **Font**: Noto Sans (SIL OFL 1.1), bundled offline at
  `assets/fonts/NotoSans-Subset-VariableFont.ttf` and registered as the
  `NotoSans` family in `pubspec.yaml` (license: `assets/fonts/OFL.txt`).
  Bundled rather than fetched at runtime so it works offline and in
  tests. Applied via `ThemeData.fontFamily`, not per-widget. The same
  family name is repeated in `web/index.html`'s pre-Flutter splash CSS —
  change both together, or the splash silently falls back to a system
  font (unverified whether Flutter web's CanvasKit/skwasm renderers
  actually expose the bundled text font as a CSS `@font-face` the splash
  can pick up — confirm in a browser via
  `Array.from(document.fonts).map(f => f.family)` before relying on the
  stated mechanism).
  - **The bundled file is a subset**, not the upstream variable font:
    232,860 B raw / 149,373 B gzip, against 2,049,096 B / 1,192,786 B for
    the full one. Flutter web tree-shakes *icon* fonts only, never text
    fonts, so the whole file ships — the subset is what keeps this a
    +83 KB (gzip) change over the Quicksand it replaced (124,824 B /
    66,113 B).
  - **Regenerate it with exactly this command** (source font:
    google/fonts `ofl/notosans/NotoSans[wdth,wght].ttf`), or nobody can
    reproduce the shipped file:

    ```
    python3 -m fontTools.subset NotoSans.ttf --unicodes="U+0000-00FF,U+0100-017F,U+2000-206F,U+2070-209F,U+20A0-20BF" --layout-features="*" --output-file=NotoSans-subset.ttf
    ```

    That is Latin-1 + Latin Extended-A (for names like Łukasz/Ćwik) +
    general punctuation + super/subscripts (needed for `vitalsSpo2Label`'s
    "SpO₂") + currency: 506 codepoints / 769 glyphs. **The upstream font
    has no arrow, math-operator or misc-symbol glyphs at all** (checked
    directly against its cmap) — the `→` used in `homeOpenHealth` /
    `settingsInstallIosHint` / `splitScheduleAdjusted` /
    `splitActivityAmountChange` is drawn by the platform fallback font,
    not this one, regardless of unicode range requested. Both `fvar` axes
    survive (wght 100–900 default 400, wdth 62.5–100 default 100); the
    `weight: 700` registration in `pubspec.yaml` selects that axis on
    platforms that render variable fonts by weight, but this has **not**
    been confirmed on-device or in a web build — a `FontLoader` in a
    widget test only ever renders the default (400) instance, so nothing
    in this repo's test suite can tell 700 apart from 400 (see caveat 1 in
    `real_font_metrics_test.dart`). There is **no** CJK, Greek, Cyrillic
    or Vietnamese in it — Chinese has always come from the platform
    fallback font and still does.
  - **Widget tests cannot see the font family.** `flutter_test` paints one
    `fontSize`-sized square per glyph whatever the family is, so every
    layout guard in `test/` is byte-identical under any font. A green
    `flutter test` means the logic still works, never that the layout
    still fits. `test/shared/theme/real_font_metrics_test.dart` is the one
    file that loads the real `.ttf` (via `FontLoader`) before pumping —
    extend it, not the ordinary guards, when a change is about metrics.
- **Screens**: derive all colors, shapes, and text styles from
  `Theme.of(context)` — never hard-code a `Color(...)` or use
  `Colors.*` in presentation code.
- **Responsive breakpoints**: phone `< 600`, tablet `600–899`, desktop
  `>= 900` (logical pixels, via `LayoutBuilder`/`MediaQuery`). Sign-in
  centers its card with a `maxWidth` of ~420 that shrinks on narrower
  viewports instead of stretching edge-to-edge. Home centers its
  content in a `maxWidth` of 960 and the "Your spaces" grid uses
  `SliverGridDelegateWithFixedCrossAxisCount` with 2 columns on phone,
  3 on tablet, 4 on desktop.
- **New screens**: use `TextField` (not `TextFormField`) for consistency
  with existing widget tests that assert on `TextField.enabled`; wrap
  primary content in a themed `Container`/`Card` with the standard
  20–22px corner radius and 2px outline border; use `FilledButton` for
  primary actions (pill shape + ledge shadow come from the theme) and
  `OutlinedButton` for secondary actions. Test responsive layout with
  `tester.binding.setSurfaceSize(...)`, and always
  `addTearDown(() => tester.binding.setSurfaceSize(null))` to avoid
  leaking the size into later tests.
- **Numeric input empty-zero convention**: for portion/quantity numeric
  inputs, when the value is `0` the field shows an **empty string plus a
  `hintText: '0'`**, never a literal `'0'` — so the user can type straight
  away without deleting the 0 first. This applies both to inline fields and
  to tap-to-type edit dialogs. Reference implementations:
  `portion_form_fields.dart` (`value == 0 ? '' : …` with `hintText: '0'`)
  and `portion_stepper.dart`'s `_PortionEditDialog`. Match this for any new
  numeric portion/quantity input.

## i18n

The app is localized in **English** (fallback/default) and **Traditional
Chinese** (`zh-Hant`) via Flutter's official `gen_l10n` toolchain. See
`openspec/changes/add-i18n/design.md` for the full rationale.

- **ARB files**: `lib/l10n/app_en.arb` is the template (every key + English
  text + a `description` for translators); `lib/l10n/app_zh_Hant.arb` holds
  the Traditional Chinese translations. `lib/l10n/app_zh.arb` is a
  gen_l10n-required fallback-base file for the `zh` language (script-coded
  locales need a plain-language-code ARB to exist); it is not a supported
  app locale on its own — see `supportedLocales` in `lib/app.dart`.
- **Generated output**: `l10n.yaml` uses `output-dir: lib/l10n/generated`
  (non-synthetic — the synthetic-package mode is deprecated/removed as of
  Flutter 3.35). `lib/l10n/generated/*.dart` is generated by `flutter
  gen-l10n` (also run automatically by `flutter test`/`flutter build`) and
  **is checked into git** like any other source file — regenerate it after
  editing an ARB file and commit the diff.
- **Adding a new language**: add `lib/l10n/app_<code>.arb` (and a plain
  `app_<lang>.arb` fallback if the new locale has a script/country code),
  translate every key from `app_en.arb`, then add the `Locale` to
  `supportedLocales` in `lib/app.dart`. `zh-Hant` uses
  `Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')` — **not**
  `Locale('zh', 'Hant')`, which treats `'Hant'` as a country code and never
  matches.
- **No hard-coded strings**: every user-facing string in `presentation/`
  comes from `AppLocalizations.of(context)!.<key>` — never a string
  literal. Add new copy to `app_en.arb` (with a `description`) and
  `app_zh_Hant.arb` first.
- **Error copy lives in presentation, not infrastructure/domain**:
  `infrastructure`/`domain` throw or expose a **typed error** (e.g.
  `AuthFailureCode`, `ProfileError`) — never a localized message string.
  `ChangeNotifier` controllers (`LoginController`, `HomeController`) hold
  that typed error, not text, because they have no `BuildContext` and so
  cannot look up `AppLocalizations`. The owning screen maps the error to a
  localized string in `build()`.
- **Language switching**: `LocaleController` (`lib/shared/i18n/`) holds the
  user's chosen `Locale?` (`null` = follow the system) and persists it via
  `shared_preferences`; `lib/app.dart` rebuilds `MaterialApp` from it via
  `AnimatedBuilder` and falls back to English when the system locale isn't
  supported. `LanguageSwitcher` (`lib/shared/i18n/language_switcher.dart`)
  is the reusable chip control, shown pre-auth on the sign-in screen (a
  logged-out user has no settings page to reach), that shows the current
  language and opens a menu with three options — follow system, English,
  and Traditional Chinese — through the controller. Post-auth, language
  selection lives in the settings page instead (see "Settings / Theme"
  below) as inline option rows sharing the same `LocaleController`, not the
  chip widget itself.
- **Testing**: widget tests wrap the widget under test in a `MaterialApp`
  with `AppLocalizations.localizationsDelegates`/`supportedLocales` and a
  fixed `locale` (see `test/support/l10n_test_app.dart`'s `l10nTestApp`
  helper) instead of asserting on hard-coded English literals — assert
  against `lookupAppLocalizations(locale).someKey` so tests stay correct if
  copy changes. The home screen's time-of-day greeting takes an injectable
  `clock` (`DateTime Function()`, default `DateTime.now`) so tests can pin
  the time instead of depending on the real clock.

## Settings / Theme

A dedicated settings page (reachable only once authenticated) centralizes
theme, language, and sign-out. See
`openspec/changes/add-settings/design.md` for the full rationale.

- **ThemeController**: `lib/shared/theme/theme_controller.dart` — mirrors
  `LocaleController`. A `ChangeNotifier` holding a `ThemeMode` (`system`,
  `light`, or `dark`; defaults to `system`), persisted via
  `shared_preferences` (`ThemeMode.name`/`ThemeMode.values.byName` round-trip
  the enum to/from the stored string, so unlike `LocaleController` it needs
  no manual string-to-enum switch). `setThemeMode` updates the field,
  notifies listeners, then persists.
- **Wiring**: `lib/app.dart`'s `MaterialApp.themeMode` follows
  `themeController.themeMode`, rebuilt via
  `AnimatedBuilder(animation: Listenable.merge([localeController,
  themeController]))` alongside the existing locale wiring.
  `lib/main.dart` constructs one `ThemeController` (and one `LocaleController`)
  from the same `SharedPreferences` instance and passes it down.
- **DI path**: `SettingsScreen` needs `ThemeController` + `LocaleController`
  + the auth context's `SignOut` use case. These are threaded through
  `App` → `_AuthenticatedHome` → `HomeScreen` as required constructor
  parameters (not pulled out of `HomeController`, which only exposes
  `signOut()` bound to its own internal `SignOut` instance) — `main.dart`
  builds a single `SignOut` and passes it to both `HomeController` and
  `App`/`SettingsScreen`. `HomeScreen`'s settings gear icon (loaded state
  only, `Key('settings-icon-button')`) does
  `Navigator.push(MaterialPageRoute(builder: (_) => SettingsScreen(...)))`.
- **SettingsScreen**: `lib/contexts/settings/presentation/settings_screen.dart`
  — a thin, presentation-only context (no `domain`/`application`/
  `infrastructure`; it orchestrates existing shared controllers and the
  auth context's use case, per the "keep the tactical pattern set
  lightweight" rule above). Three sections — Theme, Language, Sign out —
  each rendered as a titled, rounded/outlined card
  (`_SettingsSection`) containing selectable rows built with the private
  `_OptionRow<T>` widget (a `ListTile` with a filled/outline circle icon
  indicating the current selection). **Not** `RadioListTile`: its
  `groupValue`/`onChanged` are deprecated as of Flutter 3.35 (trips
  `flutter analyze`) in favor of a `RadioGroup` ancestor API this app
  doesn't otherwise need. Adding a new setting item: add rows/a new
  `_SettingsSection` in `settings_screen.dart`, add any new ARB strings
  first (see i18n rules above), and keep it presentation-only — new
  business logic belongs in its owning context's `application`/`domain`,
  not here.
- **Sign-out-and-close**: `SettingsScreen`'s sign-out button awaits
  `signOut()`, then pops itself via `Navigator.canPop`/`pop` if it was
  pushed on top of `HomeScreen`. This is required, not cosmetic: the auth
  state stream flips `App`'s `home:` to `LoginScreen` on sign-out, but
  `MaterialApp`'s root `Navigator` doesn't auto-discard routes pushed on
  top of that root — without the pop, a pushed `SettingsScreen` would stay
  on screen over a now-stale `HomeScreen` after sign-out.
- **Recovery exits stay on `HomeScreen`, not settings**: the home screen's
  `error` state (`Key('sign-out-button')`) and `needsReauth` state
  (`Key('sign-in-again-button')`) keep their own direct sign-out buttons —
  these are unreachable-otherwise recovery exits (profile failed to load /
  401), and `SettingsScreen` requires a loaded profile to reach. Only the
  `loaded` state's sign-out (and, pre-this-change, its language chip) moved
  into settings.
