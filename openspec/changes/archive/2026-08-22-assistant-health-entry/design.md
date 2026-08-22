## Context

See proposal.md — Why. Design-relevant current state:

- `AssistantChatContext` (`lib/contexts/assistant/presentation/assistant_chat_context.dart`)
  is finance-shaped throughout: `fromQuery` returns `null` unless
  `ctx == 'finance'`, the only period field is `month` (`^\d{4}-(0[1-9]|1[0-2])$`),
  and `label()` joins `loc.spaceFinance` with a finance tab name and a
  `monthYearLabel`. Its class doc states the invariant this change must not
  break: `label()` is the **only** place the context becomes text, because that
  one string is both painted in the transcript's context row and prepended into
  the first outgoing message (the backend body is `{messages}` only).
- The finance entry is `FinanceScaffold._openAssistant` + the
  `finance-assistant-button` `TextButton.icon` in the app bar, whose in-code
  comments record two decisions worth copying verbatim in shape: labelled rather
  than icon-only (tooltips need hover/long-press and never appear on the
  phone/PWA), and a `ConstrainedBox(maxWidth: 96)` + ellipsis so the label, not
  the title, absorbs a long translation at a large text scale.
- `FinanceTab` (`lib/shared/routing/finance_tab.dart`) exists precisely so the
  writer and the reader of `?tab=` cannot drift; its doc says the slugs are
  deliberately the same wire strings `/assistant` uses.
- `HealthScaffold` has **no** tab vocabulary: it tracks `int _index` and orders
  the `IndexedStack`/`NavigationBar` by hand (0 總覽, 1 記錄, 2 趨勢, 3 更多).
  It has a `_todayString(DateTime)` helper and an injected `clock` (default
  `DateTime.now`), and `_scheduleLoad()` is its batched whole-screen reload.
- The empty state (`AssistantScreen._transcript`) keys its hint on
  `chatContext?.month == null` and hard-codes the three finance chips.
- Health access is opt-in: `GeminiKeyController.healthEnabled` defaults to
  `false`, `clear()` (sign-out) resets it to `false`, and the settings page is
  the only place it can be turned on. The assistant reads it at send time and
  passes it as a header; with it off the backend exposes no health tools at
  all. The assistant screen's only existing pointer at settings is the
  `assistant-setup` block, which serves the **no-key** state alone.

## Goals / Non-Goals

**Goals:**
- One vocabulary for health tab slugs, shared by the writer (health shell) and
  the reader (`fromQuery`).
- Health's day handled as a first-class period alongside finance's month, with
  the same "drop field by field, never echo" and "never claim a view no screen
  showed" discipline.
- Guards that can actually go red — see Decisions D6.

**Non-Goals:**
- Refactoring `HealthScaffold._index` into an enum-driven `IndexedStack`. The
  new enum is introduced for the URL vocabulary only; the widget keeps its
  integer index.
- Deep-linking `/health?tab=…`. `HealthTab.location` is deliberately not added:
  nothing reads it, and an unused URL builder is a second naming scheme waiting
  to drift.
- Anything about the assistant's request body, prompt, or tool wiring.

## Decisions

### D1 — A `HealthTab` enum in `lib/shared/routing/`, not two copies of the slugs

Chosen: a small `enum HealthTab { overview('overview'), record('record'),
trends('trends'), more('more') }` in `lib/shared/routing/health_tab.dart`,
carrying `slug` and `fromSlug(String?)`, with **declaration order pinned to the
nav-bar / `IndexedStack` order** so `HealthTab.values[_index]` is correct — the
exact shape `FinanceScaffold._openAssistant` already uses.

Alternatives rejected:
- *Inline `switch (_index)` in the shell + a private `_healthTabs` set in
  `fromQuery`.* Two copies of the same four strings, in two files that never
  import each other. The failure mode is silent (a renamed slug parses to
  `null`, the tab quietly disappears from the context line, nothing goes red) —
  which is the failure `finance_tab.dart`'s own doc was written about.
- *Reusing `FinanceTab`.* The tab sets differ and 記錄/趨勢/更多 have no finance
  counterpart.

Consequence: a `test/shared/routing/health_tab_test.dart` mirroring
`finance_tab_test.dart` pins order and indices, so a reorder cannot happen by
accident.

### D2 — `day` is a new field, not `month` reused

`AssistantChatContext` gains `final String? day` (`YYYY-MM-DD`) beside `month`,
plus the module itself. `fromQuery` accepts `ctx=finance` (month path, unchanged)
and `ctx=health` (day path); anything else still returns `null`.

Reusing `month` for a day would force `label()` to guess which format it holds
from the string's length — a display-vs-data split of exactly the kind the class
doc exists to prevent. Two nullable fields, each with one owner module, keep the
`label()` switch total and readable.

Representation of the module: an explicit field on the class (e.g.
`AssistantContextSpace.finance | .health`), not "month != null means finance".
Deriving the module from which period happens to be set makes 健康趨勢 (a health
context with no day) indistinguishable from 財務分帳 (a finance context with no
month), and `label()` would name the wrong space.

### D3 — The day the health shell sends is the shell's today, from the injected `clock`

`_openAssistant` in `HealthScaffold` sends `_todayString(widget.clock())` for
總覽, and no day for 記錄/趨勢/更多. 總覽 is the shell's today-anchored view —
it pre-loads the day-keyed trackers for today and its cards (today's care
summary, the record calendar) are about that day; the diet screen's own day
selector belongs to a pushed screen that is not part of this shell and is not
what the app bar is showing.

**記錄 sends no day** (superseding an earlier draft of this decision that
grouped it with 總覽): the 記錄 tab's body is a hub of buttons and shows no
date anywhere on screen, so 「健康 記錄 2026年8月22日」 would describe a view
the user never saw — exactly what D4 below forbids.

Using the injected `clock` rather than `DateTime.now()` directly is what makes
the day assertable in a widget test at all. This is the change's one date-bearing
seam, and it straddles a timezone boundary in both directions: the local
midnight the shell computes and the day string the assistant then renders. Per
the repo's standing rule, every date-touching test in this change is re-run under
`TZ=UTC` (see D6).

### D4 — Reduction rules live in `fromQuery`, expressed as two separate checks

Per field: an unknown tab → `null`; a `day` that is not a real calendar date →
`null`. **The day check is `tryParseDayString`, not a shape regex.** A
`^\d{4}-\d{2}-\d{2}$` regex accepts `2026-02-31` and `0000-00-00`, and
`DateTime`'s constructor silently rolls those over to a wrong-but-plausible date
that the context line would then state as fact. `tryParseDayString`
(`lib/shared/date/day_format.dart`) already does the round-trip check that
rejects them; this repo has been bitten by "shape regex is not date validation"
before.

Cross-field: `day` is dropped for `record`/`trends`/`more` exactly as `month`
is dropped for `split` today — same rule, same reason (the context row must
never describe a view no screen ever rendered). 總覽 is the only health tab
that paints a date, so `overview` is the only slug that keeps the day.

Note the asymmetry that follows and is intended: `ctx=health` with an unknown tab
still yields a context ("健康"), because the module itself was stated. Only an
unknown `ctx` yields `null`.

### D5 — `label()` renders the day through `mediumDateLabel`

The month goes through `monthYearLabel` so the context line spells a month the
way every other month header in the app does; the day gets the same treatment via
`mediumDateLabel` ("2026年8月22日" / "Aug 22, 2026"). A raw `YYYY-MM-DD` in the
context row would be the one place in the app that prints a wire string at the
user. `label()` stays the single composition point — the transcript row and the
first-message prefix both call it, unchanged.

Health tab names reuse the strings the nav bar already shows
(`dashboardTitle` / `healthTabRecord` / `trendCardTitle` / `dietTabMore`) so the
context line names the tab with the same word the user just tapped.

### D6 — Guards that can go red

Three standing lessons from this repo apply directly, and each is an acceptance
condition, not advice:

1. **Never assert a string against its own source.** `find.text(
   lookupAppLocalizations(en).assistantExampleRemaining)` compares a string with
   itself and can never fail — 443 such assertions were found in this repo. Every
   assertion on a user-visible string in this change spells the expected literal
   out (`find.text('Started from: Health Overview Aug 22, 2026')`).
2. **Every user-visible string gets its own mutation.** The chip set converged to
   one `Wrap` means a guard can pass while following only the first chip. Each of
   the three new health chips, the health hint, the health-access-off line, and
   the context line must individually be provable red by changing only that one
   ARB value. Note that `flutter test` alone does **not** regenerate
   `lib/l10n/generated/` from a mutated ARB — run `flutter gen-l10n` between the
   edit and the test run, or the mutation is not actually in the build.
3. **Re-verify under `TZ=UTC`.** The machine is UTC+8, CI is UTC; a day guard
   that passes locally can be a day off in CI and vice versa. Every test file
   touching the day is run twice.

Two mutations are named explicitly as the acceptance check for the cross-field
rules, because a guard that only proves the happy path is the shape this repo
keeps regrowing:
- Deleting the day-drop for any one of `record`/`trends`/`more` must turn a
  test red — in particular, narrowing the rule back to `trends`/`more` only
  must fail the `record` case.
- Swapping `tryParseDayString` for a shape regex must turn a test red
  (`2026-02-31`).

### D7 — The empty-state hint follows the module, and its anchor check widens

`AssistantScreen` currently picks the "name a month if it matters" hint on
`chatContext?.month == null`. Left as is, a health entry carrying a day would
still be told to name a month, and every health entry would be offered a hint
about spending, budgets and split balances above three health chips.

So: the hint is selected by module first (a new `assistantEmptyHintHealth` /
`assistantEmptyHintHealthNoDay` pair beside the existing finance pair), and the
"unanchored" branch keys on *no period at all* rather than on `month == null`.
This is inside the change's blast radius rather than adjacent cleanup: the same
`if` that selects the chips selects the hint, and shipping health chips under the
finance hint is a visible defect on the screen this change adds.

### D8 — A health entry with health access OFF gets an exit, not three dead chips

`healthEnabled` is off by default and sign-out clears it, so the first-run path
this change creates — 健康 → 問助手 → tap 「今天剩下的份量還可以吃什麼?」 — is
also the path most likely to hit an assistant that is sent no health data at
all. Nothing on the screen said so, and the one place that could turn it on is
the settings page, which the assistant only points at from its **no-key**
setup state.

Chosen: when the entry is a health one and `healthEnabled` is false, the empty
state renders a `assistant-health-access-off` block — one line of copy plus a
`FilledButton` doing `context.push('/settings')`, the same shape as the
existing `assistant-setup` exit — **in place of** the three health chips.

Alternatives rejected:
- *Notice above the chips.* Every one of the three chips asks for data the
  assistant cannot see, so leaving them tappable puts three dead ends next to
  the way out.
- *Changing the switch's default, or offering an inline toggle here.* Consent
  belongs to the settings page that owns it; this change adds a signpost, not
  a second place to grant it (proposal.md — Not in scope).

Consequence: the flag must be read at build time off the listened-to
`GeminiKeyController` (this screen already listens for the key), so returning
from settings flips the empty state without a remount — the same requirement
the setup state has, and a guard says so.

## Risks / Trade-offs

- **A fourth nullable field makes `label()`'s switch wider** → keep the switch
  total over the module enum, so adding a third module later fails to compile
  rather than silently rendering an empty view string.
- **`HealthTab.values[_index]` couples an enum's declaration order to a widget's
  hard-coded `IndexedStack` order across two files** → the order-pinning test
  (D1) plus a widget test that opens the assistant from each of the four tabs and
  asserts the slug; a reorder breaks both.
- **The day is the shell's today, computed at tap time, while the assistant panel
  is non-opaque and stays open across midnight** → accepted. The context line
  states the view *at entry*, which is what "Started from" means; the finance
  month has the same property.
- **The health-access-off notice is one more thing the empty state can show**
  → its guard asserts the literal copy, that the three chips are gone, that the
  button reaches `/settings`, and that a finance entry with the same flag off
  shows nothing; the flag-on case is asserted separately so a notice wired to
  the wrong polarity cannot pass both.
- **New ARB keys are added to three files by hand** → `flutter gen-l10n` /
  `flutter analyze` fails on a key missing from the template, and the
  three-locale ARB parity check in the test suite covers the rest.
- **`ctx=health` reaching a build without the health tools deployed** → not a
  risk: the backend tools shipped (life-os-backend PR #124) and the context is
  descriptive text only, carrying no capability of its own.

## Migration Plan

None. Additive: no stored data, no URL that previously worked stops working
(`ctx=finance` parses exactly as before), and no backend change. Rollback is
reverting the commit.
