# Design — Diet history + edit

## Context

`DietShellScreen` owns a `late final _day` computed once in `initState`, so the
whole shell is pinned to one day. `TodayScreen` renders that day's meals (entries
are display-only). The backend already exposes: `GET /api/diet-entries?day=`,
`GET /api/diet-entries/logged-days?month=`, `PATCH /api/diet-entries/:id`,
`DELETE /api/diet-entries/:id`. This change adds the navigation + editing UI and
the two missing repository methods. Follows the frontend CLAUDE.md (Clean
Arch/DDD, typed errors in controllers, i18n, Chiikawa theme, TextField, fakes).

## Decisions

### D1 — Two new repository methods (domain + infra)

Add to the `DietLogRepository` port:

```dart
Future<FoodEntry> updateEntry(String idToken, String entryId, {
  String? name, String? meal, DateTime? eatenAt, Portions? portions,
});
Future<List<String>> loggedDays(String idToken, String month); // "YYYY-MM"
```

`HttpDietLogRepository.updateEntry`: `PATCH /api/diet-entries/$entryId` with a
**partial** body — include only non-null fields (`name`, `meal`,
`eaten_at: eatenAt.toUtc().toIso8601String()`, `portions:{staple,meat,fruit,veg}`).
Expect 200 → `FoodEntry.fromJson`; 401 → `DietReauthenticationRequired` (via the
existing `_send`); other non-200 → `DietFetchFailure`. `loggedDays`:
`GET /api/diet-entries/logged-days?month=$month`, 200 → `(json['days'] as List)
.cast<String>()`.

Note on **name clearing**: sending `name: null` from the sheet means "leave
unchanged" (partial semantics), not "clear". Clearing a name is out of scope; the
sheet keeps whatever name the entry had unless the user types a new one — the
controller sends `name.isEmpty ? null : name` (same as `ManualEntryController`),
so blanking the field is a no-op (keeps the original name), *not* "make it
nameless". This is called out so a future "clear name" need isn't mistaken for a
bug.

### D2 — Use cases

`UpdateFoodEntry` and `GetLoggedDays` — thin wrappers over the port, mirroring the
existing `GetDayDietLog`/`LogManualEntry` shape.

### D3 — Mutable day + navigation in the shell

`DietShellScreen._day` becomes mutable state (`String _day`, initialized from
`clock()`), plus `DateTime _viewedDate`. A `_DayNavBar` at the top of the Today
tab shows `‹ <label> ›` + a calendar icon button. `label` is "今日"/"昨天" for
today/yesterday else a formatted date. Changing day:
`setState(_day = ...)` then reload `todayController.load(token, _day)` **and**
`dailyTargetController.load(token, _day)` (target carries forward, so it changes
per day). The existing `_openLogEntry`/`_openManualEntry`/`DailyTargetScreen` read
the mutable `_day`.

**Blocking the future**: `_viewedDate` may not advance past today — the `›` arrow
is disabled when `_viewedDate` is today (compared by calendar date via the
injected `clock`, timezone-safe). The FAB/log flows on a past day still write to
that past `_day` (the backend derives `day` from `eaten_at` on manual/dict log via
the supplied `day`).

### D4 — Calendar with entry markers

The calendar button opens a dialog hosting a **custom** month grid `_DietCalendar`
(Material's `CalendarDatePicker` can't cleanly decorate individual days, so we
don't build on it). The grid: a month header with prev/next month, day cells for
the month; future dates (after today, by the injected `clock`'s local calendar
date) are non-selectable/dimmed. On open (and on month change) it calls
`GetLoggedDays` for the visible month and renders a small dot under days in the
returned set. All colors/shapes come from `Theme.of(context)` /
`DietCategoryColors` — no hard-coded `Color`/`Colors.*` (CLAUDE.md). Picking a day
sets `_day` and reloads today + target. Loading the month's logged days uses its
own tiny state; a failure degrades to an unmarked (still usable) calendar and
never blocks navigation.

### D5 — Edit bottom sheet + shared portion form

Tapping an entry (make `TodayScreen`'s per-entry `ListTile` tappable via an
`onEditEntry(FoodEntry)` callback wired by the shell) opens a
`showModalBottomSheet(isScrollControlled: true)` hosting `EditEntryScreen`, driven
by a new `EditEntryController`:

- Fields: `name`, `staple/meat/fruit/veg`, `meal`, `snackLabel`, `eatenAt`;
  seeded from the tapped `FoodEntry` via `start(entry)`. Seeding **meal**: if
  `entry.meal` is one of `breakfast`/`lunch`/`dinner` use it directly, else treat
  it as a custom snack — `meal = snackMealValue`, `snackLabel = entry.meal` — so a
  snack's custom label round-trips through the shared form (mirrors
  `ManualEntryController`).
- **eatenAt is dirty-tracked** (`_eatenAtChanged` flag, set only by `setEatenAt`).
  This is the fix for the eaten_at/day-move trap: the backend re-derives an
  entry's `day` from the UTC calendar date of any supplied `eaten_at`, and a
  logged entry's stored `day` (sent as the user's *local* day at create time) can
  differ from its `eaten_at`'s UTC date (common for UTC+8 early-morning /
  late-night entries). So `save` MUST send `eatenAt` **only when the user actually
  changed the time** — otherwise a portions-only edit would silently move the
  entry to another day and drop it from the viewed day. When untouched, the patch
  omits `eatenAt` entirely (PATCH carries no `eaten_at`, backend leaves `day`).
- `save(idToken)` → `UpdateFoodEntry(entryId, name, meal (or snackLabel),
  portions, eatenAt: _eatenAtChanged ? eatenAt : null)`; on success pop + refresh
  the day. `delete(idToken)` → `DeleteEntry` + pop + refresh.
- Typed error enum (`saveFailed`, `reauthRequired`, `unknown`) held in the
  controller; the screen maps to localized copy in `build()`.
- Reuse the manual-entry form layout by extracting a shared
  `PortionFormFields` widget (name field + four portion inputs + meal selector +
  time picker) used by both `ManualEntryScreen` and `EditEntryScreen`. This is a
  targeted refactor serving this change (avoids duplicating the form); manual
  entry's behavior is unchanged. Delete lives only in the edit sheet.

### D6 — i18n

New ARB keys (en + zh-Hant + zh): edit sheet title, save/delete labels, a delete
confirmation, "今日"/"昨天" day labels, calendar dialog title/close. No hard-coded
strings; controllers hold typed errors, screens localize.

## Testing

- Infra: inject a mock `http.Client`; `updateEntry` sends a partial PATCH body
  (only provided fields) and parses 200; 401 → reauth; `loggedDays` parses
  `{days}`.
- Controller: `EditEntryController.start(entry)` seeds fields; `save` calls update
  with the right patch and flips status; `delete` calls delete; typed errors on
  failure.
- Widget: day nav changes day and reloads (fake controllers assert `load` calls);
  future `›` disabled on today; tapping an entry opens the sheet prefilled;
  saving/deleting refreshes; calendar marks logged days (fake `loggedDays`).
  Follow existing widget-test patterns (inject fakes, `l10nTestApp`, pinned
  `clock`, `setSurfaceSize` teardown).
