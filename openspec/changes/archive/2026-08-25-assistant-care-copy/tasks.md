## 1. English template (`lib/l10n/app_en.arb`)

- [x] 1.1 Widen `settingsAssistantHealthLabel` to name care records alongside
      health and diet records (D1), and update its `@description` to state the
      widened scope and that care rides the same single opt-in — verify by
      grepping the key for "care" and confirming no second switch is implied
- [x] 1.2 Widen `settingsAssistantHealthDisclosure`: lead-in becomes "health,
      diet and care records" and the named record-type list gains care records
      with concrete category examples drawn from `careCategoryMedication` /
      `careCategoryRehab` (D2); leave destination, free-tier training pointer and
      sign-out clauses untouched (D3). Update its `@description` so the named
      list it pins matches — verify the sentence names all four record types and
      still mentions Google's Gemini exactly once
- [x] 1.3 Widen `assistantEmptyHintHealth` and `assistantEmptyHintHealthNoDay`
      to "health, diet and care records", keeping the no-day variant's
      ask-for-a-period sentence verbatim. Update both `@description`s, including
      `assistantEmptyHintHealth`'s note about not offering to log an entry so it
      records that the care tools are read-only too — verify neither string
      offers to log, complete or change a care entry
- [x] 1.4 Widen `assistantEmptyHintNoContextMixed` (outright) and
      `assistantEmptyHintNoContextMixedConsentOff` (conditional, "turn on health
      access in settings and you can also…") to name care records, keeping the
      finance half and the trailing ask-for-a-period sentence unchanged in both.
      Update both `@description`s — verify the two strings still differ only in
      the health half's mood
- [x] 1.5 Widen `assistantHealthAccessOff` to "health, diet or care records"
      (negative phrasing per D1) and update its `@description` — verify it still
      points at settings and names no reminder or push records
- [x] 1.6 Confirm no other ARB key mentions the health opt-in's scope:
      `grep -n "health and diet" lib/l10n/app_en.arb` returns nothing outside
      keys intentionally left alone, and `grep -n "reminder\|push"` finds no new
      claim in the seven touched strings

## 2. Traditional Chinese (`lib/l10n/app_zh_Hant.arb`)

- [x] 2.1 Translate all seven widened strings, using 照護記錄 in the two settings
      strings and 照護紀錄 in the five assistant strings to match each string's
      existing spelling (D4) — verify by diffing that no untouched string's
      記錄/紀錄 spelling moved
- [x] 2.2 Confirm the zh disclosure names the same four record types as the
      English one and keeps 「Google 的 Gemini」 — verify by reading the two
      sentences side by side

## 3. Fallback base (`lib/l10n/app_zh.arb`)

- [x] 3.1 Copy the five assistant strings verbatim from `app_zh_Hant.arb`
      (`assistantEmptyHintNoContextMixed`,
      `assistantEmptyHintNoContextMixedConsentOff`, `assistantEmptyHintHealth`,
      `assistantEmptyHintHealthNoDay`, `assistantHealthAccessOff`); do NOT add
      the two settings keys, which this file has never carried — verify with a
      diff that the five values are byte-identical to their `app_zh_Hant.arb`
      counterparts

## 4. Regenerate and verify

- [x] 4.1 Run `flutter gen-l10n` and stage the resulting `lib/l10n/generated/`
      diff — verify the diff touches only the seven (five for zh) changed
      strings and no key list
- [x] 4.2 Update the one deliberate literal assertion at
      `test/contexts/assistant/presentation/assistant_screen_test.dart:995` to
      the new `assistantHealthAccessOff` text, preserving its literal-not-lookup
      shape and the comment explaining why (D6) — verify that test fails against
      the old literal and passes against the new one
- [x] 4.3 Run `flutter analyze` — verify zero issues
- [x] 4.4 Run `flutter test` — verify green, in particular the settings
      disclosure tests (`settings_screen_test.dart` ~463–521, including the
      zh/en pairing at ~624) and the assistant empty-state/health-access-off
      tests, which follow the copy through `lookupAppLocalizations`
- [x] 4.5 Read the settings AI-assistant section and the assistant empty state
      in both languages and confirm switch label, disclosure, hints and refusal
      all describe the same scope with no reminder/push claim and no care write
      offer — the cross-string consistency the specs require and no single unit
      test covers
