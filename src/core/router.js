import { store } from './store.js';
import { esc } from './text.js';

const routes = {};

/**
 * Monotonic render token.
 *
 * Route handlers are async — they fetch before they mount. Without a token, a
 * handler that resolves late (slow API, fast user) overwrites whatever the
 * newer navigation already put on screen: you can land on `#/login` while
 * looking at the previous page's markup. Every render claims a sequence number
 * and only writes to the DOM if it still owns it.
 */
let renderSeq = 0;
let lastRenderedPath = null;

export function register(path, handler, cap = null) {
  routes[path] = { handler, cap };
}

export function navigate(path) {
  if (location.hash !== '#' + path) {
    location.hash = path;
  } else {
    render();
  }
}

export function currentPath() {
  const h = location.hash.replace(/^#/, '') || '/';
  return h.split('?')[0] || '/';
}

async function render() {
  const seq = ++renderSeq;
  const path = currentPath();
  const app = document.getElementById('app');
  const route = routes[path] || routes['/404'] || routes['/'];
  if (!route) return;

  if (path !== '/login' && path !== '/set-password' && path !== '/verify-email' && !store.user) {
    if (path === '/room' && /^\/room\?code=[a-f0-9]{32}$/.test(location.hash.slice(1))) {
      sessionStorage.setItem('postLoginRoom', location.hash.slice(1));
    }
    location.hash = '#/login';
    return;
  }
  if (store.user?.must_change_password && path !== '/settings' && path !== '/set-password' && path !== '/verify-email' && path !== '/login') {
    location.hash = '#/settings';
    return;
  }
  // Client-side guard: mirror the server-side capability so users never land
  // on a page whose data they are not allowed to see.
  if (route.cap && !store.hasCap(route.cap)) {
    if (path !== '/dashboard') {
      location.hash = '#/dashboard';
      return;
    }
  }

  if (path !== lastRenderedPath) window.scrollTo(0, 0);
  app.innerHTML = '<div style="padding:40px;text-align:center"><span class="spinner"></span></div>';

  // The handler renders into a detached staging node, so a stale resolution
  // costs nothing — it never touches the live DOM in the first place.
  const stage = document.createElement('div');
  try {
    await route.handler(stage);
  } catch (e) {
    if (seq !== renderSeq) return;
    app.innerHTML = `<div class="empty">Error: ${esc(e.message || 'Could not load this page.')}</div>`;
    return;
  }

  if (seq !== renderSeq) return;   // a newer navigation owns the view now
  app.innerHTML = '';
  while (stage.firstChild) app.appendChild(stage.firstChild);
  document.dispatchEvent(new Event('faculty-monitor:mounted'));
  if (path !== lastRenderedPath) window.scrollTo(0, 0);
  lastRenderedPath = path;
}

export function startRouter() {
  window.addEventListener('hashchange', render);
  render();
}
