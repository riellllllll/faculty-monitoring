import { api } from '../core/api.js';
import { navigate } from '../core/router.js';
import { store } from '../core/store.js';
import { esc } from '../core/text.js';
import { icon } from './icons.js';

let armed = false;
let unreadCount = 0;
let items = [];
let loadedFor = null;

function badge() {
  document.querySelectorAll('.notification-count').forEach(node => {
    node.textContent = unreadCount > 99 ? '99+' : String(unreadCount);
    node.hidden = unreadCount === 0;
  });
}

function timeLabel(value) {
  const date = new Date(String(value).replace(' ', 'T'));
  return Number.isNaN(date.getTime()) ? String(value) : new Intl.DateTimeFormat(undefined, {
    month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit',
  }).format(date);
}

function draw() {
  badge();
  const panel = document.querySelector('.notification-panel');
  if (!panel) return;
  const list = panel.querySelector('.notification-list');
  list.innerHTML = items.length ? items.map(item => `
    <button type="button" class="notification-item ${Number(item.is_read) ? '' : 'unread'}" data-notification-id="${Number(item.id)}">
      <span class="notification-item-top"><strong>${esc(item.title)}</strong><time>${esc(timeLabel(item.created_at))}</time></span>
      <span class="notification-body">${esc(item.body)}</span>
    </button>`).join('') : '<p class="notification-empty">No notifications yet.</p>';
  panel.querySelector('.notification-read-all').hidden = unreadCount === 0;
}

async function refresh() {
  const userId = store.user?.id;
  if (!userId) return;
  try {
    const { data } = await api.get('/api/notifications');
    if (store.user?.id !== userId) return;
    items = data.items || [];
    unreadCount = Number(data.unread_count || 0);
    loadedFor = userId;
    draw();
  } catch (error) {
    const message = document.querySelector('.notification-list');
    if (message && document.querySelector('.notification[data-open="true"]')) {
      message.innerHTML = `<p class="notification-empty">${esc(error.message || 'Could not load notifications.')}</p>`;
    }
  }
}

function close() {
  document.querySelectorAll('.notification[data-open="true"]').forEach(root => {
    root.dataset.open = 'false';
    root.querySelector('.notification-button')?.setAttribute('aria-expanded', 'false');
  });
}

function arm() {
  if (armed || typeof document === 'undefined') return;
  armed = true;
  document.addEventListener('click', async event => {
    const root = event.target.closest?.('.notification');
    if (!root) { close(); return; }
    if (event.target.closest('.notification-button')) {
      const opening = root.dataset.open !== 'true';
      close();
      root.dataset.open = opening ? 'true' : 'false';
      root.querySelector('.notification-button')?.setAttribute('aria-expanded', String(opening));
      if (opening) refresh();
      return;
    }
    if (event.target.closest('.notification-read-all')) {
      try { await api.post('/api/notifications/read-all', {}); await refresh(); } catch (error) { refresh(); }
      return;
    }
    const itemButton = event.target.closest('.notification-item');
    if (!itemButton) return;
    const item = items.find(row => Number(row.id) === Number(itemButton.dataset.notificationId));
    if (!item) return;
    try { await api.post(`/api/notifications/${Number(item.id)}/read`, {}); await refresh(); } catch (error) { return; }
    close();
    if (typeof item.link === 'string' && /^\/schedules\?faculty=\d+(&term=\d+)?$/.test(item.link)) navigate(item.link);
  });
  document.addEventListener('keydown', event => { if (event.key === 'Escape') close(); });
  setInterval(() => {
    if (document.visibilityState === 'visible' && document.querySelector('.notification')) refresh();
  }, 60000);
}

export function renderNotifications() {
  arm();
  const userId = store.user?.id;
  if (loadedFor !== userId) { items = []; unreadCount = 0; loadedFor = null; }
  setTimeout(refresh, 0);
  return `<div class="notification" data-open="false">
    <button class="notification-button" type="button" aria-label="Notifications" aria-expanded="false" aria-controls="notificationPanel">
      ${icon('bell', 18)}<span class="notification-count" ${unreadCount ? '' : 'hidden'}>${unreadCount > 99 ? '99+' : unreadCount}</span>
    </button>
    <section class="notification-panel" id="notificationPanel" aria-label="Notifications">
      <div class="notification-panel-head"><h2>Notifications</h2><button type="button" class="notification-read-all" ${unreadCount ? '' : 'hidden'}>Mark all read</button></div>
      <div class="notification-list"><p class="notification-empty">${items.length ? 'Loading…' : 'No notifications yet.'}</p></div>
    </section>
  </div>`;
}
