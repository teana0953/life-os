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
      var cache = await caches.open(PENDING_CACHE_NAME);
      await cache.put(
        PENDING_CACHE_KEY,
        new Response(JSON.stringify({ path: path, savedAt: Date.now() }))
      );

      // `includeUncontrolled: true` makes this visible by *origin*, not
      // scope — a `/push/`-scoped worker CAN see `/`-scope app windows with
      // this flag set.
      var allClients = await clients.matchAll({
        type: 'window',
        includeUncontrolled: true,
      });
      var target = allClients.find(function (c) { return c.focused; }) || allClients[0];

      if (target) {
        // Focus only — never navigate() here. Navigating would replace the
        // user's current page stack with a URL-driven rebuild, which is
        // exactly the "no back arrow" bug this design fixes (design D3/D5);
        // the app itself does the `push` navigation once it reads the Cache.
        try {
          await target.focus();
          // The window is already open, so a lifecycle `resumed` transition
          // may never fire (e.g. a foregrounded heads-up notification) — this
          // signal is the only thing that wakes it up to read the Cache. No
          // destination is sent: Cache stays the single source of truth
          // (design D4). Sent only after focus() succeeds — sending it first
          // would race a fallback openWindow() into reading an already-
          // consumed (or about-to-be-consumed) Cache entry (design D3).
          target.postMessage({});
        } catch (e) {
          // focus() rejected (missing user activation, unfocusable client,
          // Android version differences) — fall back to opening a window,
          // and do NOT signal, or the fallback races a background consumer.
          await clients.openWindow('/');
        }
      } else {
        await clients.openWindow('/');
      }
    })()
  );
});
