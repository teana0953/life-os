// Web Push service worker. Registered by BrowserWebPushGateway at a
// separate scope (`/push/`) so it never replaces Flutter's own `/`-scope
// service worker (flutter_service_worker.js) — see design D2.

// Activate immediately on first install so `pushManager.subscribe` (which needs
// an active worker) doesn't fail on the very first "enable" tap.
self.addEventListener('install', function () {
  self.skipWaiting();
});
self.addEventListener('activate', function (event) {
  event.waitUntil(self.clients.claim());
});

// Cache Storage hand-over contract (design D2) — SINGLE source of truth
// shared with lib/shared/pwa/pending_deep_link_web.dart. Do not change one
// side without the other.
//
// The chain, end to end:
//   push               → showNotification(title, { data: { path } })
//                        `data` has NO `path` when the payload carried no
//                        destination — see destinationOf() below.
//   notificationclick  → reads that notification's own `data.path`, and only
//                        when there is one writes
//                        {path, savedAt} to PENDING_CACHE_KEY; then focuses an
//                        existing window (or opens one) either way.
//   the app            → reads and deletes the entry, and navigates only if
//                        the running version has a screen for that path.
// The app deliberately outlives this worker's updates in both directions, so
// a path written by one version may be unknown to the other: that is ignored,
// never an error page.
var PENDING_CACHE_NAME = 'lifeos-deeplink';
var PENDING_CACHE_KEY = '/pending';

// The backend origin is not knowable from inside this file: it is served from
// the Pages origin while the API lives on another, and a static worker has no
// build-time substitution. It arrives as a query on the registration script
// URL, written by `pushSwScriptUrl` in
// lib/contexts/notifications/infrastructure/push_sw_url.dart — the parameter
// name is a two-language contract, guarded by push_sw_ack_contract_test.dart.
//
// Registering a *different script URL* at the same scope neither creates a
// second registration nor invalidates the existing push subscription: the
// registration map is keyed by (storage key, scope url), so Register falls
// through to Update on the existing registration (ServiceWorker spec), and a
// subscription is bound to the registration's scope (Push API spec). Only
// `unregister()` destroys it — see web/index.html.
//
// Returns null when the query is absent (an app version registered before this
// existed): the push handler then shows the notification and sends nothing.
function ackEndpoint() {
  try {
    var base = new URL(self.location.href).searchParams.get('api');
    if (!base) return null;
    return base + '/api/push/ack';
  } catch (e) {
    return null;
  }
}

// The destination a notification carries, or null when it carries none.
//
// A router *path* (design D2), never a hash URL: `notificationclick` writes
// this straight into the Cache hand-over, and a hash form there would match
// no route (design D9). Anything that is not a root-relative path is treated
// as no destination — the app would refuse it anyway.
//
// TRANSITIONAL (design D1): the backend does not send `path` yet, so care
// reminders are recognized by the field it *does* send — only they carry an
// `ack` token (backend design D6; test pushes and budget alerts carry none),
// which is exactly the distinction this needs. Delete this branch, its
// constant, and the contract assertion pinning it once the backend sends
// `path`. The token itself is only read here, never copied into the
// notification.
var CARE_DESTINATION = '/care-today';

function destinationOf(data) {
  if (typeof data.path === 'string' && data.path.charAt(0) === '/') {
    return data.path;
  }
  if (data.data && data.data.ack) return CARE_DESTINATION;
  return null;
}

self.addEventListener('push', function (event) {
  var data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (e) {
    data = {};
  }
  var title = data.title || 'LifeOS';
  var path = destinationOf(data);
  event.waitUntil(
    self.registration.showNotification(title, {
      body: data.body || '',
      // The ack token must NEVER be copied in here. This object is persisted with
      // the notification and read back by `notificationclick` long after this
      // handler is gone, while the ack token is a bearer capability the
      // backend deliberately keeps out of URLs and logs (backend design D1).
      //
      // No `path` key at all when this notification has no destination of its
      // own. This worker serves EVERY push type — care reminders, budget
      // alerts, test pushes — so a blanket default sent all of them to the
      // care checklist, a page unrelated to what most of them said
      // (issue #193). Absent means absent.
      data: path ? { path: path } : {},
    })
  );

  // Delivery receipt (backend design D1/D2), in its own `waitUntil` AFTER the
  // notification: a failed ack must never cost the user the notification. A
  // payload with no `ack` is normal, not an error — test pushes and budget
  // alerts carry none (design D6).
  // The wire payload is `{title, body, data: {ack}}` (backend design D2,
  // web-push-sender.ts) — the token sits one level in, NOT beside `title`.
  var ackToken = data.data && data.data.ack;
  var endpoint = ackEndpoint();
  if (ackToken && endpoint) {
    event.waitUntil(
      // `Promise.resolve().then` so a *synchronous* throw from fetch becomes a
      // rejection the `catch` below absorbs, instead of escaping the handler
      // after the notification was already queued.
      Promise.resolve()
        .then(function () {
          return fetch(endpoint, {
            method: 'POST',
            // `text/plain`, not the contract's `application/json`: it is
            // CORS-safelisted (Fetch 2.2.2), so this stays a *simple* request
            // and no preflight is sent. The bytes on the wire are unchanged —
            // the handler never reads Content-Type — but the ack stops
            // depending on the backend's ALLOWED_WEB_ORIGIN listing whichever
            // origin this build is served from. Measured: from a
            // non-allowlisted origin (every Pages preview deployment is one) a
            // preflight returns no ACAO and the POST never leaves the browser,
            // while a simple POST still reaches the handler.
            // No `Authorization` header, per design D1 — and it is not
            // safelisted either, so adding one would bring the preflight back.
            headers: { 'Content-Type': 'text/plain' },
            body: JSON.stringify({ ack: ackToken }),
          });
        })
        // The response is always 204 with an empty body, so there is nothing
        // to branch on, and nothing is retried: `expires_at` has no grace
        // (design D4), so a queued retry would land outside the window the
        // backend accepts. The catch exists only so a rejection is not an
        // unhandled one.
        .catch(function () {})
    );
  }
});

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  var path = event.notification.data && event.notification.data.path;

  event.waitUntil(
    (async function () {
      // Write the hand-over before touching any window — a window opened or
      // focused before the write lands could read an empty Cache (design D3).
      // Best-effort: a rejected open/put (quota, blocked site data, private
      // mode) must NOT abort this handler, or the tap would neither focus nor
      // open anything. Falling through leaves the app to open with nothing
      // pending — the documented degradation, "stops at the home screen"
      // (design D9) — instead of doing nothing at all.
      //
      // Nothing is written when this notification carried no destination
      // (design D1): the tap still brings the app to the foreground below,
      // and the app stays wherever it normally opens. Guessing one here would
      // put the knowledge of "what this notification is about" in a second
      // place — the payload is the only source of it.
      if (typeof path === 'string' && path) {
        try {
          var cache = await caches.open(PENDING_CACHE_NAME);
          await cache.put(
            PENDING_CACHE_KEY,
            new Response(JSON.stringify({ path: path, savedAt: Date.now() }))
          );
        } catch (e) {
          // Ignored on purpose; see above.
        }
      }

      // `includeUncontrolled: true` makes this visible by *origin*, not
      // scope — a `/push/`-scoped worker CAN see `/`-scope app windows with
      // this flag set.
      // Best-effort for the same reason as the Cache write above: a rejected
      // matchAll must not abort the handler, or the tap would neither focus
      // nor open anything. Treating it as "no windows" falls through to
      // openWindow, so a tap always opens the app.
      var allClients = [];
      try {
        allClients = await clients.matchAll({
          type: 'window',
          includeUncontrolled: true,
        });
      } catch (e) {
        // Ignored on purpose; see above.
      }
      var target = allClients.find(function (c) { return c.focused; }) || allClients[0];

      // Focus only — never navigate() here. Navigating would replace the
      // user's current page stack with a URL-driven rebuild, which is
      // exactly the "no back arrow" bug this design fixes (design D3/D5);
      // the app itself does the `push` navigation once it reads the Cache.
      // The try covers focus() ONLY: a throwing postMessage inside it would
      // run the openWindow fallback on top of a window that was in fact
      // focused, leaving two windows racing for one Cache entry.
      var focused = false;
      if (target) {
        try {
          await target.focus();
          focused = true;
        } catch (e) {
          // focus() rejected (missing user activation, unfocusable client,
          // Android version differences) — fall through to opening a window,
          // and do NOT signal, or the fallback races a background consumer.
        }
      }

      if (focused) {
        // The window is already open, so a lifecycle `resumed` transition
        // may never fire (e.g. a foregrounded heads-up notification) — this
        // signal is the only thing that wakes it up to read the Cache. No
        // destination is sent: Cache stays the single source of truth
        // (design D4). Sent only after focus() succeeds — sending it first
        // would race a fallback openWindow() into reading an already-
        // consumed (or about-to-be-consumed) Cache entry (design D3).
        target.postMessage({});
      } else {
        await clients.openWindow('/');
      }
    })()
  );
});
