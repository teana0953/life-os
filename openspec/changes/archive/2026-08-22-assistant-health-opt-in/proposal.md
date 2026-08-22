## Why

The AI assistant deliberately cannot see any health data today. The backend
(`teana0953/life-os-backend` PR #123, merged) now registers nine read-only health
tools — but only when the request carries `X-Assistant-Health: on`. Nothing in the
app can send that header, so the capability is unreachable.

It has to stay unreachable until the user says otherwise. This app stores menstrual
cycles, blood glucose and vital signs, and the assistant runs on the user's own
free-tier Gemini key — a tier whose terms generally reserve the right to use
submitted content for training. That is a decision only the user can make, so this
change ships the place to make it: off by default, explicit about what is sent and
where, and revoked on sign-out.

## What Changes

- `GeminiKeyController` gains a persisted `healthEnabled` flag (its own
  `SharedPreferences` slot) with a setter, and `clear()` clears the flag alongside
  the key. **The flag lives in the existing controller on purpose** — issue #156's
  sign-out leak happened because the key was a bare prefs entry rather than
  controller state, and `app.dart`'s list-shaped sign-out reset can only see
  controllers it was handed. A second controller would rebuild that bug.
- The settings page's existing "AI assistant" section gains a switch, default off,
  with copy that names menstrual cycles, blood glucose and vital signs explicitly,
  states that those records are sent to Google's Gemini and that free-tier content
  is generally used for training, and states that sign-out turns it back off. The
  copy is written as a standing rule, not an incident notice (matching the existing
  device-storage notice), and is added to both ARB files.
- The switch is operable with no key stored — consent and credential are separate
  decisions, and disabling the control would read as a broken feature. The copy
  carries the fact that no request is made at all without a key.
- `HttpAssistantRepository.send` takes the consent as a per-call argument (the same
  shape `geminiKey` already uses) and adds `X-Assistant-Health: on` **only** when it
  is true. Exactly `on`: the backend does not trim or casefold, and fails closed.
  The port, the use case, `AssistantController` and `AssistantScreen` thread the
  value through; the screen reads it at send time, next to where it already reads
  the key.

## Capabilities

### New Capabilities

- `assistant-health-consent`: whether the assistant may read the user's health and
  diet records — where the consent is stored, how it is granted and revoked, what
  the user is told before granting it, and how it reaches (and stays off) the wire.

### Modified Capabilities

<!-- None. The `settings` spec has no requirement covering the AI assistant
     section, so the new control's rules belong wholly to the new capability
     rather than splitting across two specs. -->

## Impact

- `lib/shared/assistant/gemini_key_controller.dart` — new prefs key, `healthEnabled`
  getter, `setHealthEnabled`, `clear()` extended.
- `lib/contexts/settings/presentation/settings_screen.dart` — a switch row plus
  consent copy inside `_AssistantKeySection`.
- `lib/l10n/app_en.arb`, `lib/l10n/app_zh_Hant.arb` (+ regenerated
  `lib/l10n/generated/`) — the new strings.
- `lib/contexts/assistant/domain/assistant_repository.dart`,
  `application/send_assistant_message.dart`,
  `infrastructure/http_assistant_repository.dart`,
  `presentation/assistant_controller.dart`, `presentation/assistant_screen.dart` —
  the per-call consent argument and the conditional header.
- Tests: the controller's persistence + clear-on-sign-out guards, the settings copy
  and toggle guards (every user-visible string mutated separately — #208), and the
  header-present/header-absent guards on the repository.
- No backend change: `X-Assistant-Health` is already implemented and already in the
  Worker's CORS `allowHeaders`.
- Out of scope: health write proposals (#218), the assistant entry point on the
  health pages (#220), cross-device sync of the flag.
