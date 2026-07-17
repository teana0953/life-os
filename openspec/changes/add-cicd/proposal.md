# Proposal: add-cicd (frontend)

## Why

The Flutter login skeleton is on main but has no automated quality gate or delivery — every change is analyzed, tested, and deployed by hand. A GitHub Actions pipeline guards pull requests (analyze + test + web build) and delivers the web app automatically to Cloudflare Pages on merge, matching the backend's already-working CI/CD.

## What Changes

- Add CI workflow (`ci.yml`): on PRs and non-`main` pushes run `flutter analyze`, `flutter test`, and `flutter build web`.
- Add CD workflow (`deploy.yml`): on push to `main`, build web with the backend URL injected and deploy `build/web` to Cloudflare Pages via `cloudflare/wrangler-action` (`pages deploy`); the account is inferred from the API token.
- Add `actionlint` to the quality gate; document required GitHub secret/variable and the Pages project in the README.

## Capabilities

### New Capabilities

- `ci-cd`: continuous integration (analyze + test + web build gate on PRs/pushes) and continuous delivery (build + deploy the Flutter web app to Cloudflare Pages on merge to main), with the Cloudflare account inferred from the API token.

### Modified Capabilities

(none — `login-flow` behavior is unchanged.)

## Impact

- **New**: `.github/workflows/{ci,deploy}.yml`, README CI/CD section, `actionlint` gate script.
- **External (user)**: GitHub secret `CLOUDFLARE_API_TOKEN` (Pages:Edit) and variable `API_BASE_URL`; a Cloudflare Pages project.
- **Backend prerequisite**: CORS must allow the deployed Pages origin — handled as a small `life-os-backend` change making the allowed production origin configurable via env.
- **Not affected**: app code (`lib/`), tests. Android/iOS packaging, Pages custom domain, and per-PR preview deploys are deferred.
