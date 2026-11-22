import { api } from '../core/api.js';
import { el, mount } from '../core/dom.js';
import { renderNav, bindNav } from '../components/nav.js';
import { pageHead, esc } from '../components/ui.js';
import { store } from '../core/store.js';
import { navigate } from '../core/router.js';

export default async function roomCheckPage(container) {
  const code = new URLSearchParams(location.hash.split('?')[1] || '').get('code') || '';
  if (store.hasRole('faculty') && /^[a-f0-9]{32}$/.test(code)) {
    navigate(`/verification?code=${code}`);
    return;
  }
  const wrap = el('div', { class: 'layout' });
  const navC = el('div');
  navC.innerHTML = renderNav('/room');
  bindNav(navC);
  wrap.appendChild(navC.firstElementChild);

  const main = el('main', { class: 'main room-check-main' });
  main.innerHTML = pageHead({ title: 'Room QR', sub: 'Check the room shown on the printed card.' });
  if (!/^[a-f0-9]{32}$/.test(code)) {
    main.innerHTML += '<div class="room-check-result"><h2>Invalid room QR</h2><p>Scan a room card issued by the department.</p></div>';
  } else {
    try {
      const { data: room } = await api.get(`/api/rooms/resolve?code=${encodeURIComponent(code)}`);
      main.innerHTML += `<div class="room-check-result"><h2>${esc(room.code)}</h2><p>${esc(room.name)}</p>
        <span>${esc([room.building, room.room_type].filter(Boolean).join(' · '))}</span>
        <div class="room-check-notice">Room identified. Attendance check-in is not available yet.</div></div>`;
    } catch (error) {
      main.innerHTML += `<div class="room-check-result"><h2>Room QR unavailable</h2><p>${esc(error.message || 'This code could not be verified.')}</p></div>`;
    }
  }
  wrap.appendChild(main);
  mount(container, wrap);
}
