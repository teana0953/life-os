## Why

Final slice of "import from chaodays": the frontend UI. The four backend endpoints
(`POST /api/import/chaodays/{weight,diet,water,bowel}`) are live. This gives the user
an in-app screen to enter their chaodays credentials, pick a date range, and import
all four data types at once, seeing per-type results.

## What Changes

- New `import` context (`lib/contexts/import/`):
  - **`ImportRepository`** port + typed exceptions (fetch failure, reauth-required,
    chaodays-auth-failed, chaodays-unavailable) and a `ChaodaysImportSummary`
    (imported/skipped, plus glucose for diet); **`HttpImportRepository`** calls the
    four endpoints with the Firebase Bearer token, mapping status codes to the typed
    errors (401→reauth, 400 `chaodays_auth_failed`→auth-failed, 502→unavailable).
  - **`ChaodaysImportController`** (ChangeNotifier): runs the four imports in
    sequence, tracking per-type state (pending / importing / success(summary) /
    failed) and an overall status; a lifeos 401 stops with a re-auth prompt.
  - **`ChaodaysImportScreen`**: a form (chaodays account + obscured password, start
    and end date pickers), an import button enabled only when the form is complete,
    and per-type progress/results. Credentials are used only for the import and not
    stored; the copy says so. Error copy (wrong credentials, chaodays unreachable,
    re-auth) is localized and lives in presentation.
- **Entry point**: the health module's 更多 tab gains an import card that pushes the
  screen (`/import/chaodays`), wired like the existing settings entry.
- New i18n strings (en + zh-Hant + zh), regenerated localizations.

Frontend only. Gate = `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test`.

## Capabilities

### Added Capabilities

- `chaodays-import-ui`: from the health module, a user can import all four chaodays
  data types by entering their chaodays credentials and a date range, seeing per-type
  results and clear, recoverable errors, without the credentials being stored.
