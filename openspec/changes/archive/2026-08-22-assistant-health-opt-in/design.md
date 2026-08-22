## Context

See proposal.md — Why. Constraints this design has to work inside:

- The backend (life-os-backend PR #123, merged) registers the nine read-only health
  tools only when the request header `X-Assistant-Health` is **exactly** `on`. It
  does not trim and does not casefold; anything else, including a missing header,
  denies the tools. It is already listed in the Worker's CORS `allowHeaders`.
- `GeminiKeyController` (`lib/shared/assistant/`) is an app-lifetime `ChangeNotifier`
  over `SharedPreferences`, constructed once in `main.dart` and handed to `App`.
  `app.dart`'s sign-out reset is a hand-written list of controllers to clear
  (`unawaited(widget.geminiKeyController.clear())` among them) — it enumerates
  objects, so per-user state that is not on one of those objects is invisible to it.
  That is exactly how #156 shipped.
- The key already travels as a **per-call** argument
  (`AssistantRepository.send(idToken, geminiKey:, messages:)`), read from the
  controller at the moment of sending in `AssistantScreen._send`/`_retry`. The
  dependency rule forbids `infrastructure/` importing a presentation-layer
  controller anyway.

## Goals / Non-Goals

**Goals:**

- One object owns the consent, so every existing sweep over per-user state covers it.
- The "off" path is provably off — a guard that fails when the condition is inverted
  or deleted, not one that passes because a header is absent for unrelated reasons.
- The user can read what leaves the device before deciding.

**Non-Goals:**

- Any change to what the assistant does with the tools once granted (that is the
  backend's, already merged).
- A per-conversation or per-message consent. The switch is a standing setting; the
  request reflects its value at send time and nothing narrower.
- Storing the consent server-side or syncing it across devices — see Risks.

## Decisions

### D1 — The flag lives on `GeminiKeyController`, not a new controller or a bare prefs read

Adding `AssistantHealthController` would be the tidier-looking split (consent is not
a credential), and reading the prefs entry directly at the call site would be the
smallest diff. Both reintroduce #156: the sign-out reset in `app.dart` can only clear
what it was handed, so new per-user state that is not on an already-registered
controller is state nobody clears. Consent to send menstrual and glucose records is
precisely the kind of state that must not survive into the next account on a shared
device.

The cost is a controller whose name (`GeminiKeyController`) is now narrower than its
contents. Accepted: the alternative trades a naming smell for a privacy leak. The
class doc records why the flag is there, so a future tidy-up split does not undo it
without reading the reason.

### D2 — A separate prefs entry, absent meaning "off"

`assistant_health_enabled`, its own slot. Not packed into the key's entry (clearing
one must not be able to half-clear the other), and not provider-named: unlike the API
key — whose provider-specific name deliberately blocks a future provider switch from
silently reusing the slot — consent to read health records is about *this app's* data
and survives a provider change unchanged.

Absent or unreadable reads as `false`. `getBool` returning `null` on a fresh install,
in private browsing, or after cleared site data must never mean "granted".

`clear()` removes the entry rather than writing `false`, and awaits the writes before
mutating the in-memory fields and notifying — the same ordering, for the same reason,
as the existing `setKey`/`clear`: a revocation that repaints as revoked while the flag
is still on disk is worse than one that visibly failed.

### D3 — The consent is a per-call argument, threaded like `geminiKey`

`AssistantRepository.send` gains a required named `healthEnabled` (bool), passed by
`SendAssistantMessage` and `AssistantController`, read by `AssistantScreen` from
`geminiKeyController.healthEnabled` at the moment of sending — the line right next to
where it already reads the key, so the two can never come from different points in
time.

Rejected: injecting the controller into `HttpAssistantRepository`. It puts a
presentation-layer object inside `infrastructure/` against the dependency rule, and
it makes the header depend on a mutable object the adapter holds rather than on a
value the caller resolved — the shape MEMORY records as "a shared field used as the
answer to a single call" (#165).

Making the parameter **required** rather than defaulted is deliberate: a default of
`false` would let a future call site forget it and silently lose a consent the user
granted; a default of `true` would leak. Required means the compiler names every site
that has to decide.

### D4 — Off means the header is absent, not `off`

The adapter emits the header only inside `if (healthEnabled)`. Sending
`X-Assistant-Health: off` would also work against this backend, but it makes the
denial depend on the backend's string comparison rather than on the request not
carrying the claim at all — and it puts the app one typo (`'On'`, `'on '`) away from
granting access the user did not grant, against a backend that fails closed precisely
because it does not normalize.

The guard risk this creates is that "the header is absent" is the easiest assertion in
this repo to write green by accident — an assertion against the wrong request object,
or a fake that never records headers, passes forever. So the disabled-case guard is
mutation-verified in both directions: inverting the condition and deleting the
condition must each turn it red, and the enabled-case guard asserts the exact value
`on` (not `contains`, not case-insensitive).

### D5 — The switch works with no key stored

Consent and credential are separate decisions, and a greyed-out switch in a section
that already shows a key field reads as "this feature is broken". The section instead
states the consequence: with no key, the assistant sends nothing anywhere. `_send`
already returns early when `key == null`, so an enabled flag with no key produces no
request — the flag is inert, not dangerous.

### D6 — Copy: separate ARB strings, standing-rule phrasing, each guarded on its own

The disclosure is split into distinct ARB keys (the switch label, the disclosure
naming Gemini + free-tier training + menstrual/glucose/vitals, the sign-out
revocation, and the no-key note) rather than one paragraph. Two reasons: the existing
section already composes several short notices this way, and #208 — when a control
collapses into "one entry plus a layer", guards follow the entry and every other
string can be replaced with `Text('zzz')` with the suite green. Separate keys make
"mutate each user-visible string separately" a mechanical, checkable exercise.

Phrasing follows the existing `settingsAssistantDeviceNotice` ("The key is stored only
on this device. Signing out … removes it") — a description of how the feature works.
Written as an event ("Your health data was shared"), the same sentence reads as an
incident report to someone opening settings for the first time.

Both `app_en.arb` (with `description`) and `app_zh_Hant.arb` get every key, and
`lib/l10n/generated/` is regenerated and committed, per the repo's i18n rules.

## Risks / Trade-offs

- **The flag is device-local, so consent granted on the phone does not appear on the
  laptop** → Consistent with the key, which is already device-local for the same
  reason (it is stored in `SharedPreferences`, never sent to our backend). Erring
  toward re-asking on a new device is the safe direction for this particular setting.
- **`GeminiKeyController` now holds two unrelated concerns** → Accepted per D1;
  the class doc states why, so the split is not undone by tidying.
- **The "header absent" guard is the classic always-green shape** → D4's two-direction
  mutation is part of the task list, not left to reviewer discretion.
- **A user enables the switch, never adds a key, and believes health data is being
  used** → The no-key note (D5) is on screen in the same section; the assistant screen
  additionally shows its setup state whenever no key is stored.
- **Copy drift between the two ARB files** — the English gains a sentence the Chinese
  does not → Every new key is added to both files in the same task, and the copy guards
  assert against `lookupAppLocalizations(locale)`, so a missing translation surfaces as
  a failure rather than as English text on a Chinese screen.

## Migration Plan

None. The absent prefs entry reads as disabled, so every existing install starts off,
which is the intended default. The backend change is already deployed and is a no-op
for a request without the header, so old clients keep working unchanged; rollback is
reverting the frontend, after which no request carries the header again.
