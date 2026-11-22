import { esc } from './ui.js';

const codes = value => String(value || '').split(',').map(part => part.trim()).filter(Boolean);
const hasRole = (person, role) => codes(person.role_codes).includes(role);
const fullName = person => `${person.first_name || ''} ${person.last_name || ''}`.trim();

/* Shared profile avatar — the gray circle + silhouette placeholder shown for
   every member until a real photo is available. Painted inline so it stays
   crisp at any size and needs no external asset. */
const AVATAR = `<svg viewBox="0 0 96 96" focusable="false" aria-hidden="true">
  <rect width="96" height="96" fill="#d5d8dc"/>
  <circle cx="48" cy="41" r="16" fill="#75797e"/>
  <path d="M19 96c3-17 14-25 29-25s26 8 29 25z" fill="#75797e"/>
</svg>`;

export function facultyPhoto(small = false) {
  return `<span class="faculty-photo-placeholder${small ? ' is-small' : ''}" aria-hidden="true">${AVATAR}</span>`;
}

export function leadershipFromAccounts(users, programs, departmentName) {
  return (users || []).filter(user => Number(user.is_active) &&
    (user.roles || []).some(role => role === 'chairperson' || role === 'program_coordinator'))
    .map(user => ({ ...user, role_codes: user.roles.join(', '),
      program_codes: (programs || []).filter(program => user.program_ids.includes(Number(program.id)))
        .map(program => program.code).join(', '), department_name: departmentName }));
}

export function facultyLeadership(rows) {
  const head = rows.find(person => hasRole(person, 'chairperson'));
  if (!head) return '';
  return `<section class="faculty-leadership" aria-label="Department head">
    ${facultyPhoto()}
    <div class="faculty-leadership-copy"><span>Department head</span><h2>${esc(fullName(head))}</h2><p>${esc(head.department_name || 'Department of Computer Studies')}</p></div>
    <span class="faculty-leadership-role">Chairperson</span>
  </section>`;
}

/* ---------- Square name tiles (Faculty page) ----------
   A tile carries the member's profile avatar and name; role/program context
   lives in the optional tag, every other detail in the panel the tile opens. */

export const isLeader = person => hasRole(person, 'chairperson') || hasRole(person, 'program_coordinator');
export const plainFaculty = rows => (rows || []).filter(person => !isLeader(person));

export function facultyTile({ id = 0, kind, name, tags = [], inactive = false, empty = false, search = '', actionLabel = 'view details' }) {
  const label = empty ? 'Not assigned' : name || 'Unknown';
  const tileTags = (empty ? tags : inactive ? [...tags, { text: 'Inactive' }] : tags)
    .map(tag => `<span class="faculty-tile-tag${tag.tone === 'accent' ? ' accent' : ''}">${esc(tag.text)}</span>`)
    .join('');
  return `<button type="button" class="faculty-tile${kind !== 'faculty' ? ' faculty-leader-tile' : ''}" data-tile-kind="${esc(kind)}"${id ? ` data-tile-id="${Number(id)}"` : ''}${kind === 'faculty' && id ? ` data-faculty-id="${Number(id)}"` : ''} data-faculty-card data-search="${esc((search || label).toLowerCase())}"${inactive ? ' data-state="inactive"' : ''}${empty ? ' disabled' : ''} aria-label="${esc(label)}${empty ? '' : ` — ${esc(actionLabel)}`}">
    ${tileTags}<span class="faculty-tile-avatar" aria-hidden="true">${AVATAR}</span><span class="faculty-tile-name">${esc(label)}</span>
  </button>`;
}

export function coordinatorForProgram(coordinators, code) {
  const matches = (coordinators || []).filter(person => hasRole(person, 'program_coordinator') && codes(person.program_codes).includes(code));
  return matches.find(person => Number(person.is_active)) || matches[0] || null;
}

export function facultyHeadTile(head, actionLabel = 'view details') {
  if (!head) return '';
  return `<section class="faculty-tile-strip" aria-label="Department head">
    <div class="faculty-tile-grid faculty-tile-grid-center">${facultyTile({
      id: head.id, kind: 'head', name: fullName(head),
      tags: [{ text: 'Department head' }],
      actionLabel,
      inactive: !Number(head.is_active),
      search: `${fullName(head)} ${head.email || ''}`.toLowerCase(),
    })}</div>
  </section>`;
}

export function facultyProgramSections(rows, catalog, renderCard, showCoordinators = false, leaders = rows, listClass = '', coordinatorTile = null) {
  const known = new Map((catalog || []).map(program => [program.code, program.name]));
  const assigned = new Set(rows.flatMap(person => codes(person.program_codes)));
  const programs = ['BSIT', 'BSCS'].filter(code => known.has(code) || assigned.has(code));
  for (const code of assigned) if (!programs.includes(code)) programs.push(code);
  const labels = { BSIT: 'Information Technology', BSCS: 'Computer Science' };
  const sections = programs.map(code => {
    const members = rows.filter(person => codes(person.program_codes).includes(code));
    const coordinator = leaders.find(person => hasRole(person, 'program_coordinator') && codes(person.program_codes).includes(code));
    return `<section class="faculty-program" data-faculty-group aria-label="${esc(known.get(code) || labels[code] || code)} faculty">
      <header class="faculty-program-head"><div><span class="faculty-program-code">${esc(code)}</span><h3>${esc(labels[code] || known.get(code) || code)}</h3></div><span class="faculty-program-count" data-group-count>${members.length} member${members.length === 1 ? '' : 's'}</span></header>
      ${typeof coordinatorTile === 'function' ? coordinatorTile(code) : showCoordinators ? `<div class="faculty-program-lead">${coordinator ? facultyPhoto(true) : ''}<div><span>Program coordinator</span><strong>${coordinator ? esc(fullName(coordinator)) : 'Not assigned'}</strong></div></div>` : ''}
      <div class="faculty-card-list${listClass ? ` ${listClass}` : ''}">${members.map(renderCard).join('')}</div>
      <p class="faculty-group-empty" ${members.length ? 'hidden' : ''}>${members.length ? 'No matching faculty.' : 'No faculty assigned yet.'}</p>
    </section>`;
  }).join('');
  const unassigned = rows.filter(person => !codes(person.program_codes).length);
  return `<div class="faculty-program-grid">${sections}</div>${unassigned.length ? `<section class="faculty-unassigned"><h3>Unassigned faculty</h3><div class="faculty-card-list${listClass ? ` ${listClass}` : ''}">${unassigned.map(renderCard).join('')}</div></section>` : ''}`;
}

export function filterFacultyCards(root, query) {
  const visible = new Set();
  root.querySelectorAll('[data-faculty-group]').forEach(group => {
    let count = 0;
    group.querySelectorAll('[data-faculty-card]').forEach(card => {
      if (card.classList.contains('faculty-leader-tile')) return; // head & coordinator tiles filter themselves out of member counts
      const matches = !query || card.dataset.search.includes(query);
      card.hidden = !matches;
      if (matches && card.dataset.facultyId) visible.add(card.dataset.facultyId);
      if (matches) count++;
    });
    group.querySelector('[data-group-count]').textContent = `${count} member${count === 1 ? '' : 's'}`;
    group.querySelector('.faculty-group-empty').hidden = count > 0;
  });
  root.querySelectorAll('.faculty-unassigned [data-faculty-card]').forEach(card => {
    const matches = !query || card.dataset.search.includes(query);
    card.hidden = !matches;
    if (matches && card.dataset.facultyId) visible.add(card.dataset.facultyId);
  });
  return visible.size;
}
