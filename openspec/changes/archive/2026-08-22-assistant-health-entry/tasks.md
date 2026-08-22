> All of this is one change unit: `AssistantChatContext`, the health shell entry,
> the chip/hint selection and the three ARBs compile and test only together.
> Do not split it across isolated worktrees.

## 1. Health tab vocabulary

- [x] 1.1 Add `lib/shared/routing/health_tab.dart` — `enum HealthTab { overview('overview'), record('record'), trends('trends'), more('more') }` with `slug` and `fromSlug(String?)` (nullable, exact, case-sensitive), plus the doc stating that declaration order IS the `NavigationBar`/`IndexedStack` order; verify `flutter analyze` is clean.
- [x] 1.2 Add `test/shared/routing/health_tab_test.dart` mirroring `finance_tab_test.dart`: pin each value's index and slug with hard-coded literals, and assert `fromSlug` rejects `'Record'`, `'2'`, `''` and `null`; verify the file passes and that renaming any one slug in `health_tab.dart` turns it red.

## 2. Entered-context model

- [x] 2.1 In `lib/contexts/assistant/presentation/assistant_chat_context.dart`, add an explicit module field (finance | health) and a `String? day` beside `month`, keeping `label()` the only place text is composed (design D2); verify `flutter analyze` is clean and the existing `assistant_chat_context_test.dart` still passes for every `ctx=finance` case.
- [x] 2.2 Extend `fromQuery` to accept `ctx=health`: unknown `ctx` still returns `null`; tab validated against `HealthTab.fromSlug`; `day` validated with `tryParseDayString` (NOT a shape regex — design D4); verify with tests covering a good day, `banana`, `2026-02-31`, `0000-00-00` and an unknown tab, each asserting the dropped value appears nowhere in `label()`'s output.
- [x] 2.3 Apply the cross-field rule: `day` dropped for `record`/`trends`/`more`, kept only for `overview`; `month` still dropped for finance `split`; verify with a test per branch, and prove the guard real by narrowing the rule back to `trends`/`more` only and seeing the `record` cases go red.
- [x] 2.4 Extend `label()` with the health branch — `loc.spaceHealth`, the tab name from the nav bar's own strings (`dashboardTitle` / `healthTabRecord` / `trendCardTitle` / `dietTabMore`), and the day via `mediumDateLabel` (design D5); verify with assertions spelling out the full expected literal (e.g. `'Started from: Health Overview Aug 22, 2026'`) — never `lookupAppLocalizations(en).<key>`, which compares a string with itself.
- [x] 2.5 Re-run every test file touched in section 2 under `TZ=UTC flutter test <files>` and confirm the same results as the local (UTC+8) run.

## 3. Health shell entry point

- [x] 3.1 Add `_openAssistant()` to `lib/contexts/health/presentation/health_scaffold.dart`: build `/assistant` with `ctx=health`, `tab=HealthTab.values[_index].slug`, and `day=_todayString(widget.clock())` for `overview` only; `await context.push(...)`, then `if (!mounted) return;` and `_scheduleLoad()`; verify `flutter analyze` is clean.
- [x] 3.2 Add the app-bar action next to the title — a `TextButton.icon` keyed `health-assistant-button` with `Icon(Icons.smart_toy_outlined)` and `label: ConstrainedBox(maxWidth: 96, child: Text(loc.assistantOpenButton, overflow: TextOverflow.ellipsis))`, carrying the two comments explaining why it is labelled rather than an `IconButton` and why the width is capped; verify the button is present on all four tabs in a widget test.
- [x] 3.3 Add health-shell widget tests (`test/contexts/health/presentation/health_scaffold_test.dart`) that tap the button from each of the four tabs with an injected fixed `clock` and assert the exact pushed location string, including that `record`/`trends`/`more` carry no `day`; verify a mutation that widens `showsDay` back to `overview || record` turns the `record` case red.
- [x] 3.4 Add a test that the shell reloads on return and does not reload when disposed before the return; verify by asserting the reload count with a fake repository.
- [x] 3.5 Re-run sections 3's test files under `TZ=UTC flutter test <files>` and confirm the day in the asserted location is the same relative to the injected clock.

## 4. Strings

- [x] 4.1 Add to `lib/l10n/app_en.arb` (template, with `@` descriptions) and then `app_zh_Hant.arb` and `app_zh.arb`: three health example prompts — one of them asking what can still be eaten given the day's remaining portions — plus the health empty-state hint and its no-day variant (design D7) and the health-access-off line (design D8); verify `flutter gen-l10n` succeeds and `test/l10n/arb_parity_test.dart` passes.
- [x] 4.2 Verify each new string is individually mutable to red: change one ARB value at a time, **run `flutter gen-l10n`** (`flutter test` alone does not regenerate `lib/l10n/generated/`, so the mutation would never reach the build), re-run the suite, confirm exactly the test asserting that string fails — repeat for all six new strings plus the health context line.

## 5. Assistant empty state

- [x] 5.1 In `lib/contexts/assistant/presentation/assistant_screen.dart`, select the three example chips by entered module — health chips (keys `assistant-example-*`, distinct from the finance keys) for `ctx=health`, finance chips otherwise (including no context at all); verify with a widget test per branch that asserts the three literal chip texts and that none of the other module's chips is present.
- [x] 5.2 Change the hint selection to key on the module first and on "no period at all" (neither `month` nor `day`) for the ask-for-a-period variant, replacing the current `chatContext?.month == null` check; verify with tests for health-overview-with-day, health-record and health-trends (no day), finance-with-month, finance-split and no-context.
- [x] 5.3 Assert the unchanged chip behaviour for a health chip: tapping fills the composer, leaves the caret at the end, focuses the composer, and sends nothing; verify by asserting the controller recorded zero sends.
- [x] 5.4 Add a routing test in `test/app_assistant_context_routing_test.dart` for `/assistant?ctx=health&tab=overview&day=…`: the context row renders the health line and the first sent message carries that same line as its prefix, character for character.

## 5b. Health access off — the empty state's way out

- [x] 5b.1 In `assistant_screen.dart`, when the entry is a health one and `widget.geminiKeyController.healthEnabled` is false, render an `assistant-health-access-off` block — the new copy plus a `FilledButton` keyed `assistant-health-access-off-settings-button` doing `context.push('/settings')` — **in place of** the three health chips (design D8); verify `flutter analyze` is clean.
- [x] 5b.2 Guard it in `test/contexts/assistant/presentation/assistant_screen_test.dart`: with the flag off, assert the **literal** copy (never `lookupAppLocalizations(en).<key>`), that all three health chip keys are absent, and that tapping the button lands on `/settings`; with the flag on, assert the block is absent and the chips are back; and assert a finance entry with the same flag off shows neither.
- [x] 5b.3 Guard the live flag: with the block on screen, call `setHealthEnabled(true)` on the same controller, pump, and assert the block is gone without remounting the screen — a build-time capture of the flag stays dead otherwise.
- [x] 5b.4 Prove the guards real by mutation, one at a time: replacing the condition with `false` must fail the off-state tests, and replacing it with `_isHealthEntry` alone must fail the flag-on tests.

## 6. Whole-change verification

- [x] 6.1 `flutter analyze` clean and `flutter test` fully green (look for `All tests passed!`, not merely the absence of red — a hung run prints neither).
- [x] 6.2 `TZ=UTC flutter test` for the whole suite, green.
- [x] 6.3 Manually confirm on a narrow phone-width device (or a width-constrained widget test at a large text scale) that the health app bar's title is not swallowed by the assistant label — the label ellipsizes instead.
