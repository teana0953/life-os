## Why

The AI assistant can now read health and diet records (health consent shipped in
`assistant-health-opt-in`; the backend's `list_favorite_foods` /
`list_recent_foods` / `search_foods` tools shipped in life-os-backend PR #124),
but the health module has no way to reach it. The only entry point is the
finance shell's app-bar button, which enters with `ctx=finance` — so a user
standing on 記錄 who wants to ask 「剩下的份量可以吃什麼」 must leave health,
go to finance, open the assistant there, and then type their way out of a
context that says they were looking at the ledger.

Issue #220: give the health module its own assistant entry, and teach the
entered-context vocabulary to describe a health view as precisely as it already
describes a finance one.

## What Changes

- The health shell's app bar gains a labelled assistant button (the finance
  shell's `TextButton.icon` shape, not a bare `IconButton` — a tooltip needs a
  hover or a long-press and never appears on the phone/PWA this app is used
  on). It pushes `/assistant?ctx=health&tab=<slug>`, adding
  `&day=YYYY-MM-DD` only from 總覽 — the one health tab that shows a date —
  and, on return, reloads the health screen behind it.
- `AssistantChatContext` stops being finance-only: `fromQuery` accepts
  `ctx=health` alongside `ctx=finance`, carrying the health tab and — for the
  one tab that has one — the viewed day. Health is day-keyed where finance is
  month-keyed, so a new `day` parameter joins `month`; both are dropped
  field-by-field when malformed, and `day` is dropped for the tabs that never
  show one (記錄/趨勢/更多), mirroring finance's existing `tab=split` rule.
  `label()` remains the only place a context string is composed.
- The assistant's empty-state example chips become context-dependent: entering
  from health offers three health questions (one of them asking what to eat
  with the remaining portions) instead of the three finance ones. Chip
  behaviour is unchanged — fill the composer and focus it, never send.
- The assistant's empty state gains a way out when a health entry arrives while
  health access is switched off: the three health chips are replaced by a line
  saying the assistant cannot read health or diet records yet and a button to
  settings. Health access is opt-in (`GeminiKeyController.healthEnabled`
  defaults to false and sign-out clears it), so the most-walked first-time
  path — 健康 → 問助手 → tap 「今天剩下的份量還可以吃什麼?」 — otherwise
  reaches an assistant sent no health data, with nothing on screen saying why
  and nowhere to go: the existing `assistant-setup` exit serves the no-key
  state only.
- New user-visible strings in all three ARBs (`app_zh_Hant.arb`, `app_zh.arb`,
  `app_en.arb`): the health tab names the context row needs, the three health
  example prompts, and the health-access-off line.

Not in scope: any change to the assistant's API calls, prompt, or tool wiring
(the backend already exposes the health tools); any change to what the health
consent switch *does* — its behaviour, its storage and the settings control
that owns it are untouched, and this change only adds a signpost to it from
the assistant's empty state; deep-linking `/health` by tab.

## Capabilities

### New Capabilities
- `assistant-entry-context`: how the assistant is entered from a module's
  screen, what the URL carries about the view the user came from, how a
  malformed or impossible URL is reduced, and how the entered context shapes
  the empty-state examples.

### Modified Capabilities
- `health-navigation`: the health shell's app bar gains the assistant entry
  point, which is navigation-level behaviour of that shell.

## Impact

- `lib/contexts/health/presentation/health_scaffold.dart` — app-bar action and
  the open-then-reload handler.
- `lib/contexts/assistant/presentation/assistant_chat_context.dart` — `ctx`,
  `tab` and the new `day` field; `label()` gains the health branch.
- `lib/contexts/assistant/presentation/assistant_screen.dart` — the empty-state
  chip set (and the empty-state hint's anchor check, which today keys off
  `month`), plus the health-access-off notice that takes the chips' place.
- `lib/shared/routing/` — the health tab slug vocabulary, so the writer (health
  shell) and the reader (`fromQuery`) cannot drift.
- `lib/l10n/app_zh_Hant.arb`, `lib/l10n/app_zh.arb`, `lib/l10n/app_en.arb`.
- Tests: `test/contexts/assistant/presentation/assistant_chat_context_test.dart`,
  `assistant_screen_context_test.dart`, `assistant_screen_test.dart`,
  `test/contexts/health/presentation/health_scaffold_test.dart`,
  `test/app_assistant_context_routing_test.dart`.
- No backend change; no API-call change.
