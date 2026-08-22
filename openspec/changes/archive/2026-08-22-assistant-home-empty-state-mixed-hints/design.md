## Context

See proposal.md — Why. Two facts about the current screen shape the design:

- `AssistantScreen`'s empty state is driven by a single boolean,
  `_isHealthEntry` (`chatContext?.space == AssistantContextSpace.health`). It
  picks the hint *and* the chips, deliberately — one switch so a health entry
  cannot get health chips under a finance hint. `chatContext == null` (the home
  entry) falls into the `false` arm and is therefore treated as finance.
- The screen already *listens* to `GeminiKeyController`, so
  `healthEnabled` flipping in settings rebuilds the empty state without a
  remount. The consent is off by default and cleared on sign-out.

## Goals / Non-Goals

**Goals:**

- The home (no-context) empty state names both halves of the assistant.
- The home chips follow `healthEnabled` and never offer an example whose data
  the assistant is not allowed to read.
- The finance-entry and health-entry states are byte-for-byte the behaviour
  they have today, including the health-access-off notice.

**Non-Goals:**

- No change to the consent, to the request headers, or to what the backend
  sees.
- No home-entry equivalent of the health-access-off **notice**. That notice
  exists because a *health entry* is a user who just asked for health; a home
  visitor asked for nothing in particular, and putting a "you must enable health
  access" block on the app's most generic entry point would push consent at
  people who never asked for it. **Revised after UI/UX review** (user's own
  call): the notice still stays off the home path, but the flat ban on any
  settings exit there does not — with the consent off, the home hint's health
  clause led nowhere, so a single low-emphasis text button now sits under the
  examples. The reasoning above is what keeps it a text button below the chips
  rather than the health entry's notice + `FilledButton`.

## Decisions

**1. The empty state stops being one boolean and becomes three states:
health entry / finance entry / home.** The `_isHealthEntry` two-way switch
cannot express "home", because "home" is exactly the case it currently folds
into finance. Keep the "one switch picks both hint and chips" discipline by
computing one enum-ish selector (health entry, finance entry, home) and driving
both the hint and the chip list off it — not by adding a second independent
`chatContext == null` test at each of the two call sites, which is how the hint
and the chips drift apart.

*Alternative rejected:* leave the boolean and special-case only the hint. That
gets the reported symptom half-fixed (the hint mentions health, the chips still
say nothing about it) and leaves the two halves keyed on different conditions.

**2. The home chips are two finance + one health, reusing existing copy.** With
consent on: `assistantExampleSpend`, `assistantExampleLog`,
`assistantExampleRemainingPortions`; `assistantExampleOwe` is the one that steps
aside. Three chips stay three — the spec has always said three, and the layout
(a `Wrap` inside a 420px box) was sized for three. Reusing the shipped strings
means no new chip copy and no new translation risk; the dropped chip is the one
whose answer ("who do I owe") is the narrowest of the three finance ones.

*Alternative rejected:* four chips at home. It changes the count the spec fixes
at three and makes the home state taller than every other empty state at large
text scale.

**3. One new hint string, `assistantEmptyHintNoContextMixed` (working name),
replacing `assistantEmptyHintNoContext` at the home call site.** The existing
`assistantEmptyHintNoContext` stays in the ARBs and stays in use: the finance
module with no month still needs a finance-only hint with the ask-for-a-period
sentence. The new string is the finance sentence + a health-and-diet clause +
the same ask-for-a-period sentence, so the home visitor gets one line naming
both halves and one nudge, not two nudges.

**4. The home hint names the health half either way, but conditionally while
`healthEnabled` is off — and offers the switch.** *Superseded the original
Decision 4 ("the home hint does not depend on `healthEnabled`; the chips do")
after UI/UX review; the user made the call.*

The original reasoning is kept because half of it still holds: the hint
describes what the assistant is *for*, and dropping the health clause when the
consent is off would leave a consent-off home visitor with no way to learn the
health half exists at all — issue #231 again. What it got wrong is that
`healthEnabled` is **off by default and cleared on sign-out**, so the flat
promise ("you can also ask about your health and diet records") was the copy
nearly every home visitor met, describing a capability that was not switched on,
while the three chips beside it were all finance. Description and examples
pointed at different assistants.

So the home hint gets two variants off one condition:

- consent on → `assistantEmptyHintNoContextMixed`, unchanged;
- consent off → a new `assistantEmptyHintNoContextMixedConsentOff` whose health
  clause is conditional ("turn on health access in settings and you can also
  ask…"), plus a low-emphasis `TextButton` to `/settings` under the chips so the
  sentence leads somewhere.

The chips are unchanged by this decision — consent off is still spend / log /
owe (Decision 2).

Note the contrast with the *health entry*, where the hint is suppressed
entirely when consent is off: there the "I can't read your health records yet"
notice sits directly beneath it, and hint + notice on one screen was a live
contradiction. That notice still never appears on the home path (Non-Goals), so
the conditional sentence has nothing to contradict.

*Alternative rejected:* keep the flat promise and rely on the chips to signal
the real state. That is what the review found: the chips are not a legible
signal of a consent the user has never seen a switch for.

**4a. The consent-dependent part of the home empty state is a live region.**
The screen listens to `GeminiKeyController`, so granting the consent in settings
and coming back rewords the hint, swaps the third chip and removes the button
on the **same mounted screen** (`_onKeyChanged` only calls `setState`). A screen
reader has nothing to re-read and would announce none of it (WCAG 4.1.3) — the
same reason the health entry's access-off notice already carries a live region.
Wrapping the whole consent-dependent block, not just the chip, because the hint
and the button change too.

**5. Guards.** Per the repo's history of guards that cannot fail:

- Assert on literal expected text, never on
  `find.text(lookupAppLocalizations(en).someKey)` — that compares a string to
  itself and stays green through any copy change.
- The home-with-consent-on and home-with-consent-off cases are a deliberate
  pair: the fixture differs only in `healthEnabled`, and each asserts both what
  is present and what is absent (consent-off must assert the health chip is
  *not* there, or deleting the branch passes).
- Mutation-check each user-visible string separately: each hint variant, each of
  the three chips in each of the two home states, and the settings button. A
  guard that only follows one chip passes with the other two deleted.
- The consent-off case asserts the button is *there* **and** that the health
  entry's `assistant-health-access-off` block is *not*; the consent-on case
  asserts the button is gone. The button gets a test that actually taps it and
  checks it lands on `/settings` — asserting it exists says nothing about where
  it goes.

## Risks / Trade-offs

- **A consent-off home visitor reads "ask me about your health records", asks
  one, and gets an unhelpful answer** → this was accepted in the original
  Decision 4 and rejected at UI/UX review: on the default path the promise is
  simply wrong. Now the sentence is conditional and the switch is one tap away,
  so the health half is still discoverable without being promised.
- **A second settings exit on one screen** (the setup state's, the error row's,
  the health entry's) → they are mutually exclusive states: the home
  consent-off button only renders in the empty state with a key present and no
  health entry, so no two of them are ever on screen together.
- **`assistantExampleOwe` disappears from the home entry** → it remains on the
  finance entry, which is where a split-balance question comes from.
- **Three states multiply the empty-state combinations** (3 entries × consent
  on/off) → covered by making the selector one value used twice, and by pairing
  the two home tests on a single differing fixture field.

## Migration Plan

Pure client-side copy and layout change behind no flag; ships with the next
frontend deploy. Rollback is a revert — no stored state, no schema, nothing
persisted depends on it.
