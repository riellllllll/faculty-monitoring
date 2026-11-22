import { store } from '../core/store.js';
import { api } from '../core/api.js';
import { toast } from './toast.js';
import { icon } from './icons.js';
import { esc, initials } from '../core/text.js';

/**
 * Account chip — the signed-in identity, always parked in the top-right of the
 * page header.
 *
 * The header used to say what page you were on but never who you were; the
 * only identity display lived in the sidebar footer. This chip answers that
 * at a glance (name + roles) and opens a menu with the full picture.
 *
 * Markup is emitted by renderAccount() through pageHead(); clicks are handled
 * by a single document-level delegate armed once, so re-rendering a route never
 * re-binds listeners and never leaves a stale one behind.
 */

export const roleLabels = {
  chairperson: 'Department Chairperson',
  program_coordinator: 'Program Coordinator',
  faculty: 'Faculty',
};

function identity() {
  const u = store.user || {};
  const name = [u.first_name, u.last_name].filter(Boolean).join(' ').trim() || u.email || 'Signed in';
  const roles = (u.roles || []).map(r => roleLabels[r] || r);
  return { u, name, roles, ini: initials(u.first_name, u.last_name) };
}

export function renderAccount() {
  armDelegate();
  const { u, name, roles, ini } = identity();
  const roleLine = roles.length ? roles.join(' · ') : 'Signed in';

  return `
    <div class="account" data-open="false">
      <button class="account-btn" type="button" aria-label="${esc(name)} account menu" aria-expanded="false" aria-controls="accountMenu">
        <span class="account-avatar">${esc(ini)}</span>
        <span class="account-id">
          <b>${esc(name)}</b>
          <small>${esc(roleLine)}</small>
        </span>
        <span class="ico account-caret">${icon('caretDown', 14)}</span>
      </button>

      <div class="account-menu" id="accountMenu" aria-label="Account">
        <div class="am-head">
          <span class="account-avatar lg">${esc(ini)}</span>
          <span class="am-head-text">
            <b>${esc(name)}</b>
            <small>${esc(u.email || '')}</small>
          </span>
        </div>

        <div class="am-section">
          <span class="am-label">Signed in as</span>
          <span class="am-pills">
            ${(roles.length ? roles : ['No role assigned']).map(r => `<span class="pill">${esc(r)}</span>`).join('')}
          </span>
        </div>

        <div class="am-group">
          <a class="am-item" href="#/settings">${icon('sliders', 15)}<span>Settings</span></a>
          <button class="am-item danger" type="button" data-action="logout">${icon('logOut', 15)}<span>Sign out</span></button>
        </div>
      </div>
    </div>
  `;
}

// --- one delegate for the lifetime of the document -------------------------

let armed = false;

function closeAll() {
  document.querySelectorAll('.account[data-open="true"]').forEach(acc => {
    acc.dataset.open = 'false';
    const btn = acc.querySelector('.account-btn');
    if (btn) btn.setAttribute('aria-expanded', 'false');
  });
}

function toggle(acc) {
  const willOpen = acc.dataset.open !== 'true';
  closeAll();
  if (!willOpen) return;
  acc.dataset.open = 'true';
  const btn = acc.querySelector('.account-btn');
  if (btn) btn.setAttribute('aria-expanded', 'true');
}

function armDelegate() {
  if (armed || typeof document === 'undefined') return;
  armed = true;

  document.addEventListener('click', (e) => {
    const acc = e.target.closest && e.target.closest('.account');
    if (!acc) { closeAll(); return; }

    if (e.target.closest('.account-btn')) { toggle(acc); return; }

    const action = e.target.closest('[data-action]');
    if (action && action.dataset.action === 'logout') {
      closeAll();
      logout();
      return;
    }

    // A plain link (e.g. Settings) navigates itself — just drop the menu.
    if (e.target.closest('a.am-item')) closeAll();
  });

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeAll();
  });
}

async function logout() {
  try { await api.post('/api/auth/logout'); } catch (e) { /* session already gone */ }
  store.clear();
  location.hash = '#/login';
  toast('Logged out.');
}
