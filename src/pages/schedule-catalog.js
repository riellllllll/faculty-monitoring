import { api } from '../core/api.js';
import { esc } from '../components/ui.js';
import { icon } from '../components/icons.js';
import { toast } from '../components/toast.js';

export function openScheduleCatalog(main, options, terms, onSaved) {
  const overlay = main.querySelector('#catalogOverlay');
  const editor = main.querySelector('#catalogEditor');
  const opener = document.activeElement;
  overlay.hidden = false;
  document.body.classList.add('modal-open');
  const close = () => {
    overlay.hidden = true;
    document.body.classList.remove('modal-open');
    opener?.focus?.();
  };
  const programs = (options.programs || []).map(p => `<option value="${Number(p.id)}">${esc(p.code)} · ${esc(p.name)}</option>`).join('');
  const subjects = (options.subjects || []).map(s => `<option value="${Number(s.id)}">${esc(s.code)} · ${esc(s.title)}</option>`).join('');
  const termChoices = terms.map(t => `<option value="${Number(t.id)}">${esc(t.school_year)} · ${esc(t.name)}</option>`).join('');
  const curriculum = `<div class="row two"><div><label>Curriculum type</label><select name="subject_type">${['Core', 'Elective', 'Laboratory', 'PE', 'General Education', 'NSTP', 'Institutional', 'Practicum', 'Thesis'].map(x => `<option>${x}</option>`).join('')}</select></div><div><label>Year level</label><input name="year_level" type="number" min="1" max="5" value="1" required></div></div>
    <div class="row"><label>Curriculum semester</label><select name="semester_code"><option value="">Any semester</option><option value="S1">First semester</option><option value="S2">Second semester</option><option value="SUM">Summer term</option></select></div>`;
  const fields = {
    subjects: `<div class="row two"><div><label>Program</label><select name="program_id" required>${programs}</select></div><div><label>Subject code</label><input name="code" maxlength="20" required></div></div>
      <div class="row two"><div><label>Subject title</label><input name="title" maxlength="150" required></div><div><label>Units</label><input name="units" type="number" min="1" max="12" value="3" required></div></div>
      ${curriculum}<div class="row two"><div><label>Lecture hours</label><input name="lecture_hours" type="number" min="0" max="20" step="0.5" value="0" required></div><div><label>Lab hours</label><input name="lab_hours" type="number" min="0" max="20" step="0.5" value="0" required></div></div>`,
    curriculum: `<div class="row two"><div><label>Program</label><select name="program_id" required>${programs}</select></div><div><label>Existing subject</label><select name="subject_id" required>${subjects}</select></div></div>${curriculum}`,
    terms: `<div class="row two"><div><label>School year starts in</label><input name="start_year" type="number" min="2020" max="2100" value="${new Date().getFullYear()}" required></div><div><label>Semester code</label><input name="code" maxlength="20" required></div></div>
      <div class="row"><label>Semester name</label><input name="name" maxlength="40" required></div>
      <div class="row two"><div><label>Start date</label><input name="start_date" type="date" required></div><div><label>End date</label><input name="end_date" type="date" required></div></div>`,
    sections: `<div class="row two"><div><label>Program</label><select name="program_id" required>${programs}</select></div><div><label>Academic term</label><select name="semester_id" required>${termChoices}</select></div></div>
      <div class="row two"><div><label>Section code</label><input name="code" maxlength="20" required></div><div><label>Year level</label><input name="year_level" type="number" min="1" max="5" value="1" required></div></div>
      <div class="row"><label>Section name</label><input name="name" maxlength="80" required></div>`,
    rooms: `<div class="row two"><div><label>Room code</label><input name="code" maxlength="20" required></div><div><label>Room name</label><input name="name" maxlength="100" required></div></div>
      <div class="row two"><div><label>Building</label><input name="building" maxlength="100"></div><div><label>Room type</label><select name="room_type">${['Lecture', 'Laboratory', 'Auditorium', 'Online'].map(x => `<option>${x}</option>`).join('')}</select></div></div>
      <div class="row"><label>Capacity</label><input name="capacity" type="number" min="0" max="1000" value="0"></div>`,
  };
  editor.innerHTML = `<header class="account-editor-head"><div class="panel-head"><div><span class="account-scope">Schedule foundations</span><h2>Academic setup</h2></div>
    <button class="btn ghost sm" id="closeCatalog">${icon('x', 14)}Close</button></div>
    <p class="lead">Add approved terms, subjects, sections, and rooms before scheduling classes.</p></header>
    <form id="catalogForm"><section class="account-section"><div class="account-section-head"><span class="account-section-number">01</span><div><h3>Record type</h3></div></div>
    <div class="row"><label for="catalogKind">Choose what to add</label><select id="catalogKind"><option value="terms">Academic term</option><option value="sections">Section</option><option value="subjects">Subject</option><option value="curriculum">Assign subject to program</option><option value="rooms">Room</option></select></div></section>
    <section class="account-section"><div class="account-section-head"><span class="account-section-number">02</span><div><h3>Details</h3></div></div><div id="catalogFields"></div></section>
    <div class="actions"><button class="btn ghost" type="button" id="cancelCatalog">Cancel</button><button class="btn primary" type="submit">Add record</button></div></form>`;
  editor.querySelector('#closeCatalog').onclick = close;
  editor.querySelector('#cancelCatalog').onclick = close;
  overlay.querySelector('.ui-overlay-backdrop').onclick = close;
  overlay.onkeydown = event => { if (event.key === 'Escape') close(); };
  const renderFields = () => {
    editor.querySelector('#catalogFields').innerHTML = fields[editor.querySelector('#catalogKind').value];
  };
  editor.querySelector('#catalogKind').addEventListener('change', renderFields);
  renderFields();
  editor.querySelector('#catalogForm').addEventListener('submit', async event => {
    event.preventDefault();
    const kind = editor.querySelector('#catalogKind').value;
    const submit = editor.querySelector('[type="submit"]');
    submit.disabled = true;
    try {
      const result = await api.post(`/api/schedule-catalog/${kind}`, Object.fromEntries(new FormData(event.currentTarget).entries()));
      toast(result.message || 'Record added.');
      close();
      onSaved();
    } catch (error) { toast(error.message, true); submit.disabled = false; }
  });
}
