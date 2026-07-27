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
var PENDING_CACHE_NAME = 'lifeos-deeplink';
var PENDING_CACHE_KEY = '/pending';

self.addEventListener('push', function (event) {
  var data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (e) {
    data = {};
  }
  var title = data.title || 'LifeOS';
  // No explicit path from the backend yet (reminders are all care reminders
  // today), so default to the Today care checklist — the place to act on it,
  // not the app root. A router *path* (design D2), never a hash URL: the
  // notificationclick handler writes this straight into the Cache hand-over,
  // and a hash form there would match no route (design D9).
  event.waitUntil(
    self.registration.showNotification(title, {
      body: data.body || '',
      data: { path: data.path || '/care-today' },
    })
  );
});

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  var path = (event.notification.data && event.notification.data.path) || '/care-today';

  event.waitUntil(
    (async function () {
      // Write the hand-over before touching any window — a window opened or
      // focused before the write lands could read an empty Cache (design D3).
      // Best-effort: a rejected open/put (quota, blocked site data, private
      // mode) must NOT abort this handler, or the tap would neither focus nor
      // open anything. Falling through leaves the app to open with nothing
      // pending — the documented degradation, "stops at the home screen"
      // (design D9) — instead of doing nothing at all.
      try {
        var cache = await caches.open(PENDING_CACHE_NAME);
        await cache.put(
          PENDING_CACHE_KEY,
          new Response(JSON.stringify({ path: path, savedAt: Date.now() }))
        );
      } catch (e) {
        // Ignored on purpose; see above.
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
