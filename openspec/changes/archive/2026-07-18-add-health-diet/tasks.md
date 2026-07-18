# Tasks: add-health-diet

## 1. Domain (TDD)

- [x] 1.1 Add entities in `lib/contexts/health/domain/`: `FoodItem` (incl. `baseGrams`), `FoodEntry` (incl. `eatenAt`, portions + nutrients + meal + source), `DayDietLog` (meals grouped + totals), `DailyTarget` (base/bonus/effective/remaining per category)
- [x] 1.2 Add repository ports: `FoodDictionaryRepository`, `DietLogRepository`, `DailyTargetRepository`
- [x] 1.3 Write unit tests then implement the pure portion-preview helper (portions/nutrients × quantity; `grams ÷ baseGrams` with guards for null/non-positive) — calibration: `飯/1碗`×1.5 → 6 staple; `飯/50g` 33g → ~0.66 staple

## 2. Application (TDD with fake repos)

- [x] 2.1 Use cases + tests: `SearchDictionary`, `ListFavorites`, `FavoriteFood` / `UnfavoriteFood`
- [x] 2.2 Use cases + tests: `LogFoodFromDictionary` (quantity XOR grams, eatenAt), `DeleteEntry` (manual free-portion entry is out of scope for this change — dictionary logging is the primary path)
- [x] 2.3 Use cases + tests: `GetDayDietLog`, `GetDailyTargetWithRemaining`, `SetDailyTarget`

## 3. Infrastructure (TDD with a mock http.Client)

- [x] 3.1 `HttpFoodDictionaryRepository` (`GET/POST /api/food-items`, `/favorites`, `/:id/favorite`) decoding items incl. `base_grams`; tests inject a mock client
- [x] 3.2 `HttpDietLogRepository` (`POST /api/diet-entries` dict{quantity|grams, eaten_at}/manual, `GET ?day=`, `DELETE /:id`) + tests
- [x] 3.3 `HttpDailyTargetRepository` (`GET /api/daily-target?day=` returns effective + remaining per category; `PUT` sends flat base/bonus fields) + tests that pin the exact request/response shape against the backend contract
- [x] 3.4 Typed `DietError` family (fetch-failed / reauth-required) thrown by all three (no localized strings); `401` → reauth, mirroring `HttpProfileRepository`

## 4. Theme — category colors

- [x] 4.1 Add four food-group color tokens (light + dark) to `app_colors.dart` and expose them via a `DietCategoryColors` `ThemeExtension` registered on both themes in `app_theme.dart` (staple=Usagi yellow, meat=blush pink, fruit=peach, veg=sage); screens read them through the theme

## 5. i18n

- [x] 5.1 Add all diet ARB keys to `app_en.arb` (template, with descriptions) and `app_zh_Hant.arb` (translations); run `flutter gen-l10n` and commit generated output

## 6. Presentation (widget tests with fake repos)

- [x] 6.1 `DietShellScreen` with a bottom `NavigationBar` (Today · Dictionary · Target); owns token load and passes it down; `ChangeNotifier` controllers per section
- [x] 6.2 `TodayScreen` + controller: per-category portion progress + meals/snacks in eaten order; loading/error/reauth states like `HomeScreen`; widget tests (eaten-order, progress, error)
- [x] 6.3 `QuantityCard` widget + `LogEntryController`: meal chips, dictionary search + favorites, unit/gram toggle, quantity stepper (decimals), live portion preview via §1.3, eaten-at picker (defaults now), save; widget tests (preview scales; gram option hidden when no base grams; save calls the use case)
- [x] 6.4 `DailyTargetScreen` + controller: per-category steppers + remaining view; widget tests (set target, remaining reflects logged)
- [x] 6.5 Add-snack flow (custom snack label) reachable from Today / log entry; widget test

## 7. Home entry + composition

- [x] 7.1 Home "健康" tile navigates to `DietShellScreen`; remove the `profile.id` row from the home profile card; update existing home widget tests
- [x] 7.2 Wire the new repositories, use cases, and controllers from `main.dart` (manual DI); pass `apiBaseUrl` + `http.Client` + auth token like the profile flow

## 8. Verify

- [x] 8.1 Run `flutter analyze` and `flutter test`; both green
