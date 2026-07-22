## Why

The backend now requires a time (HH:mm) on every vitals reading (life-os-backend
PR #19), so multiple readings on the same day can be ordered. The vitals screen's
three list editors need a per-reading time control. Small change to the shipped
vitals-ui.

## What Changes

- **Reading types gain a `time`** (`String`, HH:mm): `BpReading`, `GlucoseReading`,
  and `Spo2Reading` add `time` in `fromJson`/`toJson` and in their value equality
  (`==`/`hashCode`) so `hasUnsavedChanges` (which compares the lists element-wise)
  still works.
- **Adding a reading defaults its time to now**: a new row's time is pre-filled
  with the current `HH:mm`, so the required field is never empty (satisfies the
  backend's required-time without friction) and can be changed.
- **A per-reading time control** on each row in all three list editors: a compact
  tappable control showing the reading's `HH:mm`; tapping opens the Material time
  picker and writes the chosen time back to that reading.
- The controller gains time editing (via the existing per-list field update or a
  `setTime`); `HttpVitalsRepository` serialization already flows through
  `toJson`/`fromJson`, now including `time`.
- No change to the scalars, the other tabs, or the backend.

## Capabilities

### Modified Capabilities

- `vitals`: every blood-pressure, glucose, and blood-oxygen reading now has a time
  (HH:mm) shown and editable per row, defaulting to the current time when a reading
  is added.
