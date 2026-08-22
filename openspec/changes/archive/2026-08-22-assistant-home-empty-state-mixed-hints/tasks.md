## 1. Copy

- [x] 1.1 Add the home/no-context hint string `assistantEmptyHintNoContextMixed`
      to `lib/l10n/app_en.arb` with an `@` description saying it is the entry
      with no module and must name both finance and health/diet; verify
      `flutter gen-l10n` (or `flutter pub get` + build) regenerates
      `AppLocalizations` with the getter present.
- [x] 1.2 Add the same key to `lib/l10n/app_zh.arb` and `lib/l10n/app_zh_Hant.arb`
      matching the tone of the shipped `assistantEmptyHintNoContext` /
      `assistantEmptyHintHealth` lines (finance clause + health-and-diet clause
      + the existing 「牽涉時間範圍請自己講清楚」 nudge); verify no
      untranslated-message warning for the new key and that
      `flutter analyze` is clean.

## 2. Empty state

- [x] 2.1 In `lib/contexts/assistant/presentation/assistant_screen.dart`,
      replace the `_isHealthEntry` two-way selector with one three-way selector
      (health entry / finance entry / home) used by **both** the hint and the
      chip list, keeping the health-entry and finance-entry arms byte-for-byte
      today's behaviour; verify the existing assistant screen and context tests
      still pass unchanged (`flutter test test/contexts/assistant/`).
- [x] 2.2 Make the home arm show `assistantEmptyHintNoContextMixed`; verify by
      widget test that opening with `chatContext == null` renders it.
- [x] 2.3 Make the home arm's chips follow `geminiKeyController.healthEnabled`:
      consent on → spend + log + remaining-portions; consent off → today's three
      finance chips; verify by widget test that the health chip is present in
      the first case and absent in the second.
- [x] 2.4 Confirm the health-access-off notice and its settings button remain
      scoped to a health entry (no such block on the home path); verify by
      widget test that opening with `chatContext == null` and health access off
      shows neither `assistant-health-access-off` nor its settings button.

## 3. Guards

- [x] 3.1 In `test/contexts/assistant/presentation/assistant_screen_test.dart`
      and `assistant_screen_context_test.dart`, update/extend the no-context
      guards so the two home cases are a pair differing only in `healthEnabled`,
      each asserting presence **and** absence; assert on literal expected text,
      never on a localization lookup compared to itself; verify
      `flutter test test/contexts/assistant/` passes.
- [x] 3.2 Mutation-check each user-visible string of the home state separately —
      each hint variant, each of the three chips in each of the two consent
      states, and the settings button — by deleting/replacing one at a time;
      verify each mutation turns the suite red and note which assertion caught
      it.
- [x] 3.3 Run the full suite plus `TZ=UTC flutter test` and `flutter analyze`;
      verify both are green.

## 4. Consent-off home state (after UI/UX review — the user's call)

- [x] 4.1 Add `assistantEmptyHintNoContextMixedConsentOff` to all three ARBs —
      same sentence as `assistantEmptyHintNoContextMixed` except the health
      clause is conditional ("turn on health access in settings and you can
      also…"), the zh ones keeping the two-example 「(例如「這個月」或「今天」)」
      nudge; the `en` `@` description must say what it is for and that it is
      used only on the home entry with the consent off. Verify `flutter
      gen-l10n` produces the getter and `flutter analyze` is clean.
- [x] 4.2 Make the home hint pick between the two variants on
      `geminiKeyController.healthEnabled`; verify by the consent-on/consent-off
      pair of widget tests that each renders its own literal string and not the
      other's.
- [x] 4.3 Add a low-emphasis `TextButton` keyed
      `home-assistant-enable-health-button`, labelled with its own key
      `assistantEnableHealthAccess` (en 'Turn on health access', zh 開啟健康存取)
      because it is read on its own three examples below the sentence it
      answers — `assistantGoToSettings` stays on the health entry's button and
      its `@` description names both uses; shown only on the home entry with
      the consent off, pushing `/settings`; verify by widget test that it is
      present with the consent off, absent with it on, that its literal label
      is asserted, and that tapping it lands on `/settings` — including at
      320dp × textScale 2.0, where it is the lowest element on screen, by
      `ensureVisible` + tap inside `expectNoLayoutErrors`.
- [x] 4.4 Keep the health entry's `assistant-health-access-off` notice off the
      home path; verify by widget test that neither it nor its button is found
      in the consent-off home state.
- [x] 4.5 Wrap the consent-dependent part of the home empty state (hint, chips,
      button) in `Semantics(liveRegion: true)`; verify by a widget test that
      walks the LIVE semantics tree (`semanticsOwner.rootSemanticsNode`, not
      `getSemantics`/`bySemanticsLabel`, which read a cache) for the single
      live-region node, asserts its label is the consent-off wording verbatim,
      then flips the consent on the mounted screen (`setHealthEnabled(true)` +
      pump) and asserts the hint, the example and that same node's label all
      swapped; and by mutation that both removing the wrapper and emptying its
      label (`explicitChildNodes: true`) turn that test red — a live region
      with no label announces nothing on web.
