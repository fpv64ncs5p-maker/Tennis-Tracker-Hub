// Training Hub service worker (2026-11-14)
// Keeps a copy of the app on the phone so it opens with no connection.
// - The app page: network first (so updates arrive), falls back to the saved
//   copy when offline or when the network takes longer than 4 s (bad gym signal).
// - Icons / manifest: saved copy first.
// - Supabase and any other site: never touched (always live network).
// Your data is NOT stored here — it lives in localStorage, as before.
const CACHE = 'training-hub-v1';
const CORE = ['./', './index.html', './manifest.json', './icon.png', './icon-512.png'];
const TIMEOUT_MS = 4000;

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE)
      .then(c => c.addAll(CORE.map(u => new Request(u, { cache: 'reload' }))))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

function isPage(req) {
  const p = new URL(req.url).pathname;
  return req.mode === 'navigate' || p.endsWith('/') || p.endsWith('/index.html');
}

async function pageNetworkFirst(req) {
  const cache = await caches.open(CACHE);
  const net = fetch(req).then(res => {
    if (res && res.ok) cache.put('./index.html', res.clone());
    return res;
  });
  const timeout = new Promise(r => setTimeout(() => r(null), TIMEOUT_MS));
  try {
    const res = await Promise.race([net, timeout]);
    if (res) return res;
  } catch (err) { /* offline */ }
  const cached = await cache.match('./index.html');
  if (cached) return cached;
  return net; // nothing saved yet: wait for the network
}

async function assetCacheFirst(req) {
  const cache = await caches.open(CACHE);
  const cached = await cache.match(req, { ignoreSearch: true });
  if (cached) return cached;
  const res = await fetch(req);
  if (res && res.ok) cache.put(req, res.clone());
  return res;
}

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  if (new URL(req.url).origin !== self.location.origin) return; // Supabase etc.
  e.respondWith(isPage(req) ? pageNetworkFirst(req) : assetCacheFirst(req));
});
