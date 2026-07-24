// Web Push service worker. Registered by BrowserWebPushGateway at a
// separate scope (`/push/`) so it never replaces Flutter's own `/`-scope
// service worker (flutter_service_worker.js) — see design D2.

self.addEventListener('push', function (event) {
  var data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (e) {
    data = {};
  }
  var title = data.title || 'LifeOS';
  event.waitUntil(
    self.registration.showNotification(title, { body: data.body || '' })
  );
});

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  // A `/push/`-scoped worker can't focus an existing `/`-scope app tab
  // (clients.matchAll only sees clients within this registration's scope),
  // so just open the app root — may open a new tab (design D6a).
  event.waitUntil(clients.openWindow('/'));
});
