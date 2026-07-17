/// Backend base URL, injected via `--dart-define=API_BASE_URL=...`.
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://life-os-backend.playground-92f.workers.dev',
);
