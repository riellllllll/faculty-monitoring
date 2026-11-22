import { api } from '../core/api.js';
import { navigate } from '../core/router.js';
import { toast } from './toast.js';
import { esc } from './ui.js';
import { icon } from './icons.js';

export function openEditor(main, panel, programs, user = null) {
  const overlay = main.querySelector('#accountOverlay');
  const editor = main.querySelector('#accountEditor');
  const opener = document.activeElement;
  const isFaculty = panel.role === 'faculty';
  const mayTeach = panel.role === 'program_coordinator';
  const isHead = panel.role === 'chairperson';
  const selected = new Set(user?.program_ids.map(Number) || (panel.programId ? [panel.programId] : []));
  overlay.hidden = false;
  document.body.classList.add('modal-open');
  editor.setAttribute('aria-label', `${user ? 'Edit' : 'Add'} ${panel.title}`);
  const close = () => {
    overlay.hidden = true;
    document.body.classList.remove('modal-open');
    opener?.focus?.();
  };
  editor.innerHTML = `
    <header class="account-editor-head">
      <div class="panel-head"><div><span class="account-scope">${esc(panel.scope)} / ${esc(panel.title)}</span><h2 id="accountEditorTitle">${user ? 'Edit' : 'Add'} ${esc(panel.title)}</h2></div>
        <button class="btn ghost sm" id="closeAccountEditor">${icon('x', 14)}Close</button></div>
      <p class="lead">${user ? 'Update this person’s account and assignment details.' : `Create a ${isFaculty ? 'faculty' : 'coordinator'} record and email a temporary password with the login link.`}</p>
    </header>
    <section class="account-section" aria-labelledby="accountIdentityTitle">
      <div class="account-section-head"><span class="account-section-number">01</span><div><h3 id="accountIdentityTitle">Personal information</h3><p>Name and contact details for the account.</p></div></div>
      <div class="row two"><div><label for="accountFirst">First name <span class="field-required" aria-hidden="true">*</span></label><input id="accountFirst" maxlength="80" value="${esc(user?.first_name)}" required></div>
        <div><label for="accountLast">Last name <span class="field-required" aria-hidden="true">*</span></label><input id="accountLast" maxlength="80" value="${esc(user?.last_name)}" required></div></div>
      <div class="row two"><div><label for="accountMiddle">Middle name</label><input id="accountMiddle" maxlength="80" value="${esc(user?.middle_name)}"></div>
        <div><label for="accountEmployee">Employee number</label><input id="accountEmployee" maxlength="30" value="${esc(user?.employee_no)}"></div></div>
      <div class="row two"><div><label for="accountEmail">Email <span class="field-required" aria-hidden="true">*</span></label><input id="accountEmail" type="email" maxlength="120" value="${esc(user?.email)}" required><small id="accountEmailFeedback" class="account-email-feedback" aria-live="polite">${user ? '' : 'Enter a valid email that is not registered in this system.'}</small><button type="button" class="btn ghost sm account-email-recovery" id="findInactiveFaculty" hidden>Find inactive faculty account</button></div>
        <div><label for="accountPhone">Phone</label><input id="accountPhone" maxlength="30" value="${esc(user?.phone)}"></div></div>
    </section>
    <section class="account-section" aria-labelledby="accountAssignmentTitle">
      <div class="account-section-head"><span class="account-section-number">02</span><div><h3 id="accountAssignmentTitle">Program assignment${isHead ? '' : ' <span class="field-required" aria-hidden="true">*</span>'}</h3><p>${isFaculty ? 'Choose the programs this faculty member belongs to.' : isHead ? 'The Department Chairperson oversees every program.' : 'Choose the program this coordinator manages.'}</p></div></div>
      ${mayTeach ? `<label class="account-check account-teaching"><input id="accountFaculty" type="checkbox" ${!user || user.roles.includes('faculty') ? 'checked' : ''}> Also teaches as faculty</label>` : ''}
      ${mayTeach ? `<div class="row"><label for="accountProgram">Assigned program</label><select id="accountProgram">${programs.map(p => `<option value="${Number(p.id)}" ${selected.has(Number(p.id)) ? 'selected' : ''}>${esc(p.code)} · ${esc(p.name)}</option>`).join('')}</select></div>` : ''}
      ${isFaculty ? `<div class="account-programs" role="group" aria-label="Program assignments">${programs.map(p => `<label class="account-check"><input type="checkbox" data-program="${Number(p.id)}" ${selected.has(Number(p.id)) ? 'checked' : ''}> ${esc(p.code)} · ${esc(p.name)}</label>`).join('')}</div>` : ''}
      ${mayTeach ? `<p class="account-section-note">Coordinator access is limited to the selected program.</p>` : ''}
    </section>
    ${isFaculty || mayTeach || isHead ? `<section class="account-section" aria-labelledby="accountEmploymentTitle">
      <div class="account-section-head"><span class="account-section-number">03</span><div><h3 id="accountEmploymentTitle">Employment details</h3><p>Teaching and appointment information.</p></div></div>
      <div class="row two"><div><label for="accountRank">Faculty rank</label><input id="accountRank" maxlength="40" value="${esc(user?.rank_code || 'Instructor')}"></div>
        <div><label for="accountEmployment">Employment type</label><select id="accountEmployment">${['Full-time', 'Part-time', 'Contractual', 'Visiting'].map(type => `<option ${user?.employment_type === type ? 'selected' : ''}>${type}</option>`).join('')}</select></div></div>
      <div class="row two"><div><label for="accountDesignation">Designation</label><input id="accountDesignation" maxlength="80" value="${esc(user?.designation)}"></div>
        <div><label for="accountSpecialization">Specialization</label><input id="accountSpecialization" maxlength="150" value="${esc(user?.field_of_specialization)}"></div></div>
      <div class="row"><label for="accountHireDate">Hire date</label><input id="accountHireDate" type="date" value="${esc(user?.hire_date)}"></div>
    </section>` : ''}
    <div class="actions"><span class="account-required-note"><span class="field-required" aria-hidden="true">*</span> Required fields</span><button class="btn ghost" id="cancelAccount">Cancel</button>
      <button class="btn primary" id="saveAccount">${user ? 'Save changes' : `Add ${isFaculty ? 'faculty' : 'coordinator'}`}</button></div>
  `;
  editor.querySelector('#closeAccountEditor').addEventListener('click', close);
  editor.querySelector('#cancelAccount').addEventListener('click', close);
  overlay.querySelector('.ui-overlay-backdrop').onclick = close;
  overlay.onkeydown = event => {
    if (event.key === 'Escape') close();
    if (event.key !== 'Tab') return;
    const focusable = [...editor.querySelectorAll('button, input, select')].filter(element => !element.disabled);
    const first = focusable[0];
    const last = focusable.at(-1);
    if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
    else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
  };
  const emailInput = editor.querySelector('#accountEmail');
  const emailFeedback = editor.querySelector('#accountEmailFeedback');
  const emailRecovery = editor.querySelector('#findInactiveFaculty');
  let checkedEmail = '';
  const showEmailFeedback = (message, state = '') => {
    emailFeedback.textContent = message;
    emailFeedback.dataset.state = state;
    emailRecovery.hidden = true;
  };
  emailRecovery.addEventListener('click', () => {
    const email = emailInput.value.trim();
    close();
    navigate(`/faculty?status=inactive&search=${encodeURIComponent(email)}`);
  });
  const checkNewEmail = async () => {
    if (user) return true;
    const email = emailInput.value.trim().toLowerCase();
    if (!email || !emailInput.checkValidity()) {
      showEmailFeedback('Enter a valid email address.', 'error');
      return false;
    }
    if (checkedEmail === email) return true;
    showEmailFeedback('Checking if this email is already registered…');
    try {
      await api.post('/api/faculty/accounts/check-email', { email });
      if (emailInput.value.trim().toLowerCase() !== email) return false;
      checkedEmail = email;
      showEmailFeedback('Email is not registered. Inbox ownership has not been verified.', 'success');
      return true;
    } catch (error) {
      if (emailInput.value.trim().toLowerCase() === email) {
        showEmailFeedback(error.message, 'error');
        emailRecovery.hidden = error.data?.errors?.code !== 'inactive_faculty';
      }
      return false;
    }
  };
  emailInput.addEventListener('input', () => {
    checkedEmail = '';
    showEmailFeedback(user ? '' : 'Enter a valid email that is not registered in this system.');
  });
  emailInput.addEventListener('blur', () => { if (!user && emailInput.value.trim()) void checkNewEmail(); });
  editor.querySelector('#saveAccount').addEventListener('click', async () => {
    const read = id => editor.querySelector(id).value.trim();
    const endpoint = isFaculty ? '/api/faculty/accounts' : mayTeach ? '/api/coordinators' : '/api/users';
    const programIds = isHead ? [] : panel.role === 'program_coordinator' ? [Number(editor.querySelector('#accountProgram').value)]
      : isFaculty ? Array.from(editor.querySelectorAll('[data-program]:checked'), input => Number(input.dataset.program)) : [];
    const data = {
      first_name: read('#accountFirst'), last_name: read('#accountLast'), middle_name: read('#accountMiddle'),
      employee_no: read('#accountEmployee'), email: read('#accountEmail'), phone: read('#accountPhone'),
      program_ids: programIds,
      ...(isHead ? { roles: ['chairperson'] } : {}),
      teaches_as_faculty: mayTeach && editor.querySelector('#accountFaculty').checked,
      rank_code: editor.querySelector('#accountRank')?.value.trim() || 'Instructor',
      employment_type: editor.querySelector('#accountEmployment')?.value || 'Full-time',
      designation: editor.querySelector('#accountDesignation')?.value.trim() || '',
      field_of_specialization: editor.querySelector('#accountSpecialization')?.value.trim() || '',
      hire_date: editor.querySelector('#accountHireDate')?.value || '',
    };
    if (!data.first_name || !data.last_name || !data.email || (!isHead && !programIds.length)) {
      toast('Complete the required account fields.', true); return;
    }
    const button = editor.querySelector('#saveAccount');
    button.disabled = true;
    try {
      if (!await checkNewEmail()) { button.disabled = false; emailInput.focus(); return; }
      const result = user ? await api.put(`${endpoint}/${user.id}`, data) : await api.post(endpoint, data);
      toast(result.message || (user ? 'Account updated.' : 'Account created.'), result.data?.email_status === 'failed');
      close();
      navigate('/faculty');
    } catch (error) {
      toast(error.message, true);
      button.disabled = false;
    }
  });
  editor.querySelector('#accountFirst').focus();
}
