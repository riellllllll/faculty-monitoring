import { api } from '../core/api.js';
import { el, mount } from '../core/dom.js';
import { renderNav, bindNav } from '../components/nav.js';
import { pageHead, esc } from '../components/ui.js';
import { store } from '../core/store.js';
import { toast } from '../components/toast.js';

function roomCodeFromScan(value) {
  if (/^[a-f0-9]{32}$/.test(value)) return value;
  try {
    const url = new URL(value);
    if (url.origin !== location.origin) return null;
    const code = new URLSearchParams(url.hash.split('?')[1] || '').get('code');
    return /^[a-f0-9]{32}$/.test(code || '') ? code : null;
  } catch { return null; }
}

export default async function verificationPage(container) {
  const canCapture = store.hasRole('faculty', 'chairperson');
  const canReview = store.hasRole('chairperson', 'program_coordinator');
  const codeFromLink = new URLSearchParams(location.hash.split('?')[1] || '').get('code');
  const wrap = el('div', { class: 'layout' });
  const nav = el('div');
  nav.innerHTML = renderNav('/verification');
  bindNav(nav);
  wrap.appendChild(nav.firstElementChild);

  const main = el('main', { class: 'main verification-main' });
  main.innerHTML = `${pageHead({ eyebrow: 'Class evidence', title: 'Verification',
    sub: 'Scan the classroom QR, then take a selfie with the class visible behind you.' })}
    ${canCapture ? `<div class="verification-steps" aria-label="Verification steps">
      <span><b>01</b> Scan room</span><span><b>02</b> Class selfie</span><span><b>03</b> Review</span>
    </div><section class="verification-capture" aria-labelledby="verifyTitle">
      <div class="verification-section-head"><div><span class="eyebrow">Faculty check-in evidence</span>
        <h2 id="verifyTitle">Record your class</h2></div></div>
      <div id="verifyStage"></div></section>` : ''}
    <section class="verification-history" aria-labelledby="verificationHistoryTitle">
      <div class="verification-section-head"><div><span class="eyebrow">${canReview ? 'Review queue' : 'Your records'}</span>
        <h2 id="verificationHistoryTitle">${canReview ? 'Faculty submissions' : 'My submissions'}</h2></div>
        <button class="btn ghost sm" type="button" id="refreshVerification">Refresh</button></div>
      ${canReview ? `<div class="verification-filters" role="group" aria-label="Filter submissions by review status">
        <button type="button" data-verification-status="all" aria-pressed="true">All</button>
        <button type="button" data-verification-status="pending" aria-pressed="false">Awaiting review</button>
        <button type="button" data-verification-status="approved" aria-pressed="false">Approved</button>
      </div><p class="verification-filter-note">Approved means the classroom selfie was reviewed; teaching hours are not credited yet.</p>` : ''}
      <div id="verificationItems"><p class="verification-muted">Loading submissions…</p></div>
    </section>`;
  wrap.appendChild(main);
  mount(container, wrap);

  const stage = main.querySelector('#verifyStage');
  const items = main.querySelector('#verificationItems');
  let scannerControls = null;
  let selfieStream = null;
  let selected = null;
  let room = null;
  let roomCode = null;
  let photo = null;
  let disposed = false;
  let scanHandled = false;
  let statusFilter = 'all';
  let listRequest = 0;

  const setStep = index => {
    main.querySelectorAll('.verification-steps span').forEach((step, position) => {
      if (position === index) step.setAttribute('aria-current', 'step');
      else step.removeAttribute('aria-current');
    });
  };

  const stopVideo = video => {
    if (video?.srcObject) {
      video.srcObject.getTracks().forEach(track => track.stop());
      video.srcObject = null;
    }
  };
  const stopCameras = () => {
    scannerControls?.stop();
    scannerControls = null;
    selfieStream?.getTracks().forEach(track => track.stop());
    selfieStream = null;
    main.querySelectorAll('video').forEach(stopVideo);
  };
  const leave = () => {
    disposed = true;
    stopCameras();
    window.removeEventListener('hashchange', leave);
  };
  window.addEventListener('hashchange', leave);

  const scanView = (message = 'Point your camera at a printed classroom QR card.') => {
    stopCameras();
    setStep(0);
    selected = null;
    photo = null;
    if (!stage) return;
    stage.innerHTML = `<div class="verification-scan">
      <div class="verification-camera"><video id="qrPreview" autoplay muted playsinline aria-label="Room QR camera preview"></video>
        <div class="verification-camera-cue">Place the room QR inside the frame</div></div>
      <div class="verification-guidance"><h3>Scan the room card</h3><p id="scanStatus" role="status">${esc(message)}</p>
        <button class="btn primary" type="button" id="startQrScan">Open camera</button>
        <small>Camera access requires HTTPS. You can also open the printed QR with your phone camera.</small></div></div>`;
    stage.querySelector('#startQrScan').addEventListener('click', startScanner);
  };

  async function startScanner() {
    const video = stage.querySelector('#qrPreview');
    const button = stage.querySelector('#startQrScan');
    const status = stage.querySelector('#scanStatus');
    if (!video || !navigator.mediaDevices?.getUserMedia) {
      status.textContent = 'This browser cannot open the camera. Use your phone camera to open the printed QR.';
      return;
    }
    button.disabled = true;
    status.textContent = 'Opening the back camera…';
    scanHandled = false;
    try {
      const { BrowserQRCodeReader } = await import('@zxing/browser');
      const reader = new BrowserQRCodeReader();
      scannerControls = await reader.decodeFromVideoDevice(undefined, video, (result, _error, controls) => {
        if (disposed || scanHandled || !result) return;
        const code = roomCodeFromScan(result.getText());
        if (!code) { status.textContent = 'This is not a room QR issued by this system.'; return; }
        scanHandled = true;
        controls.stop();
        scannerControls = null;
        stopVideo(video);
        loadRoom(code);
      });
      if (disposed) stopCameras();
      else if (!scanHandled) status.textContent = 'Scanning… hold the QR card steady.';
    } catch (error) {
      button.disabled = false;
      status.textContent = `Camera unavailable: ${error.message || 'Check camera permission.'}`;
    }
  }

  async function loadRoom(code) {
    if (!stage) return;
    stage.innerHTML = '<p class="verification-muted">Matching the room to your current class…</p>';
    try {
      const { data } = await api.get(`/api/verification/current?code=${encodeURIComponent(code)}`);
      if (disposed) return;
      room = data.room;
      roomCode = code;
      selected = data.classes?.[0] || null;
      if (!selected) {
        scanView(`${room.code} was identified, but you have no entered class scheduled in this room right now.`);
        return;
      }
      selfieView();
      await startSelfie();
    } catch (error) {
      if (!disposed) scanView(error.message || 'This room could not be matched.');
    }
  }

  function selfieView() {
    photo = null;
    setStep(1);
    stage.innerHTML = `<div class="verification-class">
      <div><span class="eyebrow">Room ${esc(room.code)}</span><h3>${esc(selected.subject_code)} · ${esc(selected.subject_title)}</h3>
        <p>${esc(selected.section_code)} · ${esc(selected.start_time)}–${esc(selected.end_time)}</p></div>
      <button class="btn ghost sm" type="button" id="scanAgain">Scan another room</button></div>
      <div class="verification-selfie"><div class="verification-camera">
        <video id="selfieVideo" autoplay muted playsinline aria-label="Selfie camera preview"></video>
        <img id="selfieImage" alt="Captured classroom selfie" hidden></div>
        <div class="verification-guidance"><h3>Take a class selfie</h3>
          <p>Stand in front of the class so your face and the class behind you are visible. A reviewer will check the photo.</p>
          <p id="selfieStatus" role="status">Opening the front camera…</p>
          <div class="verification-actions"><button class="btn primary" type="button" id="captureSelfie" disabled>Take selfie</button>
            <button class="btn ghost" type="button" id="retakeSelfie" hidden>Retake</button>
            <button class="btn primary" type="button" id="submitSelfie" hidden>Submit for review</button></div></div></div>`;
    stage.querySelector('#scanAgain').addEventListener('click', () => scanView());
    stage.querySelector('#captureSelfie').addEventListener('click', captureSelfie);
    stage.querySelector('#retakeSelfie').addEventListener('click', async () => { selfieView(); await startSelfie(); });
    stage.querySelector('#submitSelfie').addEventListener('click', submitSelfie);
  }

  async function startSelfie() {
    const video = stage.querySelector('#selfieVideo');
    const status = stage.querySelector('#selfieStatus');
    if (!navigator.mediaDevices?.getUserMedia) {
      status.textContent = 'This browser cannot open the camera. Use a phone with HTTPS enabled.';
      return;
    }
    try {
      selfieStream = await navigator.mediaDevices.getUserMedia({ video: {
        facingMode: 'user', width: { ideal: 1280 }, height: { ideal: 720 },
      }, audio: false });
      if (disposed || !video.isConnected) { stopCameras(); return; }
      video.srcObject = selfieStream;
      await video.play();
      status.textContent = 'Make sure your face and class are both in frame.';
      stage.querySelector('#captureSelfie').disabled = false;
    } catch (error) {
      status.textContent = `Front camera unavailable: ${error.message || 'Check camera permission.'}`;
    }
  }

  function captureSelfie() {
    const video = stage.querySelector('#selfieVideo');
    if (!video.videoWidth || !video.videoHeight) return;
    const scale = Math.min(1, 1280 / video.videoWidth, 1280 / video.videoHeight);
    const canvas = document.createElement('canvas');
    canvas.width = Math.round(video.videoWidth * scale);
    canvas.height = Math.round(video.videoHeight * scale);
    canvas.getContext('2d').drawImage(video, 0, 0, canvas.width, canvas.height);
    photo = canvas.toDataURL('image/jpeg', .78);
    stopCameras();
    stage.querySelector('#selfieImage').src = photo;
    stage.querySelector('#selfieImage').hidden = false;
    video.hidden = true;
    stage.querySelector('#captureSelfie').hidden = true;
    stage.querySelector('#retakeSelfie').hidden = false;
    stage.querySelector('#submitSelfie').hidden = false;
    stage.querySelector('#selfieStatus').textContent = 'Check that your face and the class are clearly visible before submitting.';
  }

  async function submitSelfie() {
    if (!photo || !selected) return;
    const button = stage.querySelector('#submitSelfie');
    button.disabled = true;
    try {
      await api.post('/api/verification', { code: roomCode, schedule_id: Number(selected.schedule_id), selfie: photo });
      photo = null;
      selected = null;
      setStep(2);
      stage.innerHTML = `<div class="verification-done"><span class="eyebrow">Submitted</span>
        <h3>Your class selfie is awaiting review.</h3><p>This submission does not count teaching hours yet.</p>
        <button class="btn ghost" type="button" id="scanAnother">Scan another class</button></div>`;
      stage.querySelector('#scanAnother').addEventListener('click', () => scanView());
      toast('Class selfie submitted for review.');
      await loadSubmissions();
    } catch (error) {
      toast(error.message || 'Could not submit the selfie.', true);
      button.disabled = false;
    }
  }

  async function loadSubmissions() {
    const request = ++listRequest;
    try {
      const { data } = await api.get('/api/verification' + (statusFilter === 'all' ? '' : `?status=${statusFilter}`));
      if (disposed || request !== listRequest) return;
      items.innerHTML = data.length ? data.map(row => `<article class="verification-item" data-id="${Number(row.id)}">
        <div class="verification-item-main"><span class="verification-status ${esc(row.status)}">${esc(row.status)}</span>
          <h3>${esc(row.subject_code)} · ${esc(row.section_code)}</h3>
          <p>${canReview ? `${esc(row.faculty_name)} · ` : ''}${esc(row.room_code)} · ${esc(row.class_date)} · ${esc(row.submitted_at.slice(11, 16))}</p>
          ${row.review_note ? `<p class="verification-note">${esc(row.review_note)}</p>` : ''}</div>
        <div class="verification-item-actions"><button class="btn ghost sm" type="button" data-view-photo>View selfie</button>
          ${canReview && row.status === 'pending' && Number(row.faculty_id) !== Number(store.user?.id)
            ? '<button class="btn primary sm" type="button" data-approve>Approve</button><button class="btn ghost sm" type="button" data-reject>Reject</button>' : ''}</div>
        <div class="verification-photo" hidden></div>
        <div class="verification-reject" hidden><label>Reason for rejection<textarea maxlength="255" rows="2"></textarea></label>
          <div><button class="btn danger sm" type="button" data-confirm-reject>Confirm rejection</button>
          <button class="btn ghost sm" type="button" data-cancel-reject>Cancel</button></div></div>
      </article>`).join('') : '<p class="verification-muted">No class selfies submitted yet.</p>';
    } catch (error) {
      if (!disposed && request === listRequest) items.innerHTML = `<p class="verification-muted">${esc(error.message || 'Could not load submissions.')}</p>`;
    }
  }

  items.addEventListener('click', async event => {
    const card = event.target.closest('.verification-item');
    if (!card) return;
    const id = Number(card.dataset.id);
    if (event.target.closest('[data-view-photo]')) {
      const area = card.querySelector('.verification-photo');
      area.hidden = !area.hidden;
      if (!area.hidden && !area.firstChild) area.innerHTML = `<img src="/api/verification/${id}/photo" alt="Classroom selfie submission" loading="lazy">`;
    } else if (event.target.closest('[data-approve]')) {
      if (!confirm('Approve this classroom selfie after checking that the faculty member and class are visible?')) return;
      await decide(id, 'approved', '');
    } else if (event.target.closest('[data-reject]')) {
      card.querySelector('.verification-reject').hidden = false;
      card.querySelector('textarea').focus();
    } else if (event.target.closest('[data-cancel-reject]')) {
      card.querySelector('.verification-reject').hidden = true;
    } else if (event.target.closest('[data-confirm-reject]')) {
      await decide(id, 'rejected', card.querySelector('textarea').value.trim());
    }
  });

  async function decide(id, status, note) {
    try {
      await api.post(`/api/verification/${id}/decision`, { status, review_note: note });
      toast(`Submission ${status}.`);
      await loadSubmissions();
    } catch (error) { toast(error.message || 'Could not save the review.', true); }
  }

  main.querySelector('#refreshVerification').addEventListener('click', loadSubmissions);
  main.querySelector('.verification-filters')?.addEventListener('click', event => {
    const button = event.target.closest('[data-verification-status]');
    if (!button) return;
    statusFilter = button.dataset.verificationStatus;
    main.querySelectorAll('[data-verification-status]').forEach(item => {
      item.setAttribute('aria-pressed', String(item === button));
    });
    loadSubmissions();
  });
  if (canCapture) {
    scanView();
    if (codeFromLink) loadRoom(codeFromLink);
  }
  loadSubmissions();
}
