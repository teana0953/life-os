# ci-cd — Delta Spec

## ADDED Requirements

### Requirement: Continuous integration on proposed changes
The system SHALL run static analysis, the test suite, and a web build automatically on every pull request and on pushes to non-default branches, and MUST fail the workflow if any of them fails.

#### Scenario: Passing branch
- **WHEN** a pull request is opened or updated and `flutter analyze`, `flutter test`, and `flutter build web` all succeed
- **THEN** the CI workflow completes successfully

#### Scenario: Failing analysis or tests blocks the branch
- **WHEN** a pull request contains code where `flutter analyze` or `flutter test` fails
- **THEN** the CI workflow fails and reports the failure on the pull request

### Requirement: Automatic deployment to Cloudflare Pages
The system SHALL, on every push to the default branch (`main`), build the Flutter web app with the backend base URL injected and deploy the build output to Cloudflare Pages.

#### Scenario: Successful delivery
- **WHEN** a commit is pushed to `main` and the web build succeeds
- **THEN** the CD workflow deploys `build/web` to the Cloudflare Pages project using the configured API token

#### Scenario: Build failure aborts deploy
- **WHEN** a commit is pushed to `main` and `flutter build web` fails
- **THEN** the CD workflow stops and does not deploy

### Requirement: Account inferred from API token
The CD workflow SHALL authenticate to Cloudflare with an API token and SHALL NOT require a separately configured account id (the account is determined by the token).

#### Scenario: Deploy authentication
- **WHEN** the CD workflow deploys to Pages
- **THEN** it authenticates with `CLOUDFLARE_API_TOKEN` and targets the token's account without an account-id input

### Requirement: Workflow definitions are statically validated
The repository's GitHub Actions workflow files SHALL pass `actionlint` static validation as part of the project's quality gate.

#### Scenario: Malformed workflow caught before merge
- **WHEN** a workflow YAML contains an invalid expression or key
- **THEN** the `actionlint` gate fails
