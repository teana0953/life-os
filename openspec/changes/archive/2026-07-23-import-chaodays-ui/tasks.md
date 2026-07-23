# Tasks

## 1. Domain
- [ ] `contexts/import/domain/`: `ImportRepository` port (4 methods), `ChaodaysImportSummary`,
      typed exceptions (fetch / reauth / chaodays-auth-failed / chaodays-unavailable).

## 2. Infrastructure (TDD, mock http.Client)
- [ ] Test `HttpImportRepository` (仿 http_bowel test): each method POSTs the right
      endpoint + Bearer + snake_case body; 401→reauth, 400 chaodays_auth_failed→auth-failed,
      502→unavailable, other non-200→fetch-failure; parses summary.
- [ ] `HttpImportRepository`.

## 3. Presentation controller (TDD)
- [ ] Test `ChaodaysImportController` (fake ImportRepository): runs 4 sequentially;
      per-type notAttempted→importing→success/failed; success summaries; **auth-failed
      aborts with remaining types still notAttempted (not failed), status=authFailed**;
      unavailable → status=unavailable; lifeos 401 → status=needsReauth. Controller
      takes no storage dependency.
- [ ] `ChaodaysImportController` (states per design).

## 4. Screen + i18n (TDD widget) [needs_uiux]
- [ ] i18n strings (en + zh-Hant + zh) for title, fields, button, per-type labels,
      error copy, credentials note; `flutter gen-l10n`.
- [ ] `ChaodaysImportScreen`: account/password fields, start/end date pickers, gated
      import button, per-type progress/results, localized errors + credentials note.
- [ ] Widget tests: fields present; button disabled until complete then enabled;
      submit calls import + shows loading; success shows per-type numbers; wrong
      credentials shows the specific message.

## 5. Entry + routing + DI [needs_uiux]
- [ ] `_MoreBody` import card → `onOpenImport` → `context.push('/import/chaodays')`;
      nav test via `l10nRouterTestApp`.
- [ ] `app.dart` GoRoute `/import/chaodays` (DI-built) + `onOpenImport` wiring;
      `main.dart` builds repo/use cases/controller into `App`.

## 6. Gate
- [ ] `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test` green.
