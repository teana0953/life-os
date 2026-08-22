## 1. Consent storage

- [x] 1.1 Add the `assistant_health_enabled` prefs slot to
  `lib/shared/assistant/gemini_key_controller.dart`: a `healthEnabled` getter read in
  the constructor (absent/unreadable → `false`, per design D2), a
  `setHealthEnabled(bool)` that awaits the write before mutating the field and
  notifying, and `clear()` extended to remove the entry alongside the key with the
  same ordering. Extend the class doc with why the flag lives here (#156, design D1).
  Verify: `flutter analyze` clean.
- [x] 1.2 Extend `test/shared/assistant/gemini_key_controller_test.dart`: default-off
  on a fresh prefs map, set → both `healthEnabled` **and** the prefs entry change,
  round-trip through a newly constructed controller, and `clear()` leaves both the key
  and the flag absent **in memory and in prefs**. Verify: `flutter test
  test/shared/assistant/gemini_key_controller_test.dart` green, and mutating
  `clear()` to drop only the in-memory field turns the prefs assertion red.

## 2. Wire the consent to the request

- [x] 2.1 Add a required named `healthEnabled` to the port
  `lib/contexts/assistant/domain/assistant_repository.dart` (documenting that the
  adapter must omit, not falsify, the claim when it is false) and thread it through
  `lib/contexts/assistant/application/send_assistant_message.dart`. Verify: `flutter
  analyze` names every call site that has to decide (design D3).
- [x] 2.2 In `lib/contexts/assistant/infrastructure/http_assistant_repository.dart`,
  emit `'X-Assistant-Health': 'on'` only when `healthEnabled` — exact lower-case
  value, no header at all otherwise (design D4). Verify: `flutter analyze` clean.
- [x] 2.3 Add guards to
  `test/contexts/assistant/infrastructure/http_assistant_repository_test.dart`:
  enabled → the captured request headers contain `X-Assistant-Health` with exactly
  `on`; disabled → the captured headers contain no `X-Assistant-Health` key at all
  (assert on the recorded request, not on a fake's default). Verify: both green, and
  **both** mutations turn the pair red — invert the condition, and delete the
  condition so the header is always sent.
- [x] 2.4 Thread the value through
  `lib/contexts/assistant/presentation/assistant_controller.dart` (`send`,
  `retryLast`, `_dispatch`) and read it in
  `lib/contexts/assistant/presentation/assistant_screen.dart` at send time and at
  retry time, beside the existing key read. Verify: `flutter test
  test/contexts/assistant/` green, plus a controller/screen guard that a retry after
  toggling the setting sends the current value (spec scenario "A retry carries the
  consent in force at retry time").

## 3. Settings control and copy

- [x] 3.1 Add to `lib/l10n/app_en.arb` (each with a `description`) and
  `lib/l10n/app_zh_Hant.arb` the separate strings of design D6: the switch label, the
  disclosure naming Google's Gemini + free-tier training use + menstrual cycles,
  blood glucose and vital signs, the sign-out revocation rule, and the no-key note —
  all phrased as standing rules. Verify: `flutter gen-l10n` succeeds and the
  regenerated `lib/l10n/generated/` is committed; both ARB files hold every new key.
- [x] 3.2 Add the switch row and the disclosure text to `_AssistantKeySection` in
  `lib/contexts/settings/presentation/settings_screen.dart`, reading and writing
  `widget.controller.healthEnabled` / `setHealthEnabled`, rendered in **both** the
  has-key and no-key branches so it is reachable with no key stored (design D5).
  Colors and text styles from `Theme.of(context)` only; every string from
  `AppLocalizations`. Verify: `flutter analyze` clean, no hard-coded literal.
- [x] 3.3 Add guards to `test/contexts/settings/presentation/settings_screen_test.dart`:
  the switch is off by default, toggling it writes through to the controller and the
  prefs entry, the switch is present and operable with **no key stored**, and each
  disclosure string is asserted by content via `lookupAppLocalizations(locale)` — not
  by widget key alone. Verify: green in both locales, and per #208 each user-visible
  string mutated **separately** (replace that one string's source with a sentinel)
  turns exactly one guard red.

## 4. Sign-out coverage and closing checks

- [x] 4.1 Verify the existing `_resetControllersOnSignOut` path in `lib/app.dart`
  clears the flag without modification (design D1's whole premise): add a guard that
  signs out with the flag on and asserts it is off in memory and absent from prefs
  afterwards. Verify: green, and it fails if `clear()` stops removing the flag.
- [x] 4.2 Full suite and static analysis: `flutter analyze` clean and `flutter test`
  green, plus `TZ=UTC flutter test` — no date logic here, but the repo's CI runs UTC
  and the settings suite is shared.
- [x] 4.3 Confirm against the backend contract that no other value is ever emitted
  (`grep -rn "X-Assistant-Health" lib` returns exactly one occurrence, guarded by the
  condition) and record the check in the PR description.
