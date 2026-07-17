# life-os

Flutter frontend for Life OS. Minimal login skeleton: Firebase email/password
sign-in → fetch the user's profile from the backend `GET /api/me` → display
it. See `CLAUDE.md` for architecture conventions.

Targets Flutter Web (Chrome) first; the code stays cross-platform.

## Prerequisites (do this before running the app)

1. **Register a Firebase Web app and generate config**: in your Firebase
   project, add a Web app, then run `flutterfire configure` in this
   directory. It overwrites `lib/firebase_options.dart` with your project's
   real values (this file is committed — Firebase web config is a public
   client identifier, not a secret).
2. **Enable Email/Password sign-in**: Firebase Console → Authentication →
   Sign-in method → enable Email/Password.
3. **Create a test user**: Firebase Console → Authentication → Users → add
   an email/password account to sign in with.

## Running

```
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=https://life-os-backend.playground-92f.workers.dev
```

`API_BASE_URL` defaults to the URL above if omitted; pass a different value
(e.g. a local backend) to override it.

## Testing

```
flutter analyze
flutter test
```

Tests inject fake `AuthRepository`/`ProfileRepository` implementations and
never call `Firebase.initializeApp` or perform real network requests.

## CI/CD

GitHub Actions runs two workflows:

- **CI** (`.github/workflows/ci.yml`) — on every pull request and every push
  to a branch other than `main`: `flutter pub get`, `flutter analyze`,
  `flutter test`, `flutter build web`. A failing analyze, test, or build
  fails the run.
- **Deploy** (`.github/workflows/deploy.yml`) — on every push to `main`:
  builds the web app with the backend URL injected
  (`flutter build web --dart-define=API_BASE_URL=...`), then deploys
  `build/web` to Cloudflare Pages with `cloudflare/wrangler-action`
  (`pages deploy build/web --project-name=life-os`). A failing build aborts
  before the deploy step runs. Workflow YAML is checked with `actionlint`
  (`./scripts/lint-actions.sh`) as part of the quality gate.

### Required GitHub configuration

Set these under the repo's **Settings → Secrets and variables → Actions**:

**Secrets** (tab: Secrets):

| Secret | Used for |
|---|---|
| `CLOUDFLARE_API_TOKEN` | Deploy authentication (Cloudflare dashboard → API Tokens → needs Pages:Edit). Must be scoped to a **single** Cloudflare account — the Pages project's account is inferred from this token (no separate account-id input), and a token that can see multiple accounts makes the non-interactive deploy fail with "More than one account". |

**Variables** (tab: Variables):

| Variable | Used for |
|---|---|
| `API_BASE_URL` | Backend URL injected into the web build (e.g. `https://life-os-backend.playground-92f.workers.dev`). Not a secret — it's a public URL baked into the client bundle. |

The Cloudflare Pages project (`life-os`) must exist before the first deploy
— create it in the Cloudflare dashboard, or run `wrangler pages deploy`
locally once to create it, matching `--project-name=life-os`.

### Prerequisites for login to work after deploy

Deploying doesn't require these, but login on the deployed Pages site will
fail without both:

1. **Backend CORS**: set the backend's `ALLOWED_WEB_ORIGIN` to the deployed
   Pages URL, so the backend's CORS allow-list accepts requests from it.
2. **Firebase Authorized domains**: Firebase Console → Authentication →
   Settings → Authorized domains → add the Pages domain. Without this,
   Firebase rejects sign-in from the deployed origin.
