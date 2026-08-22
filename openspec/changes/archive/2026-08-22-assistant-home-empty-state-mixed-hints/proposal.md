## Why

The assistant now answers health and diet questions too, but the empty state a
user meets when they open it from the **home grid** (no entry context at all)
still speaks only finance: the hint offers "spending, budgets or split
balances" and all three example chips are finance ones. The health half of the
assistant is invisible on the one entry point that belongs to no module
(issue #231).

## What Changes

- The no-context (home) empty-state hint SHALL name both what the assistant can
  answer about finance **and** what it can answer about health and diet, while
  keeping its existing "name a month if it matters" nudge.
- The no-context example chips SHALL follow the health-access consent
  (`GeminiKeyController.healthEnabled`): with consent granted the three chips
  are a **mix** of finance and health examples; with consent off they stay the
  three finance chips shipped today.
- No change to the finance-entry or health-entry empty states: their hints,
  chips, the health-access-off notice and its settings exit all keep today's
  behaviour exactly.
- No change to the consent itself — what it means, where it is stored, when it
  is cleared — nor to what is sent on the wire.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `assistant-entry-context`: the two empty-state requirements ("The empty state
  offers examples fitting the entered module" and "The empty-state hint matches
  the entered module") change for the **no-entry-module** case only — the hint
  gains a health half, and the chips become consent-dependent instead of
  unconditionally finance.

## Impact

- `lib/contexts/assistant/presentation/assistant_screen.dart` — the empty-state
  block: the hint selection and the chip list stop being a single
  `_isHealthEntry` two-way switch for the no-context case.
- `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`, `lib/l10n/app_zh_Hant.arb` — one
  new hint string for the home/no-context case (existing chip strings are
  reused; no new chip copy).
- `test/contexts/assistant/presentation/assistant_screen_test.dart`,
  `test/contexts/assistant/presentation/assistant_screen_context_test.dart` —
  the existing "no context offers the finance chips / finance hint" guards.
- No backend, API, routing or dependency impact.
