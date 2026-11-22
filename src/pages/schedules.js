import { api } from '../core/api.js';
import { navigate } from '../core/router.js';
import { el, mount } from '../core/dom.js';
import { renderNav, bindNav } from '../components/nav.js';
import { pageHead, esc, revealStack } from '../components/ui.js';
import { toast } from '../components/toast.js';
import { icon } from '../components/icons.js';
import { scheduleDays, firstMinute, lastMinute, minutes, clockTime, renderWeekGrid, downloadSchedulePng } from './schedule-grid.js';
import { openScheduleCatalog } from './schedule-catalog.js';
import { facultyHeadTile, facultyTile, facultyProgramSections, filterFacultyCards, leadershipFromAccounts, plainFaculty, coordinatorForProgram } from '../components/facultyCards.js';

export default async function schedulesPage(container) {
  const { data } = await api.get('/api/schedules');
  const faculty = data.faculty || [];
  const entries = data.entries || [];
  const terms = data.terms || [];
  const options = data.options || {};
  const canEdit = Boolean(data.can_manage);
  const canCatalog = Boolean(data.can_catalog);
  const ownSchedule = !canEdit;
  const accountDirectory = canCatalog ? (await api.get('/api/users')).data : { users: [] };
  const leaders = canCatalog
    ? leadershipFromAccounts(accountDirectory.users, options.programs || [], faculty[0]?.department_name || 'Department of Computer Studies')
    : [];
  const directoryFaculty = canCatalog ? plainFaculty(faculty) : faculty;
  const head = leaders.find(person => (person.roles || []).includes('chairperson'));
  const query = new URLSearchParams(location.hash.split('?')[1] || '');
  const requestedFaculty = query.get('faculty');
  const requestedTerm = query.get('term');
  const today = new Date();
  const localDate = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
  const todayName = new Intl.DateTimeFormat('en-PH', { weekday: 'long' }).format(today);
  let selectedTerm = String(terms.find(term => String(term.id) === requestedTerm)?.id
    || terms.find(term => term.start_date <= localDate && term.end_date >= localDate)?.id || terms[0]?.id || '');
  let selectedFaculty = String(faculty.find(person => String(person.id) === requestedFaculty)?.id
    || faculty.find(person => entries.some(entry => String(entry.semester_id) === selectedTerm && Number(entry.faculty_id) === Number(person.id)))?.id
    || faculty[0]?.id || '');
  let mode = ownSchedule ? 'view' : requestedFaculty && faculty.some(item => String(item.id) === requestedFaculty)
    ? (query.get('mode') === 'edit' && canEdit ? 'edit' : 'view') : 'list';
  let adding = false;
  let selectedEntry = null;
  let draft = null;
  let openedBlock = null;
  const pendingDeletes = new Set();
  const preferredRoom = id => Number(entries.find(entry => String(entry.faculty_id) === String(id)
    && String(entry.semester_id) === selectedTerm && entry.room_id)?.room_id || options.rooms?.[0]?.id || 0);
  let availabilityRoom = preferredRoom(selectedFaculty);
  let search = '';

  const wrap = el('div', { class: 'layout' });
  const nav = el('div');
  nav.innerHTML = renderNav('/schedules');
  bindNav(nav);
  wrap.appendChild(nav.firstElementChild);
  const main = el('main', { class: 'main schedule-main' });
  main.innerHTML = `${pageHead({
    eyebrow: 'Teaching timetable', title: ownSchedule ? 'My schedule' : 'Faculty schedules',
    sub: ownSchedule ? 'Your weekly class times.' : 'Review weekly class times by faculty member. Select a schedule to view or adjust it.',
    actions: canCatalog ? `<button class="btn ghost sm" id="openCatalog">Academic setup</button>` : '',
  })}
    <div class="schedule-term-bar"><div><label for="scheduleTerm">Academic term</label><select id="scheduleTerm">
      ${terms.map(term => `<option value="${Number(term.id)}" ${String(term.id) === selectedTerm ? 'selected' : ''}>${esc(term.school_year)} · ${esc(term.name)}</option>`).join('')}
    </select></div><div id="scheduleNotice" class="schedule-notice"></div></div>
    <section id="scheduleDirectory" class="schedule-directory" aria-label="Faculty schedules">
      <div class="section-head"><h2>Faculties</h2><label class="search schedule-directory-search">${icon('search', 16)}<input id="scheduleSearch" type="search" placeholder="Search name, employee no. or email" aria-label="Search faculty schedules" autocomplete="off"></label></div>
      <div id="scheduleRoster" class="faculty-org-directory schedule-org-directory"></div>
    </section>
    <section id="scheduleDetail" class="schedule-detail" hidden>
      ${ownSchedule ? '<section id="facultyDayAgenda" class="faculty-day-agenda" aria-labelledby="facultyDayTitle"></section>' : ''}
      <div class="schedule-detail-toolbar${ownSchedule ? ' schedule-own-toolbar' : ''}">${ownSchedule ? '' : '<button type="button" class="btn ghost sm" id="backToSchedules">← All faculty schedules</button>'}<div id="scheduleDetailButtons"></div></div>
      <div id="scheduleWorkspace" class="schedule-workspace">
        <aside class="schedule-left" aria-label="Schedule editor"><div id="scheduleEditPanel"></div></aside>
        <section class="schedule-right" aria-label="Weekly timetable">
          <div class="schedule-right-head"><div><span class="eyebrow">Weekly timetable</span><h2 id="scheduleName"></h2><p id="scheduleTermLabel"></p><p id="scheduleSelectedDetail" class="schedule-selected-detail" hidden></p></div><div class="schedule-right-meta"><span id="scheduleSlotCount" class="schedule-slot-count"></span><div id="scheduleRightActions"></div></div></div>
          <div id="scheduleAvailability"></div><div id="scheduleCanvas"></div>
        </section>
      </div>
    </section>
    ${canCatalog ? `<div id="catalogOverlay" class="ui-overlay" hidden><button class="ui-overlay-backdrop" type="button" aria-label="Close academic setup"></button><section id="catalogEditor" class="form account-editor" role="dialog" aria-modal="true" aria-label="Academic setup" tabindex="-1"></section></div>` : ''}`;
  wrap.appendChild(main);
  mount(container, wrap);
  revealStack(main);

  const person = () => faculty.find(item => String(item.id) === selectedFaculty);
  const term = () => terms.find(item => String(item.id) === selectedTerm);
  const savedSlots = () => entries.filter(entry => String(entry.semester_id) === selectedTerm && String(entry.faculty_id) === selectedFaculty);
  const renderDayAgenda = () => {
    const agenda = main.querySelector('#facultyDayAgenda');
    if (!agenda) return;
    const activeTerm = term() && term().start_date <= localDate && term().end_date >= localDate;
    agenda.hidden = !activeTerm;
    if (!activeTerm) return;
    const classes = savedSlots().filter(slot => slot.day_of_week === todayName).sort((a, b) => minutes(a.start_time) - minutes(b.start_time));
    agenda.innerHTML = `<div class="faculty-day-head"><div><span class="eyebrow">${esc(todayName)} · ${esc(localDate)}</span><h2 id="facultyDayTitle">Today's classes</h2></div><span>${classes.length} class${classes.length === 1 ? '' : 'es'}</span></div>
      ${classes.length ? `<div class="faculty-day-list">${classes.map(slot => `<article class="faculty-day-class"><span class="faculty-day-time">${esc(clockTime(slot.start_time))}–${esc(clockTime(slot.end_time))}</span><strong>${esc(slot.subject_code || 'Class')} · ${esc(slot.subject_title || 'Scheduled class')}</strong><span>${esc(slot.section_code || 'Section')} · ${esc(slot.room_code || (slot.modality === 'Online' ? 'Online' : 'Room pending'))}</span></article>`).join('')}</div>`
      : '<p class="faculty-day-empty">No classes scheduled for today. Your full weekly timetable is below.</p>'}`;
  };
  const previewSlots = () => {
    const slots = savedSlots().filter(entry => !pendingDeletes.has(Number(entry.id)))
      .map(entry => draft?.kind === 'update' && Number(entry.id) === Number(draft.id)
        ? { ...entry, ...draft.payload,
          room_code: options.rooms?.find(room => Number(room.id) === Number(draft.payload.room_id))?.code || (draft.payload.modality === 'Online' ? 'Online' : entry.room_code),
          room_name: options.rooms?.find(room => Number(room.id) === Number(draft.payload.room_id))?.name || '', draft: true }
        : entry);
    if (draft?.kind === 'create') {
      const section = options.sections?.find(item => Number(item.id) === Number(draft.payload.section_id));
      const subject = options.subjects?.find(item => Number(item.id) === Number(draft.payload.subject_id));
      const room = options.rooms?.find(item => Number(item.id) === Number(draft.payload.room_id));
      slots.push({ ...draft.payload, id: 'draft', year_level: section?.year_level,
        subject_code: subject?.code, subject_title: subject?.title,
        room_code: room?.code || (draft.payload.modality === 'Online' ? 'Online' : ''), room_name: room?.name || '',
        draft: true });
    }
    return slots;
  };
  const resetEdit = () => { adding = false; selectedEntry = null; draft = null; openedBlock = null; pendingDeletes.clear(); };

  const renderNotice = () => {
    const chosen = term();
    main.querySelector('#scheduleNotice').innerHTML = chosen?.end_date < localDate
      ? `<span>Historical term ended ${esc(chosen.end_date)}</span>` : '';
  };

  const renderRoster = () => {
    const roster = main.querySelector('#scheduleRoster');
    const headTile = canCatalog && head ? facultyHeadTile(head, 'view schedule') : '';
    const orgArms = headTile && (options.programs || []).length > 1
      ? '<div class="faculty-org-tree-arms" aria-hidden="true"><span></span><span></span></div>' : '';
    const coordinatorTile = canCatalog ? code => {
      const coordinator = coordinatorForProgram(leaders, code);
      return coordinator ? facultyTile({
        id: coordinator.id, kind: 'coordinator',
        name: `${coordinator.first_name || ''} ${coordinator.last_name || ''}`.trim(),
        tags: [{ text: `${code} coordinator`, tone: 'accent' }],
        actionLabel: 'view schedule',
        search: `${coordinator.first_name} ${coordinator.last_name} ${coordinator.email || ''} ${code}`.toLowerCase(),
      }) : facultyTile({ kind: 'coordinator', name: 'Not assigned',
        tags: [{ text: `${code} coordinator`, tone: 'accent' }], empty: true });
    } : null;
    roster.innerHTML = headTile + orgArms + facultyProgramSections(directoryFaculty, options.programs || [], item => facultyTile({
      id: Number(item.id), kind: 'faculty',
      name: `${item.first_name || ''} ${item.last_name || ''}`.trim(),
      actionLabel: 'view schedule',
      search: `${item.first_name} ${item.last_name} ${item.last_name}, ${item.first_name} ${item.employee_no || ''} ${item.email || ''}`.toLowerCase(),
    }), false, leaders, 'faculty-tile-grid', coordinatorTile);
    filterFacultyCards(roster, search);
    roster.querySelectorAll('.faculty-tile[data-tile-id]').forEach(tile => tile.addEventListener('click', () => {
      const chosen = faculty.find(item => Number(item.id) === Number(tile.dataset.tileId));
      if (!chosen) { toast('No faculty schedule is available for this account.', true); return; }
      selectedFaculty = String(chosen.id);
      resetEdit(); mode = 'view'; renderAll();
    }));
  };

  const renderDetailButtons = () => {
    const buttons = main.querySelector('#scheduleDetailButtons');
    buttons.innerHTML = `<button type="button" class="btn ghost sm" id="viewCurrent" ${mode === 'view' ? 'aria-current="page"' : ''}>View Schedule</button><button type="button" class="btn ghost sm" id="downloadCurrent">Save Schedule</button>${canEdit ? `<button type="button" class="btn ghost sm" id="editCurrent" ${mode === 'edit' ? 'aria-current="page"' : ''}>Edit Schedule</button>` : ''}`;
    buttons.querySelector('#viewCurrent').addEventListener('click', () => {
      if ((draft || pendingDeletes.size) && !confirm('Discard unsaved schedule changes?')) return;
      resetEdit(); mode = 'view'; renderAll();
    });
    buttons.querySelector('#editCurrent')?.addEventListener('click', () => {
      if (mode === 'edit') return;
      resetEdit(); availabilityRoom = preferredRoom(selectedFaculty); mode = 'edit'; renderAll();
    });
    buttons.querySelector('#downloadCurrent').addEventListener('click', async () => {
      try { await downloadSchedulePng(savedSlots(), person().full_name, `${term()?.school_year || ''} ${term()?.name || ''}`); toast('Schedule download started.'); }
      catch (error) { toast(error.message, true); }
    });
  };

  const availableSections = () => {
    const programs = new Set((options.faculty_programs || []).filter(item => String(item.user_id) === selectedFaculty).map(item => Number(item.program_id)));
    return (options.sections || []).filter(section => String(section.semester_id) === selectedTerm && programs.has(Number(section.program_id)));
  };
  const refreshSubjects = () => {
    const sectionId = Number(main.querySelector('#editorSection')?.value);
    const section = availableSections().find(item => Number(item.id) === sectionId);
    const allowed = new Set((options.curriculum || []).filter(item => Number(item.program_id) === Number(section?.program_id)
      && Number(item.year_level) === Number(section?.year_level)
      && (!item.semester_code || item.semester_code === section?.semester_code)).map(item => Number(item.subject_id)));
    const select = main.querySelector('#editorSubject');
    if (select) select.innerHTML = (options.subjects || []).filter(item => allowed.has(Number(item.id)))
      .map(item => `<option value="${Number(item.id)}">${esc(item.code)} · ${esc(item.title)}</option>`).join('');
  };

  const stageFromForm = () => {
    const form = main.querySelector('#scheduleSlotForm');
    if (!form) return;
    if (pendingDeletes.size) return;
    const get = id => form.querySelector(id)?.value || '';
    const start = get('#editorStart');
    const end = get('#editorEnd');
    const modality = get('#editorModality');
    const roomId = get('#editorRoom');
    if (roomId) availabilityRoom = Number(roomId);
    const day = get('#editorDay');
    const overlaps = slot => slot.day_of_week === day && minutes(slot.start_time) < minutes(end)
      && minutes(slot.end_time) > minutes(start);
    const facultyConflict = savedSlots().some(slot => Number(slot.id) !== Number(selectedEntry?.id) && overlaps(slot));
    const roomConflict = modality !== 'Online' && (data.occupancy || []).some(slot =>
      String(slot.semester_id) === selectedTerm && Number(slot.room_id) === Number(roomId)
      && Number(slot.id) !== Number(selectedEntry?.id) && overlaps(slot));
    const valid = scheduleDays.includes(day) && minutes(start) >= firstMinute
      && minutes(end) <= lastMinute && minutes(end) > minutes(start)
      && (modality === 'Online' || Number(roomId) > 0) && !facultyConflict && !roomConflict;
    const payload = { day_of_week: day, start_time: start, end_time: end,
      room_id: roomId || null, modality, meeting_type: get('#editorType') };
    if (adding) Object.assign(payload, { faculty_id: Number(selectedFaculty),
      section_id: Number(get('#editorSection')), subject_id: Number(get('#editorSubject')) });
    draft = valid && (!adding || (payload.section_id && payload.subject_id))
      ? { kind: adding ? 'create' : 'update', id: selectedEntry?.id, payload } : null;
    main.querySelector('#editorHint').textContent = facultyConflict ? 'This faculty member already has a class at that time.'
      : roomConflict ? 'That room is occupied at the selected time. Check the gray booking on the right.'
      : valid ? 'Preview updated. Save on the right to apply this change.'
      : 'Choose a room and a time between 7:00 AM and 8:00 PM.';
    openedBlock = null;
    renderCalendar();
  };

  const renderEditor = () => {
    const panel = main.querySelector('#scheduleEditPanel');
    if (mode !== 'edit' || !canEdit) { panel.innerHTML = ''; return; }
    const sections = availableSections();
    const active = selectedEntry;
    panel.innerHTML = `<div class="schedule-edit-head"><div><span class="eyebrow">Editor</span><h3>${active ? 'Adjust class time' : adding ? 'New class time' : 'Edit schedule'}</h3></div><button class="btn ghost sm" type="button" id="newSlot">${icon('plus', 14)}Add time</button></div>
      ${pendingDeletes.size ? `<p class="schedule-edit-prompt">${pendingDeletes.size} block${pendingDeletes.size === 1 ? '' : 's'} marked for deletion. Select another block and choose Delete block, then Save once.</p>` : ''}
      ${!active && !adding ? '<p class="schedule-edit-prompt">Select a block on the timetable, or add a new class time.</p>' : `
      <form id="scheduleSlotForm" class="schedule-slot-form">
        ${active ? `<div class="schedule-assignment"><strong>${esc(active.subject_code)} · ${esc(active.subject_title)}</strong><span>${esc(active.section_code)} · Year ${Number(active.year_level)}</span></div>` : `
          <label for="editorSection">Section</label><select id="editorSection" required>${sections.map(section => `<option value="${Number(section.id)}">${esc(section.code)} · Year ${Number(section.year_level)}</option>`).join('')}</select>
          <label for="editorSubject">Subject</label><select id="editorSubject" required></select>`}
        <label for="editorDay">Day</label><select id="editorDay">${scheduleDays.map(day => `<option ${active?.day_of_week === day ? 'selected' : ''}>${day}</option>`).join('')}</select>
        <div class="schedule-time-pair"><div><label for="editorStart">Start</label><input id="editorStart" type="time" min="07:00" max="20:00" value="${esc(active?.start_time || '07:00')}" required></div><div><label for="editorEnd">End</label><input id="editorEnd" type="time" min="07:00" max="20:00" value="${esc(active?.end_time || '08:00')}" required></div></div>
        <label for="editorRoom">Room</label><select id="editorRoom"><option value="">Select a room</option>${(options.rooms || []).map(room => `<option value="${Number(room.id)}" ${Number(active?.room_id) === Number(room.id) ? 'selected' : ''}>${esc(room.code)} · ${esc(room.name)}</option>`).join('')}</select>
        <div class="schedule-time-pair"><div><label for="editorModality">Modality</label><select id="editorModality">${['Face to Face', 'Online', 'Hybrid'].map(value => `<option ${active?.modality === value ? 'selected' : ''}>${value}</option>`).join('')}</select></div><div><label for="editorType">Class type</label><select id="editorType">${['Lecture', 'Laboratory'].map(value => `<option ${active?.meeting_type === value ? 'selected' : ''}>${value}</option>`).join('')}</select></div></div>
        <p id="editorHint" class="schedule-edit-hint">Change a field to preview it on the right.</p>
      </form>`}`;
    panel.querySelector('#newSlot').addEventListener('click', () => {
      if (pendingDeletes.size) { toast('Save or cancel the marked deletions before adding a class time.', true); return; }
      if (draft && !confirm('Discard the unsaved change?')) return;
      selectedEntry = null; adding = true; draft = null; openedBlock = null; renderEditor(); renderCalendar();
      stageFromForm();
    });
    const form = panel.querySelector('#scheduleSlotForm');
    if (form) {
      form.addEventListener('submit', event => event.preventDefault());
      if (adding) refreshSubjects();
      if (pendingDeletes.size) form.querySelectorAll('input, select').forEach(control => { control.disabled = true; });
      form.querySelector('#editorSection')?.addEventListener('change', () => { refreshSubjects(); stageFromForm(); });
      form.addEventListener('input', stageFromForm);
      form.addEventListener('change', stageFromForm);
    }
  };

  const roomBookings = () => (data.occupancy || []).filter(item => String(item.semester_id) === selectedTerm
    && Number(item.room_id) === availabilityRoom && String(item.faculty_id) !== selectedFaculty);
  const renderCalendar = () => {
    if (mode === 'list') return;
    const slots = previewSlots();
    const chosen = person();
    main.querySelector('#scheduleName').textContent = chosen?.full_name || 'No faculty selected';
    main.querySelector('#scheduleTermLabel').textContent = term() ? `${term().school_year} · ${term().name}` : 'Choose an academic term';
    main.querySelector('#scheduleSlotCount').textContent = `${slots.length} weekly slot${slots.length === 1 ? '' : 's'}`;
    const availability = main.querySelector('#scheduleAvailability');
    availability.innerHTML = mode === 'edit' ? `<div class="schedule-availability"><label for="availabilityRoom">Other faculty bookings in</label><select id="availabilityRoom">${(options.rooms || []).map(room => `<option value="${Number(room.id)}" ${Number(room.id) === availabilityRoom ? 'selected' : ''}>${esc(room.code)} · ${esc(room.name)}</option>`).join('')}</select><span>${roomBookings().length} occupied slot${roomBookings().length === 1 ? '' : 's'} shown in gray</span></div>` : '';
    availability.querySelector('#availabilityRoom')?.addEventListener('change', event => { availabilityRoom = Number(event.target.value); renderCalendar(); });
    main.querySelector('#scheduleCanvas').innerHTML = renderWeekGrid(slots, { interactive: true, selectedId: openedBlock,
      canDelete: mode === 'edit' && canEdit, occupied: mode === 'edit' ? roomBookings() : [] });
    const slot = savedSlots().find(item => String(item.id) === String(openedBlock));
    const detail = main.querySelector('#scheduleSelectedDetail');
    detail.hidden = !slot;
    detail.textContent = slot ? `${slot.subject_code} · ${slot.subject_title}  |  ${slot.room_code || slot.modality} · ${slot.room_name || 'No classroom'}` : '';
    main.querySelectorAll('[data-block]').forEach(button => button.addEventListener('click', () => {
      const entry = savedSlots().find(item => String(item.id) === button.dataset.block);
      if (!entry) return;
      if (draft && !confirm('Discard the unsaved time change?')) return;
      openedBlock = entry.id;
      if (mode === 'edit' && canEdit) {
        adding = false; selectedEntry = entry; draft = null;
        availabilityRoom = Number(entry.room_id || availabilityRoom);
        renderEditor();
      }
      renderCalendar();
    }));
    main.querySelector('[data-close-block]')?.addEventListener('click', () => { openedBlock = null; renderCalendar(); });
    main.querySelector('[data-delete-block]')?.addEventListener('click', () => {
      if (mode !== 'edit' || !canEdit || !slot) return;
      if (draft && !confirm('Discard the unsaved time change and mark this block for deletion?')) return;
      pendingDeletes.add(Number(slot.id));
      draft = null;
      selectedEntry = null; adding = false; openedBlock = null;
      renderEditor(); renderCalendar();
    });
    const actions = main.querySelector('#scheduleRightActions');
    actions.innerHTML = mode === 'edit' && canEdit ? `<div class="schedule-right-actions"><span>${pendingDeletes.size ? `${pendingDeletes.size} block${pendingDeletes.size === 1 ? '' : 's'} marked for deletion` : draft ? 'Unsaved adjustment' : 'Select or add a class time'}</span><button type="button" class="btn ghost" id="cancelSchedule">Cancel</button><button type="button" class="btn primary" id="saveSchedule" ${draft || pendingDeletes.size ? '' : 'disabled'}>Save</button></div>` : '';
    actions.querySelector('#cancelSchedule')?.addEventListener('click', () => { resetEdit(); mode = 'view'; renderAll(); });
    actions.querySelector('#saveSchedule')?.addEventListener('click', async event => {
      if (!draft && !pendingDeletes.size) return;
      const button = event.currentTarget;
      button.disabled = true;
      try {
        if (pendingDeletes.size) await api.post('/api/schedules/batch-delete', { ids: [...pendingDeletes], faculty_id: Number(selectedFaculty), semester_id: Number(selectedTerm) });
        else if (draft.kind === 'update') await api.put(`/api/schedules/${draft.id}`, draft.payload);
        else await api.post('/api/schedules', draft.payload);
        toast('Schedule saved.');
        navigate(`/schedules?faculty=${selectedFaculty}`);
      } catch (error) { toast(error.message, true); button.disabled = false; }
    });
  };

  const renderAll = () => {
    main.querySelector('#scheduleDirectory').hidden = mode !== 'list';
    main.querySelector('#scheduleDetail').hidden = mode === 'list';
    main.querySelector('#scheduleWorkspace').className = `schedule-workspace is-${mode}`;
    renderNotice();
    if (mode === 'list') renderRoster();
    else { renderDayAgenda(); renderDetailButtons(); renderEditor(); renderCalendar(); }
    window.scrollTo(0, 0);
  };
  main.querySelector('#backToSchedules')?.addEventListener('click', () => {
    if ((draft || pendingDeletes.size) && !confirm('Discard unsaved schedule changes?')) return;
    resetEdit(); mode = 'list'; renderAll();
  });
  main.querySelector('#scheduleTerm').addEventListener('change', event => {
    if ((draft || pendingDeletes.size) && !confirm('Discard unsaved schedule changes?')) { event.target.value = selectedTerm; return; }
    selectedTerm = event.target.value;
    resetEdit();
    renderAll();
  });
  main.querySelector('#scheduleSearch').addEventListener('input', event => {
    search = event.target.value.trim().toLowerCase(); renderRoster();
  });
  main.querySelector('#openCatalog')?.addEventListener('click', () => openScheduleCatalog(main, options, terms, () => navigate('/schedules')));
  renderAll();
}
