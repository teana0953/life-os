/// Backend base URL, injected via `--dart-define=API_BASE_URL=...`.
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://life-os-backend.playground-92f.workers.dev',
);

/// Wall-clock bound on an ordinary backend request, body included.
///
/// **Modeled, not measured.** This is not a p95/p99 taken from production —
/// the request-duration distribution for the 2026-08-17 incident could not be
/// retrieved from the Cloudflare dashboard, so nobody has the real numbers
/// yet. The derivation instead: the backend retries a failing query on a
/// 0/200/600ms schedule with ~25% jitter, so one degraded query costs up to
/// ~1s extra; an endpoint doing up to four of them is ~4s of server time; add
/// Neon's compute cold start (free-tier compute suspends when idle) plus TLS
/// and mobile RTT and a worst case that *still succeeds* lands around 5-6s.
/// 15s is roughly 3x that, which is headroom rather than a measurement.
/// Replace it with a real percentile once Workers Logs has one.
const httpRequestTimeout = Duration(seconds: 15);

/// The bound for the two calls whose duration is not the backend's to control:
/// the AI assistant (contains a Gemini generation) and the chaodays bulk
/// import (can post a year of records in one request). 15s would break both
/// while they are working normally.
///
/// This number is a hang ceiling, not a measured p99 — its only job is to stop
/// an unbounded wait. Nothing is meant to run anywhere near it.
const longRunningHttpTimeout = Duration(seconds: 120);

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
