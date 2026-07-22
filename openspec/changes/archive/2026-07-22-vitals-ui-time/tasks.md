# Tasks

TDD throughout: failing test first, then implementation. Run `flutter analyze` +
`flutter test`. Colors from Theme; strings via ARB (en+zh_Hant+zh, gen_l10n);
tests via l10nTestApp. This modifies the shipped `lib/contexts/vitals/**`.

## 1. Domain: time on each reading

- [x] 1.1 Add `final String time;` (HH:mm) to `BpReading`, `GlucoseReading`,
      `Spo2Reading` in `lib/contexts/vitals/domain/vitals_day.dart` (they use
      MANUAL `==`/`hashCode`, not Equatable). Update each type's `fromJson` (read
      `json['time']`, default `''` for tolerance of pre-#19 data), `toJson` (write
      `time`), `copyWith` (add a `time` param — the screen edits time via
      `copyWith(time:)`), and **`==`/`hashCode` (include `time`)** — the reading
      types have value equality that `hasUnsavedChanges` relies on via `listEquals`;
      omitting `time` would miss time edits. Test first (a reading with a changed
      time is `!=` the original; fromJson/toJson round-trip `time`).

## 2. Controller: default-now on add, edit time

- [x] 2.1 Test first (fake repo): `VitalsController`'s add-reading methods
      (addBpReading/addGlucoseReading/addSpo2Reading) now set the new reading's
      `time` to the current `HH:mm`. Editing a reading's time (via the EXISTING
      `updateBpReading`/`updateGlucoseReading`/`updateSpo2Reading` methods, which
      replace the whole reading at an index — the screen passes
      `reading.copyWith(time: newTime)`; do NOT add a `setTime` method) flips
      `hasUnsavedChanges`. Implement — **inject a clock** into the controller
      (`TimeOfDay Function() clock` defaulting to `TimeOfDay.now`) so the
      "defaults to now" test is deterministic; format it with **manual zero-pad**
      (`'${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}'`) — NOT
      `formatTimeOfDay` (which can localize digits/separators; the backend needs
      strict ASCII "HH:mm").

## 3. Screen: per-reading time control

- [x] 3.1 Test first: assert the time WRITE-BACK deterministically in the
      CONTROLLER test (tapping the Material picker's OK only accepts the unchanged
      initialTime, so a widget test can't cleanly prove a NEW time). In the
      `vitals_screen` widget test just assert each row shows a time control with its
      HH:mm and that a freshly added row shows a non-empty (current) time; opening
      the picker (tap → picker appears) is fine to assert too.
- [x] 3.2 Implement in `vitals_screen.dart`: add a compact time control to each
      row (in the generic `_ReadingListSection` row builder — a button/chip showing
      the `HH:mm`, `onPressed` → `showTimePicker(context, initialTime: <parsed>)` →
      on result write back via `updateXReading(index, reading.copyWith(time:
      zeroPadded(t)))`). **Parse `initialTime` with a guard** that tolerates an
      empty/malformed stored time (a pre-#19 reading has `time == ''`) — fall back
      to `TimeOfDay.now()` (or 00:00) instead of crashing. Store/serialize the
      manually zero-padded "HH:mm" (see 2.1); `formatTimeOfDay` may be used for
      on-screen display only. Colors from Theme; label via ARB (`vitalsTimeLabel`
      "Time" / "時間") for the control's tooltip/semantics.

## 4. Serialization + regression

- [x] 4.1 `HttpVitalsRepository` test: the three reading types round-trip `time`
      through GET/PUT (fromJson/toJson). Update ALL existing vitals test fixtures +
      assertions to include `time`: the http repo test (incl. its exact captured-
      body map assertions — once toJson emits `time`, those maps must gain `time`),
      the controller test, the screen test, AND
      `test/contexts/vitals/application/vitals_use_cases_test.dart` (it constructs a
      `BpReading` — a now-required `time` param breaks compile without it).
- [x] 4.2 `flutter analyze` clean + `flutter test` green — existing vitals/shell/
      home/app tests still pass; regenerate `lib/l10n/generated` if an ARB key was
      added.
