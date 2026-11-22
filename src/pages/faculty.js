import { api } from '../core/api.js';
import { el, mount } from '../core/dom.js';
import { renderNav, bindNav } from '../components/nav.js';
import { pageHead, esc, revealStack } from '../components/ui.js';
import { icon } from '../components/icons.js';
import { store } from '../core/store.js';
import { navigate } from '../core/router.js';
import { toast } from '../components/toast.js';
import { openEditor } from '../components/accountEditor.js';
import { facultyHeadTile, facultyTile, facultyPhoto, facultyProgramSections, filterFacultyCards, plainFaculty, coordinatorForProgram } from '../components/facultyCards.js';

export default async function facultyPage(container) {
  const pageParams = new URLSearchParams(location.hash.split('?')[1] || '');
  const showInactive = pageParams.get('status') === 'inactive';
  const initialSearch = pageParams.get('search') || '';
  const res = await api.get(`/api/faculty?is_active=${showInactive ? 0 : 1}`);
  const rows = res.data || [];
  const canManage = store.hasRole('chairperson', 'program_coordinator');
  const canManageCoordinators = store.hasRole('chairperson');
  const directory = canManage ? (await api.get('/api/faculty/accounts')).data : { users: [], programs: [] };
  const users = directory.users || [];
  const programs = directory.programs || [];
  const accountDirectory = canManageCoordinators ? (await api.get('/api/users')).data : { users: [] };
  const coordinatorDirectory = canManageCoordinators ? (await api.get('/api/coordinators')).data : { users: [] };
  const facultyPanel = { role: 'faculty', title: 'Faculty', scope: store.hasRole('program_coordinator') && !store.hasRole('chairperson') ? 'Assigned program' : 'Department' };
  const coordinatorPanel = { role: 'program_coordinator', title: 'Coordinator', scope: 'Program' };
  const headPanel = { role: 'chairperson', title: 'Department chairperson', scope: 'Administration' };
  const mayManage = user => canManage && user && user.roles.length === 1 && user.roles[0] === 'faculty' && (canManageCoordinators || user.program_ids.every(id => programs.some(p => Number(p.id) === Number(id))));

  // Leadership accounts, mapped to the row shape (role_codes + program_codes).
  const withProgramCodes = user => ({ ...user,
    role_codes: (user.roles || []).join(', '),
    program_codes: (programs || []).filter(p => (user.program_ids || []).includes(Number(p.id))).map(p => p.code).join(', ') });
  const headSource = canManageCoordinators
    ? (accountDirectory.users || []).find(user => (user.roles || []).includes('chairperson'))
    : rows.find(person => String(person.role_codes || '').includes('chairperson'));
  const head = headSource ? withProgramCodes(headSource) : null;
  const coordinators = canManageCoordinators
    ? (coordinatorDirectory.users || []).map(withProgramCodes)
    : [];
  const people = plainFaculty(rows); // coordinators and the head never repeat in the list
  const focusedInactive = showInactive && initialSearch
    ? rows.find(f => String(f.email || '').toLowerCase() === initialSearch.toLowerCase()) : null;
  const canRestoreFocused = focusedInactive && mayManage(users.find(u => Number(u.id) === Number(focusedInactive.id)));

  const wrap = el('div', { class: 'layout' });
  const navC = el('div');
  navC.innerHTML = renderNav('/faculty');
  bindNav(navC);
  wrap.appendChild(navC.firstElementChild);

  const headTile = showInactive || !head ? '' : facultyHeadTile(head);
  const orgArms = headTile && programs.length
    ? '<div class="faculty-org-tree-arms" aria-hidden="true"><span></span><span></span></div>' : '';
  const coordTileFor = code => {
    if (!canManageCoordinators) return '';
    const c = coordinatorForProgram(coordinators, code);
    return c ? facultyTile({
      id: c.id, kind: 'coordinator',
      name: `${c.first_name || ''} ${c.last_name || ''}`.trim(),
      tags: [{ text: `${code} coordinator`, tone: 'accent' }],
      inactive: !Number(c.is_active),
      search: `${c.first_name} ${c.last_name} ${c.email || ''} ${code}`.toLowerCase(),
    }) : facultyTile({ kind: 'coordinator', name: 'Not assigned', tags: [{ text: `${code} coordinator`, tone: 'accent' }], empty: true });
  };
  const facultyTileFor = f => facultyTile({
    id: Number(f.id), kind: 'faculty',
    name: `${f.first_name || ''} ${f.last_name || ''}`.trim(),
    inactive: !Number(f.is_active),
    search: `${f.first_name} ${f.last_name} ${f.last_name}, ${f.first_name} ${f.employee_no || ''} ${f.email || ''}`.toLowerCase(),
  });

  const main = el('div', { class: 'main' });
  main.innerHTML = `
    ${pageHead({
      eyebrow: 'People',
      title: 'Faculty member',
      sub: 'Teaching staff of the department, grouped by program',
      actions: `${canManageCoordinators ? '<button class="btn ghost sm" id="manageCoordinators">Coordinators</button>' : ''}${canManage ? `<button class="btn primary sm" id="addFaculty">${icon('plus', 14)}Add faculty</button>` : ''}<span class="scope-note">${people.length} member${people.length === 1 ? '' : 's'}</span>`,
    })}

    <div class="section-head">
      <h2>${showInactive ? 'Inactive faculty' : 'Faculties'}</h2>
      <div class="faculty-toolbar">
      ${canManage ? `<select id="facultyStatus" aria-label="Faculty status"><option value="active"${showInactive ? '' : ' selected'}>Active faculty</option><option value="inactive"${showInactive ? ' selected' : ''}>Inactive faculty</option></select>` : ''}
      <label class="search" style="width:290px">
        ${icon('search', 16)}
        <input id="rosterSearch" type="search" value="${esc(initialSearch)}"
               placeholder="Search name, employee no. or email" aria-label="Search faculty members" />
      </label>
      </div>
    </div>

    ${canRestoreFocused ? `<div class="inactive-recovery"><div><b>Existing inactive account</b><span>${esc(focusedInactive.first_name)} ${esc(focusedInactive.last_name)} · ${esc(focusedInactive.email)}</span></div><div class="account-member-actions"><button class="btn primary sm" data-restore-faculty="${Number(focusedInactive.id)}">Reactivate account</button><button class="btn danger sm" data-purge-faculty="${Number(focusedInactive.id)}">Delete permanently</button></div></div>` : ''}
    <div id="facultyDirectory" class="faculty-org-directory">
      ${headTile}
      ${orgArms}
      ${facultyProgramSections(people, programs, facultyTileFor, false, people, 'faculty-tile-grid', coordTileFor)}
      ${people.length ? '' : `<p class="faculty-directory-empty">${showInactive ? 'No inactive faculty.' : 'No faculty found.'}</p>`}
    </div>
    ${canManageCoordinators ? `<div id="managementOverlay" class="ui-overlay" hidden>
      <button class="ui-overlay-backdrop" type="button" aria-label="Close coordinator panel"></button>
      <section class="management-dialog" role="dialog" aria-modal="true" aria-labelledby="coordinatorDialogTitle" tabindex="-1">
      <div class="panel-head"><div><span class="account-scope">Administration</span><h2 id="coordinatorDialogTitle">Coordinators</h2></div><button class="btn ghost sm" id="closeManagement">${icon('x', 14)}Close</button></div>
      <p class="management-intro">Manage program coordinators.</p>
      <div class="management-toolbar"><button class="btn primary sm" id="addCoordinator">${icon('plus', 14)}Add coordinator</button></div>
      <div class="account-members">${coordinators.map(u => `<div class="account-member"><div class="account-member-main"><b>${esc(u.first_name)} ${esc(u.last_name)}</b><span>${esc(u.email)}</span><small>${esc(programs.filter(p => u.program_ids.includes(Number(p.id))).map(p => p.code).join(', '))} · ${Number(u.is_active) ? 'Active' : 'Inactive'}</small></div>
        <div class="account-member-actions"><button class="btn ghost sm" data-edit-coordinator="${Number(u.id)}">Edit</button>${Number(u.is_active) ? `<button class="btn danger sm" data-delete-coordinator="${Number(u.id)}">Delete</button>` : `<button class="btn ghost sm" data-restore-coordinator="${Number(u.id)}">Reactivate</button>`}</div></div>`).join('') || '<p class="account-empty">No coordinators yet.</p>'}</div>
      </section>
    </div>` : ''}
    <div id="facultyDetailOverlay" class="ui-overlay" hidden>
      <button class="ui-overlay-backdrop" type="button" aria-label="Close faculty details"></button>
      <section id="facultyDetail" class="management-dialog faculty-detail" role="dialog" aria-modal="true" aria-labelledby="facultyDetailTitle" tabindex="-1"></section>
    </div>
    <div id="accountOverlay" class="ui-overlay" hidden>
      <button class="ui-overlay-backdrop" type="button" aria-label="Close account form"></button>
      <section id="accountEditor" class="form account-editor" role="dialog" aria-modal="true" aria-label="Faculty editor" tabindex="-1"></section>
    </div>
    <div id="purgeOverlay" class="ui-overlay" hidden>
      <button class="ui-overlay-backdrop" type="button" aria-label="Cancel permanent deletion"></button>
      <section class="form account-purge-dialog" role="dialog" aria-modal="true" aria-labelledby="purgeTitle" tabindex="-1">
        <h2 id="purgeTitle">Delete faculty permanently?</h2>
        <p id="purgeIdentity"></p>
        <p>This removes the account and frees its email address. This cannot be undone. Accounts with linked teaching records cannot be deleted permanently.</p>
        <div class="actions"><button class="btn ghost" type="button" id="cancelPurge">Cancel</button><button class="btn danger" type="button" id="confirmPurge">Delete permanently</button></div>
      </section>
    </div>
  `;
  wrap.appendChild(main);
  mount(container, wrap);
  revealStack(main);

  /* ---------- Detail panel ---------- */

  const detailOverlay = main.querySelector('#facultyDetailOverlay');
  const detail = main.querySelector('#facultyDetail');
  let detailOpener = null;

  const closeDetail = () => {
    detailOverlay.hidden = true;
    document.body.classList.remove('modal-open');
    detailOpener?.focus();
    detailOpener = null;
  };

  function openDetail(tile) {
    const kind = tile.dataset.tileKind;
    if (!kind) return false;
    const id = Number(tile.dataset.tileId);
    const person = kind === 'faculty' ? people.find(f => Number(f.id) === id)
      : kind === 'coordinator' ? coordinators.find(u => Number(u.id) === id)
      : head;
    if (!person) return false;
    const name = `${person.first_name || ''} ${person.last_name || ''}`.trim();
    const active = Number(person.is_active);
    const programList = String(person.program_codes || '').split(',').map(part => part.trim()).filter(Boolean);
    const scopeLabel = kind === 'faculty' ? 'Faculty member'
      : kind === 'coordinator' ? `Program coordinator${programList.length ? ` · ${programList.join(' · ')}` : ''}`
      : 'Department chairperson';
    const editorUser = users.find(u => Number(u.id) === id);
    const isSelf = Number(person.id) === Number(store.user?.id);
    const row = (label, value, mono = false) => value
      ? `<div><dt>${esc(label)}</dt><dd${mono ? ' class="mono"' : ''}>${esc(value)}</dd></div>` : '';
    const detailRows = [
      row('Employee no.', person.employee_no, true),
      row('Rank', person.rank_code),
      row('Employment type', person.employment_type),
      row('Designation', person.designation),
      row('Specialization', person.field_of_specialization),
      row('Hire date', person.hire_date, true),
      row('Email', person.email),
      row('Phone', person.phone),
      row('Department', person.department_name || 'Department of Computer Studies'),
    ].join('');

    const actions = [`<button class="btn ghost sm" data-detail-action="schedule" type="button">Schedule</button>`];
    const deactivateButtons = () => active
      ? `<button class="btn ghost sm" data-detail-action="edit" type="button">Edit</button><button class="btn danger sm" data-detail-action="deactivate" type="button">Deactivate</button>`
      : `<button class="btn ghost sm" data-detail-action="edit" type="button">Edit</button><button class="btn ghost sm" data-detail-action="restore" type="button">Reactivate</button>`;
    if (kind === 'faculty' && mayManage(editorUser)) {
      actions.push(deactivateButtons());
      if (!active) actions.push(`<button class="btn danger sm" data-detail-action="purge" type="button">Delete permanently</button>`);
    } else if ((kind === 'coordinator' || kind === 'head') && canManageCoordinators) {
      actions.push(deactivateButtons());
    }
    detail.innerHTML = `
      <div class="panel-head">
        <div class="faculty-detail-head">${facultyPhoto(true)}
          <div><span class="account-scope">${esc(scopeLabel)}</span><h2 id="facultyDetailTitle">${esc(name)}</h2>
            <div class="faculty-detail-status"><span class="badge ${active ? 'approved' : 'draft'}">${active ? 'Active' : 'Inactive'}</span>${programList.map(code => `<span class="faculty-detail-pill">${esc(code)}</span>`).join('')}</div>
          </div>
        </div>
        <button class="btn ghost sm" id="facultyDetailClose" type="button">${icon('x', 14)}Close</button>
      </div>
      <dl class="faculty-detail-grid">${detailRows}</dl>
      <div class="faculty-detail-actions">${actions.join('')}</div>
    `;
    // The Chairperson cannot deactivate their own account; hide that action.
    if (kind === 'head' && isSelf) {
      detail.querySelectorAll('[data-detail-action="deactivate"]').forEach(button => { button.hidden = true; });
    }

    detail.querySelectorAll('[data-detail-action]').forEach(button => button.addEventListener('click', async () => {
      const action = button.dataset.detailAction;
      if (action === 'schedule') { closeDetail(); navigate(`/schedules?faculty=${Number(person.id)}`); return; }
      if (action === 'edit') {
        closeDetail();
        openEditor(main, kind === 'faculty' ? facultyPanel : kind === 'coordinator' ? coordinatorPanel : headPanel, programs,
          kind === 'faculty' ? editorUser : kind === 'coordinator' ? coordinators.find(u => Number(u.id) === id) : person);
        return;
      }
      try {
        if (action === 'deactivate') {
          const label = kind === 'faculty' ? `Remove ${name} from active faculty? Their past records will be kept.` : `Deactivate ${name}? Their past records will be kept.`;
          if (!confirm(label)) return;
          if (kind === 'faculty') await api.delete(`/api/faculty/accounts/${id}`);
          else if (kind === 'coordinator') await api.delete(`/api/coordinators/${id}`);
          else await api.delete(`/api/users/${id}`);
          toast(kind === 'faculty' ? 'Faculty removed from the active list.' : `${kind === 'head' ? 'Account' : 'Coordinator'} deactivated.`);
        } else if (action === 'restore') {
          if (kind === 'faculty') await api.post(`/api/faculty/accounts/${id}/restore`, {});
          else if (kind === 'coordinator') await api.post(`/api/coordinators/${id}/restore`, {});
          else await api.post(`/api/users/${id}/restore`, {});
          toast(kind === 'head' ? 'Account reactivated.' : `${kind === 'coordinator' ? 'Coordinator' : 'Faculty account'} reactivated.`);
        } else if (action === 'purge') {
          closeDetail();
          requestPurge(editorUser, tile);
          return;
        }
        closeDetail();
        navigate(showInactive ? '/faculty?status=inactive' : '/faculty');
      } catch (error) {
        toast(error.message, true);
      }
    }));

    detail.querySelector('#facultyDetailClose').addEventListener('click', closeDetail);
    detailOverlay.hidden = false;
    document.body.classList.add('modal-open');
    detailOpener = tile;
    detail.querySelector('#facultyDetailClose').focus();
    return true;
  }

  main.querySelectorAll('[data-tile-kind]').forEach(tile => tile.addEventListener('click', () => { openDetail(tile); }));

  detailOverlay.querySelector('.ui-overlay-backdrop').addEventListener('click', closeDetail);
  detailOverlay.addEventListener('keydown', event => {
    if (event.key === 'Escape') closeDetail();
    if (event.key !== 'Tab') return;
    const focusable = [...detail.querySelectorAll('button')].filter(element => !element.disabled && !element.hidden);
    const first = focusable[0];
    const last = focusable.at(-1);
    if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
    else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
  });

  /* ---------- Toolbar, editor, coordinator panel ---------- */

  const managementOverlay = main.querySelector('#managementOverlay');
  const managementTrigger = main.querySelector('#manageCoordinators');
  const closeManagement = () => {
    if (!managementOverlay) return;
    managementOverlay.hidden = true;
    document.body.classList.remove('modal-open');
    managementTrigger?.focus();
  };
  managementTrigger?.addEventListener('click', () => {
    managementOverlay.hidden = false;
    document.body.classList.add('modal-open');
    managementOverlay.querySelector('#closeManagement').focus();
  });
  managementOverlay?.querySelector('#closeManagement').addEventListener('click', closeManagement);
  managementOverlay?.querySelector('.ui-overlay-backdrop').addEventListener('click', closeManagement);
  managementOverlay?.addEventListener('keydown', event => {
    if (event.key === 'Escape') closeManagement();
    if (event.key !== 'Tab') return;
    const focusable = [...managementOverlay.querySelectorAll('.management-dialog button')].filter(element => !element.disabled);
    const first = focusable[0];
    const last = focusable.at(-1);
    if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
    else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
  });

  main.querySelector('#addFaculty')?.addEventListener('click', () => openEditor(main, facultyPanel, programs));
  main.querySelector('#facultyStatus')?.addEventListener('change', event => {
    navigate(event.target.value === 'inactive' ? '/faculty?status=inactive' : '/faculty');
  });
  main.querySelector('#addCoordinator')?.addEventListener('click', () => { closeManagement(); openEditor(main, coordinatorPanel, programs); });
  main.querySelectorAll('[data-restore-faculty]').forEach(button => button.addEventListener('click', async () => {
    const user = users.find(u => Number(u.id) === Number(button.dataset.restoreFaculty));
    if (!mayManage(user)) return;
    try { await api.post(`/api/faculty/accounts/${user.id}/restore`, {}); toast('Faculty account reactivated.'); navigate('/faculty'); }
    catch (error) { toast(error.message, true); }
  }));
  main.querySelectorAll('[data-edit-coordinator]').forEach(button => button.addEventListener('click', () => {
    const user = coordinators.find(u => Number(u.id) === Number(button.dataset.editCoordinator));
    if (user) { closeManagement(); openEditor(main, coordinatorPanel, programs, user); }
  }));
  main.querySelectorAll('[data-delete-coordinator]').forEach(button => button.addEventListener('click', async () => {
    const user = coordinators.find(u => Number(u.id) === Number(button.dataset.deleteCoordinator));
    if (!user || !confirm(`Deactivate ${user.first_name} ${user.last_name}?`)) return;
    try { await api.delete(`/api/coordinators/${user.id}`); toast('Coordinator deactivated.'); closeManagement(); navigate('/faculty'); }
    catch (error) { toast(error.message, true); }
  }));
  main.querySelectorAll('[data-restore-coordinator]').forEach(button => button.addEventListener('click', async () => {
    try { await api.post(`/api/coordinators/${button.dataset.restoreCoordinator}/restore`, {}); toast('Coordinator reactivated.'); closeManagement(); navigate('/faculty'); }
    catch (error) { toast(error.message, true); }
  }));

  /* ---------- Permanent deletion ---------- */

  const purgeOverlay = main.querySelector('#purgeOverlay');
  let purgeUser = null;
  let purgeOpener = null;
  const closePurge = () => {
    purgeOverlay.hidden = true;
    document.body.classList.remove('modal-open');
    purgeUser = null;
    purgeOpener?.focus();
  };
  const requestPurge = (user, opener) => {
    if (!mayManage(user) || Number(user.is_active)) return;
    purgeUser = user;
    purgeOpener = opener;
    purgeOverlay.querySelector('#purgeIdentity').textContent = `${user.first_name} ${user.last_name} · ${user.email}`;
    purgeOverlay.hidden = false;
    document.body.classList.add('modal-open');
    purgeOverlay.querySelector('#cancelPurge').focus();
  };
  main.querySelectorAll('[data-purge-faculty]').forEach(button => button.addEventListener('click', () => {
    requestPurge(users.find(u => Number(u.id) === Number(button.dataset.purgeFaculty)), button);
  }));
  purgeOverlay.querySelector('#cancelPurge').addEventListener('click', closePurge);
  purgeOverlay.querySelector('.ui-overlay-backdrop').addEventListener('click', closePurge);
  purgeOverlay.addEventListener('keydown', event => {
    if (event.key === 'Escape') closePurge();
    if (event.key !== 'Tab') return;
    const cancel = purgeOverlay.querySelector('#cancelPurge');
    const confirm = purgeOverlay.querySelector('#confirmPurge');
    if (event.shiftKey && document.activeElement === cancel) { event.preventDefault(); confirm.focus(); }
    else if (!event.shiftKey && document.activeElement === confirm) { event.preventDefault(); cancel.focus(); }
  });
  purgeOverlay.querySelector('#confirmPurge').addEventListener('click', async () => {
    if (!purgeUser) return;
    const user = purgeUser;
    const button = purgeOverlay.querySelector('#confirmPurge');
    button.disabled = true;
    try {
      const result = await api.delete(`/api/faculty/accounts/${user.id}/permanent`, { confirm_email: user.email });
      toast(result.message);
      closePurge();
      navigate('/faculty?status=inactive');
    } catch (error) {
      toast(error.message, true);
    } finally {
      button.disabled = false;
    }
  });

  // Client-side faculty search (filters existing tiles, no extra request).
  const search = main.querySelector('#rosterSearch');
  const filterRows = () => {
    const q = search.value.trim().toLowerCase();
    const visible = filterFacultyCards(main.querySelector('#facultyDirectory'), q);
    const count = main.querySelector('.scope-note');
    if (count) count.textContent = `${visible} member${visible === 1 ? '' : 's'}`;
  };
  if (search) {
    search.addEventListener('input', filterRows);
    if (initialSearch) filterRows();
  }
}
