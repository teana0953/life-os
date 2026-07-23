# Tasks

- [x] Nest the routes under `/health` (diet → target/food-search; `:name` trackers).
- [x] Build structural screens in the router from injected controllers (drop `extra`).
- [x] `AuthRouterNotifier` resolves + holds the id-token (awaited before notify).
- [x] Keep `extra` only for per-nav args: food-search `(meal, day)`, target `day`; redirect to `/health/diet` when absent.
- [x] Simplify call sites to push a path; shrink `HomeScreen` / `_AuthenticatedHome` / `_RecordHub` (remove dead params).
- [x] Regression test: URL-driven `go()` to a nested deep route pops one level (not to base).
- [x] `flutter analyze` + `flutter test` + `bash scripts/lint-actions.sh` green.
