// Runs the REAL web/push_sw.js inside a faked service worker global and
// dispatches one synthetic `push` (or `notificationclick`) event, reporting
// every observed call.
//
// Why a harness at all: the properties that matter here are runtime
// behaviours — "the notification still shows when the ack fetch throws", "no
// request is sent when the payload carries no token". A `contains()` assertion
// over the file's text cannot fail on any of them, which would make the guard
// an impossible-to-fail one.
//
// Driven by test/shared/pwa/push_sw_ack_contract_test.dart, which passes one
// JSON scenario as argv[2] and parses the JSON written to stdout.
//
// Scenario fields:
//   swPath      path to the worker source (lets a test run a mutated copy)
//   search      the script URL's query string, e.g. "?api=https://api.test"
//   payload     object returned by event.data.json(), or null for no data
//   payloadThrows  make event.data.json() throw (undecodable payload)
//   fetchMode   "success" | "throw" | "reject" | "pending"
//   dispatch    "push" (default) | "notificationclick"
//   notification  for dispatch "notificationclick": the `data` object the
//               notification was shown with (what the push handler stored)
//   windows     for dispatch "notificationclick": number of existing app
//               windows visible to clients.matchAll
//
// Output: { calls: [{seq, kind, ...}], waitUntilStates: [...], escaped }
// `seq` is a single monotonic counter across ALL call kinds, so it pins the
// ORDER of showNotification against fetch, not merely their presence.

import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const scenario = JSON.parse(process.argv[2]);
const swPath = scenario.swPath ?? 'web/push_sw.js';
const source = readFileSync(swPath, 'utf8');

const calls = [];
let seq = 0;
const record = (kind, detail) => calls.push({ seq: seq++, kind, ...detail });

const listeners = {};
const waitUntilPromises = [];
const search = scenario.search ?? '';

const openWindows = [];
for (let i = 0; i < (scenario.windows ?? 0); i++) {
  openWindows.push({
    focused: i === 0,
    focus() {
      record('focus', {});
      return Promise.resolve();
    },
    postMessage(message) {
      record('postMessage', { message });
    },
  });
}

const cacheStore = {
  put(key, response) {
    record('cachePut', { key, body: response.body });
    return Promise.resolve();
  },
};

// The worker wraps its hand-over in `new Response(...)`; `Response` is a host
// API a fresh vm realm does not have, and its absence would surface as the
// worker's own best-effort catch swallowing the write — a cachePut that
// silently never happens, which is exactly what these tests must be able to
// see.
class FakeResponse {
  constructor(body) {
    this.body = body;
  }
}

const self = {
  location: {
    href: 'https://app.example/push_sw.js' + search,
    search,
    origin: 'https://app.example',
  },
  addEventListener(type, handler) {
    listeners[type] = handler;
  },
  skipWaiting() {},
  registration: {
    showNotification(title, options) {
      record('showNotification', { title, options });
      return Promise.resolve();
    },
  },
  clients: {
    claim: () => Promise.resolve(),
    matchAll: () => Promise.resolve(openWindows),
    openWindow: (url) => {
      record('openWindow', { url });
      return Promise.resolve(null);
    },
  },
};

function fetchStub(url, init) {
  record('fetch', {
    url,
    method: init?.method ?? null,
    headers: init?.headers ?? null,
    body: init?.body ?? null,
  });
  switch (scenario.fetchMode) {
    // A synchronous throw is a real fetch failure mode (an invalid URL), and
    // it is the one that would swallow the notification if the ack ran first.
    case 'throw':
      throw new Error('synchronous fetch failure');
    case 'reject':
      return Promise.reject(new Error('network failure'));
    case 'pending':
      return new Promise(() => {});
    default:
      return Promise.resolve({ status: 204, ok: true });
  }
}

// `URL` is a host API, not part of a fresh vm realm's globals, so it has to be
// handed in explicitly.
const sandbox = {
  self,
  URL,
  Response: FakeResponse,
  fetch: fetchStub,
  clients: self.clients,
  caches: {
    open: (name) => {
      record('cacheOpen', { name });
      return Promise.resolve(cacheStore);
    },
  },
};
vm.createContext(sandbox);
vm.runInContext(source, sandbox, { filename: swPath });

const pushEvent = {
  data: (scenario.payload === undefined || scenario.payload === null) &&
    !scenario.payloadThrows
    ? null
    : {
        json() {
          if (scenario.payloadThrows) throw new Error('undecodable payload');
          return scenario.payload;
        },
      },
  waitUntil(promise) {
    record('waitUntil', {});
    waitUntilPromises.push(promise);
  },
};

const clickEvent = {
  notification: {
    data: scenario.notification ?? {},
    close() {
      record('close', {});
    },
  },
  waitUntil: pushEvent.waitUntil,
};

let escaped = null;
try {
  if (scenario.dispatch === 'notificationclick') {
    listeners.notificationclick(clickEvent);
  } else {
    listeners.push(pushEvent);
  }
} catch (error) {
  escaped = String(error?.message ?? error);
}

// The click handler's work is all inside its `waitUntil` promise, so the
// observations below only exist once it has settled.
await Promise.all(
  waitUntilPromises.map((promise) =>
    Promise.race([
      Promise.resolve(promise).catch(() => {}),
      new Promise((resolve) => setTimeout(resolve, 50)),
    ]),
  ),
);

// "pending" never settles by design, so each promise races a short timer:
// the state itself is the observation.
const waitUntilStates = await Promise.all(
  waitUntilPromises.map((promise) =>
    Promise.race([
      Promise.resolve(promise).then(
        () => 'fulfilled',
        () => 'rejected',
      ),
      new Promise((resolve) => setTimeout(() => resolve('pending'), 50)),
    ]),
  ),
);

process.stdout.write(JSON.stringify({ calls, waitUntilStates, escaped }));
