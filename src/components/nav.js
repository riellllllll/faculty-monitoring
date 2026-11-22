import { store } from '../core/store.js';
import { navigate } from '../core/router.js';
import { api } from '../core/api.js';
import { toast } from './toast.js';
import { initials } from './ui.js';
import { roleLabels } from './account.js';
import { icon } from './icons.js';
import { esc } from '../core/text.js';

let activeSidebar = null;
let responsiveHeaderBound = false;

function arrangeResponsiveHeader() {
  const sidebar = activeSidebar;
  const header = sidebar?.closest('.layout')?.querySelector('.page-head');
  if (!sidebar?.isConnected || !header) return;
  const actions = header.querySelector('.page-actions');
  const utilities = sidebar.querySelector('.sidebar-utilities');
  const toggle = sidebar.querySelector('#navToggle') || header.querySelector('#navToggle');
  if (!actions || !utilities || !toggle) return;
  if (matchMedia('(max-width: 767px)').matches) {
    utilities.append(...actions.querySelectorAll('.notification, .account'));
    sidebar.querySelector('.sidebar-mobile-menu').append(toggle);
    sidebar.querySelector('#siteNavMenu').inert = sidebar.dataset.open !== 'true';
  } else {
    actions.append(...utilities.querySelectorAll('.notification, .account'));
    sidebar.querySelector('.nav-toggle-home').append(toggle);
    sidebar.dataset.open = 'false';
    toggle.setAttribute('aria-expanded', 'false');
    sidebar.querySelector('#siteNavMenu').inert = false;
    document.body.classList.remove('nav-open');
  }
}

/**
 * Navigation is capability-driven: a link only renders when the signed-in user
 * holds the permission its target page needs. Icons come from the local SVG
 * set — no emoji, no icon font, no network dependency.
 */
const links = [
  { path: '/dashboard',    label: 'Dashboard',    icon: 'dashboard',      group: 'Monitoring',
    cap: null },
  { path: '/faculty',      label: 'Faculty',      icon: 'users',          group: 'Monitoring',
    cap: 'faculty.view' },
  { path: '/schedules',    label: 'Schedules',    icon: 'calendar',       group: 'Monitoring',
    cap: null },
  { path: '/verification', label: 'Verification', icon: 'sealCheck',     group: 'Monitoring',
    cap: null, roles: ['faculty', 'chairperson', 'program_coordinator'] },
  { path: '/rooms',        label: 'Rooms',        icon: 'building',       group: 'Monitoring',
    cap: 'room_qr.manage' },
  { path: '/reports',      label: 'Reports',      icon: 'chart',          group: 'Monitoring',
    cap: ['report.view_own', 'report.view_program', 'report.view_department'] },
  { path: '/settings',     label: 'Settings',     icon: 'sliders',        group: 'Account',
    cap: null },
];

export function renderNav(activePath) {
  const u = store.user || {};
  const name = [u.first_name, u.last_name].filter(Boolean).join(' ') || u.email || '';
  const roleLine = (u.roles || []).map(r => roleLabels[r] || r).join(' · ');

  const visible = links.filter(l => (l.cap === null || store.hasCap(l.cap))
    && (!l.roles || store.hasRole(...l.roles)));

  // Render a group label only when the group actually changes.
  let lastGroup = null;
  const items = visible.map(l => {
    let head = '';
    if (l.group !== lastGroup) {
      lastGroup = l.group;
      head = `<div class="sidebar-group-label">${l.group}</div>`;
    }
    const current = activePath === l.path;
    return `${head}<a href="#${l.path}" data-path="${l.path}" class="${current ? 'active' : ''}"` +
           `${current ? ' aria-current="page"' : ''}>` +
           `<span class="ico">${icon(l.icon, 17)}</span>${l.label}</a>`;
  }).join('');

  return `
    <aside class="sidebar" data-open="false">
      <div class="sidebar-mobile-head">
        <div class="brand"><span class="mark">${icon('cap', 18)}</span>Faculty Monitor</div>
        <div class="sidebar-utilities"></div>
        <div class="nav-toggle-home"><button class="nav-toggle" id="navToggle" type="button" aria-controls="siteNavMenu" aria-expanded="false">
          <span class="nav-bars" aria-hidden="true"><span></span><span></span><span></span></span><span>Menu</span>
        </button></div>
      </div>
      <div class="sidebar-mobile-menu"><span class="sidebar-current-page" aria-hidden="true">${esc(links.find(link => link.path === activePath)?.label || (activePath === '/room' ? 'Room QR' : 'Menu'))}</span></div>
      <div class="nav-backdrop" aria-hidden="true"></div>
      <nav class="sidebar-menu" id="siteNavMenu" aria-label="Main navigation">
        <div class="nav-drawer-head"><strong>Menu</strong><button class="nav-drawer-close" type="button" aria-label="Close menu">${icon('x', 18)}</button></div>
        ${items}
        <div class="spacer"></div>
        <div class="user">
          <span class="avatar">${esc(initials(u.first_name, u.last_name))}</span>
          <span><b>${esc(name)}</b><small>${esc(roleLine)}</small></span>
        </div>
        <button class="sidebar-logout" id="logoutBtn" type="button"><span class="ico">${icon('logOut', 17)}</span>Logout</button>
      </nav>
    </aside>
  `;
}

export function bindNav(container) {
  const sidebar = container.querySelector('.sidebar');
  const toggle = container.querySelector('#navToggle');
  const menu = container.querySelector('#siteNavMenu');
  const close = (restoreFocus = false) => {
    sidebar.dataset.open = 'false';
    toggle.setAttribute('aria-expanded', 'false');
    menu.inert = matchMedia('(max-width: 767px)').matches;
    document.body.classList.remove('nav-open');
    if (restoreFocus) toggle.focus();
  };
  toggle.addEventListener('click', () => {
    const open = sidebar.dataset.open !== 'true';
    if (!open) { close(); return; }
    sidebar.dataset.open = 'true';
    toggle.setAttribute('aria-expanded', 'true');
    menu.inert = false;
    document.body.classList.add('nav-open');
    menu.querySelector('.nav-drawer-close').focus();
  });
  sidebar.querySelector('.nav-backdrop').addEventListener('click', () => close(true));
  menu.querySelector('.nav-drawer-close').addEventListener('click', () => close(true));
  sidebar.querySelector('.sidebar-utilities').addEventListener('click', () => {
    if (sidebar.dataset.open === 'true') close();
  });
  menu.addEventListener('keydown', event => {
    if (sidebar.dataset.open !== 'true') return;
    if (event.key === 'Escape') { close(true); return; }
    if (event.key !== 'Tab') return;
    const controls = [...menu.querySelectorAll('a, button')];
    const first = controls[0];
    const last = controls[controls.length - 1];
    if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
    else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
  });
  container.querySelectorAll('a[data-path]').forEach(a => {
    a.addEventListener('click', event => { event.preventDefault(); close(); navigate(a.dataset.path); });
  });
  const lb = container.querySelector('#logoutBtn');
  if (lb) lb.addEventListener('click', async () => {
    try { await api.post('/api/auth/logout'); } catch (e) { /* session already gone */ }
    store.clear();
    close();
    navigate('/login');
    toast('Logged out.');
  });
  activeSidebar = sidebar;
  if (!responsiveHeaderBound) {
    matchMedia('(max-width: 767px)').addEventListener('change', arrangeResponsiveHeader);
    document.addEventListener('faculty-monitor:mounted', arrangeResponsiveHeader);
    responsiveHeaderBound = true;
  }
  queueMicrotask(arrangeResponsiveHeader);
}
