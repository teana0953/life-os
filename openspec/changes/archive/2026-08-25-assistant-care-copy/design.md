## Context

See proposal.md — Why. The mechanism is already in place on both sides: the
backend gates `get_care_today` / `get_care_range` / `list_care_items` on
`X-Assistant-Health: on`, and `AssistantController` already sets that header
from the existing `healthEnabled` consent. This change touches no Dart under
`lib/contexts/` at all — `settings_screen.dart:560,563` and
`assistant_screen.dart:385,386,393,394,427` already render exactly the seven
keys involved, and already branch on `healthEnabled` where the copy differs.
What is left is choosing seven sentences and keeping three ARB files and the
generated Dart in step.

Constraints that shape the wording:

- The disclosure is a **consent** disclosure. Under the repo's i18n rules it is
  the only place the covered record types are enumerated, and the existing
  requirement demands they be *named*, not summarized as "health data". So a
  bare "and care records" is not enough — care needs the same concreteness that
  "menstrual cycles, blood glucose, vital signs" has.
- Care access is **read-only** server-side. No hint may imply the assistant can
  mark a slot done or create a care item; the health hint already deliberately
  avoids offering to log anything for the same reason (its `description` says
  so).
- Reminder and push records stay unreachable in **both** opt-in states. They
  must not appear anywhere in this copy.
- `app_zh.arb` is a gen_l10n fallback base carrying a subset of keys. It has the
  five assistant keys and neither settings key, so it changes in five places,
  not seven. Adding the two settings keys to it is out of scope.

## Goals / Non-Goals

**Goals:**

- Every user-visible sentence describing the health-access consent names care
  records, in both supported languages, with matching scope between the switch
  label, the disclosure, the hints and the refusal.
- The `@key.description` entries stay a truthful contract for translators — they
  currently pin the old three-type list and would otherwise mislead the next
  person adding a language.
- `lib/l10n/generated/` is regenerated and committed in the same commit, per
  the repo's checked-in-generated-code rule.

**Non-Goals:**

- Any change to when `X-Assistant-Health` is sent, to consent storage, or to
  sign-out revocation.
- New example prompt chips for care (`assistantExampleRemainingPortions` and
  friends stay as they are) — chips are a separate design decision about what
  the model answers well, and adding one is not needed for the copy to be
  accurate.
- Adding the two settings keys to `app_zh.arb`.
- Any test restructuring beyond following the copy.

## Decisions

### D1 — Widen "health and diet records" to "health, diet and care records" everywhere, rather than inventing a new umbrella term

Alternative considered: coin a single cover term ("your wellbeing records",
「你的健康資料」) and stop enumerating. Rejected: the existing consent
requirement explicitly forbids summarizing as "health data", and an umbrella
term is exactly that. The three-noun list is longer but it is the thing the
requirement is protecting.

The phrase is a fixed unit across all seven strings — the switch label, the
disclosure lead-in, both home hints, both health hints and the refusal — so
that a user reading two of them never wonders whether they describe different
scopes. In the refusal the conjunction becomes "or" ("health, diet or care
records"), matching the existing negative phrasing.

### D2 — In the disclosure, name care by its concrete categories, not by the word "care" alone

The disclosure's record-type list becomes "menstrual cycles, blood glucose,
vital signs and care records such as medication and rehabilitation". The app's
own care categories are Medication / Rehab / Radiotherapy care / Custom
(`careCategoryMedication`, `careCategoryRehab`), so "medication and
rehabilitation" is the product's own vocabulary, not an invention, and it is the
level of concreteness the three existing items sit at. "Radiotherapy care" is
left out of the list as a "such as" example set — naming all four turns a
sentence into a table.

Alternative considered: append a bare "and care records" to the list. Rejected:
it repeats the lead-in verbatim and tells a user who has never opened 照護
nothing about what would be sent.

### D3 — Leave the free-tier training notice and the sign-out notice untouched

`settingsAssistantTrainingNotice` and `settingsAssistantDeviceNotice` are scope-
agnostic — they talk about the destination and the device, not about record
types. Widening the record scope does not change either sentence, and the
existing `settingsAssistantHealthDisclosure` description explicitly records that
the training use is stated once and deliberately not repeated. Nothing to do.

### D4 — Keep each file's existing 記錄/紀錄 spelling rather than normalizing

`app_zh_Hant.arb` uses 「記錄」 in the settings strings and 「紀錄」 in the
assistant strings today. Both are correct Traditional Chinese and the split is
pre-existing. Normalizing them is an unrelated change that would enlarge the
diff and break the surgical-change rule; the new care wording adopts whichever
form the string it lives in already uses (照護記錄 in settings, 照護紀錄 in the
assistant strings).

### D5 — Update every touched key's `description`, and only those

Seven strings change, so seven `@key.description` entries change, in
`app_en.arb` only (it is the template and the only file carrying descriptions).
Each description currently states the old semantics as a rule for future
editors — `assistantEmptyHintHealth`'s says the hint does not offer to log an
entry "because the shipped health tools are read-only", which must now also
account for the care tools being read-only; `settingsAssistantHealthDisclosure`'s
names the three record types explicitly. Descriptions of untouched keys are left
alone.

### D6 — Fix the one literal assertion, leave the lookup-based ones

`test/contexts/settings/...` and most of `test/contexts/assistant/...` assert
against `lookupAppLocalizations(...)` values, so they follow the copy for free —
that is the point of the repo's i18n testing rule. The single exception is
`assistant_screen_test.dart:995`, which asserts a **literal** on purpose (its
own comment says an expectation built from the same lookup the widget uses
would pass even if the widget rendered the wrong key). That literal is updated
by hand; the deliberate literal-not-lookup shape is preserved.

## Risks / Trade-offs

- **The disclosure sentence gets long** → it already carries a four-clause
  structure; the addition is one noun in the lead-in and one "such as" clause in
  the list. `settings_screen_test.dart` has responsive/overflow guards over this
  section (lines ~463–521) that will catch a layout break — though per CLAUDE.md
  a green widget test proves logic, not metrics, since `flutter_test` renders
  fixed-width glyph boxes. The zh text is the longer of the two and the one to
  eyeball in a real build if anything looks tight.
- **Users who granted consent before this change did so against narrower copy**
  → unavoidable and not fixable by copy alone; the consent is user-revocable at
  any time from the same screen, sign-out clears it, and the widened disclosure
  is what they now see on every visit. A one-off re-consent prompt was
  considered and rejected as out of scope for a copy change — it would need new
  stored state, which the proposal explicitly excludes.
- **"Care" is a vaguer English noun than 照護** → mitigated by D2's concrete
  category examples in the disclosure, which is the one place precision is
  legally load-bearing. The hints can stay short.
- **`app_zh.arb` drifting from `app_zh_Hant.arb`** → the five assistant strings
  are duplicated verbatim between the two files today; the tasks copy them
  across in one step so they cannot diverge, and `flutter gen-l10n` fails loudly
  on a key present in the template but missing from a locale file.
