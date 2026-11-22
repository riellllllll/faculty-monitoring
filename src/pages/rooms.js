import QRCode from 'qrcode';
import { api } from '../core/api.js';
import { el, mount } from '../core/dom.js';
import { renderNav, bindNav } from '../components/nav.js';
import { pageHead, esc, revealStack } from '../components/ui.js';
import { icon } from '../components/icons.js';
import { toast } from '../components/toast.js';

const roomDescription = room => [room.building, room.room_type].filter(Boolean).join(' · ');

export default async function roomsPage(container) {
  const response = await api.get('/api/rooms');
  let rooms = response.data || [];
  let selectedId = rooms[0]?.id || null;
  let selection = 0;

  const wrap = el('div', { class: 'layout' });
  const navC = el('div');
  navC.innerHTML = renderNav('/rooms');
  bindNav(navC);
  wrap.appendChild(navC.firstElementChild);

  const main = el('main', { class: 'main rooms-main' });
  main.innerHTML = `${pageHead({ title: 'Rooms', sub: 'A permanent QR card for each classroom.',
    actions: `<button class="btn primary" type="button" id="addRoom">${icon('plus', 15)} Add room</button>` })}
    <div class="rooms-workspace">
      <section class="rooms-list-panel" aria-labelledby="roomsListTitle">
        <div class="rooms-list-head"><div><h2 id="roomsListTitle">Classrooms</h2><p id="roomCount"></p></div></div>
        <div id="roomList" class="rooms-list"></div>
      </section>
      <section class="room-detail-panel" id="roomDetail" aria-live="polite" aria-label="Selected room QR"></section>
    </div>
    <div class="ui-overlay" id="roomOverlay" hidden><div class="ui-overlay-backdrop"></div>
      <div class="management-dialog room-create-dialog" role="dialog" aria-modal="true" aria-labelledby="roomFormTitle">
        <div class="panel-head"><h2 id="roomFormTitle">Add room</h2><button class="btn ghost sm" type="button" id="closeRoom">${icon('x', 14)} Close</button></div>
        <p class="lead">A distinct permanent QR code is created automatically when you save the room.</p>
        <form id="roomForm" class="form">
          <div class="row two"><div><label for="roomCode">Room code</label><input id="roomCode" name="code" maxlength="20" required></div>
            <div><label for="roomName">Room name</label><input id="roomName" name="name" maxlength="100" required></div></div>
          <div class="row two"><div><label for="roomBuilding">Building</label><input id="roomBuilding" name="building" maxlength="100"></div>
            <div><label for="roomType">Room type</label><select id="roomType" name="room_type"><option>Lecture</option><option>Laboratory</option><option>Auditorium</option><option>Online</option></select></div></div>
          <div class="row"><label for="roomCapacity">Capacity</label><input id="roomCapacity" name="capacity" type="number" min="0" max="1000" value="0"></div>
          <div class="actions"><button class="btn ghost" type="button" id="cancelRoom">Cancel</button><button class="btn primary" type="submit">Add room</button></div>
        </form>
      </div>
    </div>`;
  wrap.appendChild(main);
  mount(container, wrap);
  revealStack(main);

  const list = main.querySelector('#roomList');
  const detail = main.querySelector('#roomDetail');
  const overlay = main.querySelector('#roomOverlay');
  const paintList = () => {
    main.querySelector('#roomCount').textContent = `${rooms.length} active room${rooms.length === 1 ? '' : 's'}`;
    list.innerHTML = rooms.length ? rooms.map(room => `<button type="button" class="room-list-item ${Number(room.id) === Number(selectedId) ? 'selected' : ''}"
      data-room-id="${Number(room.id)}" aria-pressed="${Number(room.id) === Number(selectedId)}">
      <span class="room-list-code">${esc(room.code)}</span><span class="room-list-name">${esc(room.name)}</span>
      <span class="room-list-meta">${esc(roomDescription(room) || 'No building assigned')}</span></button>`).join('')
      : '<p class="room-empty">No rooms yet. Add the first classroom to create its QR card.</p>';
  };

  const paintDetail = async () => {
    const current = ++selection;
    paintList();
    if (!selectedId) {
      detail.innerHTML = '<div class="room-empty-detail">Select a room to view its QR card.</div>';
      return;
    }
    detail.innerHTML = '<p class="room-loading">Preparing room QR…</p>';
    try {
      const { data: room } = await api.get(`/api/rooms/${Number(selectedId)}/qr`);
      const image = await QRCode.toDataURL(room.url, {
        errorCorrectionLevel: 'M', margin: 2, width: 480,
        color: { dark: '#183b24', light: '#ffffff' },
      });
      if (current !== selection) return;
      detail.innerHTML = `<button class="btn ghost sm room-back" type="button" id="backToRooms">${icon('arrowLeft', 15)} Classrooms</button>
        <div class="room-detail-top"><div><h2>${esc(room.code)}</h2><p>${esc(room.name)}${room.building ? ` · ${esc(room.building)}` : ''}</p></div>
        <span class="room-qr-status">Permanent QR</span></div>
        <div class="room-qr-card"><img src="${image}" width="320" height="320" alt="QR code for ${esc(room.code)}" />
          <strong>${esc(room.code)}</strong><span>${esc(room.name)}</span></div>
        <p class="room-qr-note">This code identifies the room. Scanning it does not record attendance yet.</p>
        <div class="room-qr-actions"><a class="btn primary" href="${image}" download="${esc(room.code)}-QR.png">${icon('download', 16)} Download PNG</a>
          <button class="btn ghost" type="button" id="printRoom">Print card</button></div>`;
      detail.querySelector('#printRoom').addEventListener('click', () => window.print());
      detail.querySelector('#backToRooms').addEventListener('click', () => list.scrollIntoView({ block: 'start' }));
    } catch (error) {
      if (current !== selection) return;
      detail.innerHTML = `<div class="room-empty-detail">${esc(error.message || 'Could not load the room QR.')}</div>`;
    }
  };

  list.addEventListener('click', event => {
    const button = event.target.closest('[data-room-id]');
    if (!button) return;
    selectedId = Number(button.dataset.roomId);
    paintDetail();
    if (matchMedia('(max-width: 800px)').matches) detail.scrollIntoView({ block: 'start' });
  });

  let opener = null;
  const close = () => {
    overlay.hidden = true;
    document.body.classList.remove('modal-open');
    opener?.focus?.();
  };
  main.querySelector('#addRoom').addEventListener('click', () => {
    opener = document.activeElement;
    overlay.hidden = false;
    document.body.classList.add('modal-open');
    main.querySelector('#roomCode').focus();
  });
  main.querySelector('#closeRoom').addEventListener('click', close);
  main.querySelector('#cancelRoom').addEventListener('click', close);
  overlay.querySelector('.ui-overlay-backdrop').addEventListener('click', close);
  overlay.addEventListener('keydown', event => { if (event.key === 'Escape') close(); });
  main.querySelector('#roomForm').addEventListener('submit', async event => {
    event.preventDefault();
    const submit = event.currentTarget.querySelector('[type="submit"]');
    submit.disabled = true;
    try {
      const result = await api.post('/api/schedule-catalog/rooms', Object.fromEntries(new FormData(event.currentTarget).entries()));
      rooms = (await api.get('/api/rooms')).data || [];
      selectedId = result.data.id;
      event.currentTarget.reset();
      close();
      toast('Room added with its permanent QR.');
      paintDetail();
    } catch (error) {
      toast(error.message || 'Could not add room.', true);
    } finally {
      submit.disabled = false;
    }
  });

  paintDetail();
}
