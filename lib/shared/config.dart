/// Backend base URL, injected via `--dart-define=API_BASE_URL=...`.
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://life-os-backend.playground-92f.workers.dev',
);

/// Origin of the deployed web app, used to build links that are meant to be
/// opened in a browser (the friends invite link). On the web the running
/// origin is authoritative and this is only the non-web fallback: on the Dart
/// VM / a native build `Uri.base` is a `file://` URI and `Uri.base.origin`
/// throws `StateError`, so a link built from it would crash the page.
/// Injected via `--dart-define=APP_WEB_ORIGIN=...`.
const appWebOrigin = String.fromEnvironment(
  'APP_WEB_ORIGIN',
  defaultValue: 'https://life-os-6oo.pages.dev',
);
