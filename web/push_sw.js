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

self.addEventListener('push', function (event) {
  var data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (e) {
    data = {};
  }
  var title = data.title || 'LifeOS';
  // The app never calls usePathUrlStrategy(), so go_router stays on its
  // default hash strategy (routes live at '/#/...') — a bare '/care-today'
  // has no hash fragment and falls back to the app root. No explicit url
  // from the backend yet (reminders are all care reminders today), so
  // default to the Today care checklist — the place to act on it, not the
  // app root.
  event.waitUntil(
    self.registration.showNotification(title, {
      body: data.body || '',
      data: { url: data.url || '/#/care-today' },
    })
  );
});

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  // A `/push/`-scoped worker can't focus an existing `/`-scope app tab
  // (clients.matchAll only sees clients within this registration's scope),
  // so just open the target url — may open a new tab (design D6a).
  var url = (event.notification.data && event.notification.data.url) || '/#/care-today';
  event.waitUntil(clients.openWindow(url));
});
