import { api } from '../core/api.js';
import { store } from '../core/store.js';
import { el, mount } from '../core/dom.js';
import { renderNav, bindNav } from '../components/nav.js';
import { renderAccount } from '../components/account.js';
import { toast } from '../components/toast.js';
import { pageHead, esc, revealStack } from '../components/ui.js';
import { icon } from '../components/icons.js';
import { navigate } from '../core/router.js';

export default async function settingsPage(container) {
  const profile = (await api.get('/api/profile')).data;
  const mustChangePassword = Boolean(profile.must_change_password);

  const wrap = el('div', { class: 'layout' });
  const navC = el('div');
  navC.innerHTML = renderNav('/settings');
  bindNav(navC);
  wrap.appendChild(navC.firstElementChild);

  const main = el('main', { class: 'main settings-main' });
  main.innerHTML = `
    ${pageHead({
      eyebrow: 'Account',
      title: 'Settings',
      sub: 'Update your details and keep your account secure.',
    })}

    ${mustChangePassword ? `<div class="notice warning">${icon('alert', 17)}<span>Change your initial password before using the rest of the system.</span></div>` : ''}
    <div class="settings-stack">
      ${accountCard(profile)}
      ${passwordCard()}
    </div>
  `;
  wrap.appendChild(main);
  mount(container, wrap);
  revealStack(main);

  bindAccount(main, profile);
  bindPassword(main);
}

// ---------------------------------------------------------------------------
// Account settings
// ---------------------------------------------------------------------------
function accountCard(p) {
  const roles = (p.roles || []).map(r => `<span class="pill">${esc(r.replace(/_/g, ' '))}</span>`).join('');
  const programs = (p.programs || []).map(x => `<span class="pill">${esc(x.code)}</span>`).join('') || '—';

  return `
    <section class="form settings-profile" aria-labelledby="settingsProfileTitle">
      <div class="form-title"><span class="ico">${icon('user', 17)}</span><h2 id="settingsProfileTitle">Profile</h2></div>
      <p class="lead">Your name appears on teaching records and audit entries.</p>

      <fieldset class="settings-form-group">
        <legend>Personal details</legend>
        <div class="settings-field-grid">
          <div><label for="p_first">First name</label><input id="p_first" autocomplete="given-name" value="${esc(p.first_name)}" /></div>
          <div><label for="p_last">Last name</label><input id="p_last" autocomplete="family-name" value="${esc(p.last_name)}" /></div>
          <div><label for="p_middle">Middle name</label><input id="p_middle" autocomplete="additional-name" value="${esc(p.middle_name)}" /></div>
          <div><label for="p_suffix">Suffix</label><input id="p_suffix" autocomplete="honorific-suffix" value="${esc(p.suffix)}" /></div>
        </div>
      </fieldset>

      <fieldset class="settings-form-group">
        <legend>Contact</legend>
        <div class="settings-contact-fields">
          <div><label for="p_email">Email</label><input id="p_email" type="email" autocomplete="email" aria-describedby="pEmailNote" value="${esc(p.email)}" /><small id="pEmailNote">${p.pending_email ? `Confirmation pending for ${esc(p.pending_email)}.` : 'A new address requires confirmation by email.'}</small></div>
          <div><label for="p_phone">Phone</label><input id="p_phone" type="tel" autocomplete="tel" value="${esc(p.phone)}" /></div>
        </div>
      </fieldset>

      <section class="settings-form-group" aria-labelledby="settingsAssignmentTitle">
        <h3 id="settingsAssignmentTitle">Account details</h3>
        <p>These details are managed by the department.</p>
        <dl class="settings-facts">
          <div><dt>Employee no.</dt><dd>${esc(p.employee_no) || '—'}</dd></div>
          <div><dt>Department</dt><dd>${esc(p.department_name) || '—'}</dd></div>
          <div><dt>Roles</dt><dd>${roles || '—'}</dd></div>
          <div><dt>Programs</dt><dd>${programs}</dd></div>
        </dl>
      </section>

      <div class="actions"><button class="btn primary" id="saveProfile">${icon('check', 16)}Save changes</button></div>
    </section>
  `;
}

function bindAccount(main, p) {
  const btn = main.querySelector('#saveProfile');
  if (!btn) return;

  btn.addEventListener('click', async () => {
    btn.disabled = true;
    try {
      const result = await api.put('/api/profile', {
        first_name:  main.querySelector('#p_first').value,
        last_name:   main.querySelector('#p_last').value,
        middle_name: main.querySelector('#p_middle').value,
        suffix:      main.querySelector('#p_suffix').value,
        email:       main.querySelector('#p_email').value,
        phone:       main.querySelector('#p_phone').value,
      });
      const me = (await api.get('/api/auth/me')).data;
      store.setUser(me);
      main.querySelector('#p_email').value = me.email;
      if (result.data?.pending_email) main.querySelector('#pEmailNote').textContent = result.data.email_status === 'sent'
        ? `Confirmation pending for ${result.data.pending_email}.` : 'Confirmation email failed. Try saving the new address again later.';
      toast(result.message || 'Profile saved.', result.data?.email_status === 'failed');

      // Refresh the sidebar so the new name shows immediately.
      const wrapEl = main.parentElement;
      const sidebar = wrapEl?.querySelector('.sidebar');
      if (sidebar) {
        const actions = main.querySelector('.page-actions');
        actions.append(...sidebar.querySelectorAll('.sidebar-utilities .notification, .sidebar-utilities .account'));
        const account = actions.querySelector('.account');
        if (account) {
          const updated = document.createElement('div');
          updated.innerHTML = renderAccount();
          account.replaceWith(updated.firstElementChild);
        }
        const holder = document.createElement('div');
        holder.innerHTML = renderNav('/settings');
        sidebar.replaceWith(holder.firstElementChild);
        bindNav(wrapEl);
      }
    } catch (e) {
      toast(e.message, true);
    } finally {
      btn.disabled = false;
    }
  });
}

// ---------------------------------------------------------------------------
// Password
// ---------------------------------------------------------------------------
function passwordCard() {
  return `
    <section class="form password-form" aria-labelledby="settingsPasswordTitle">
      <div class="form-title tone-warning"><span class="ico">${icon('lock', 17)}</span><h2 id="settingsPasswordTitle">Change password</h2></div>
      <p class="lead">Use at least 8 characters. You stay signed in after changing it.</p>
      <div class="row"><label for="pw_current">Current password</label><input id="pw_current" type="password" autocomplete="current-password" /></div>
      <div class="row two">
        <div><label for="pw_new">New password</label><input id="pw_new" type="password" autocomplete="new-password" /></div>
        <div><label for="pw_confirm">Confirm new password</label><input id="pw_confirm" type="password" autocomplete="new-password" /></div>
      </div>
      <div class="actions"><button class="btn primary" id="savePassword">${icon('shieldCheck', 16)}Change password</button></div>
    </section>
  `;
}

function bindPassword(main) {
  const btn = main.querySelector('#savePassword');
  if (!btn) return;

  btn.addEventListener('click', async () => {
    const cur = main.querySelector('#pw_current');
    const nw  = main.querySelector('#pw_new');
    const cf  = main.querySelector('#pw_confirm');

    btn.disabled = true;
    try {
      await api.post('/api/profile/password', {
        current_password: cur.value,
        new_password: nw.value,
        confirm_password: cf.value,
      });
      toast('Password changed.');
      cur.value = nw.value = cf.value = '';
      if (store.user?.must_change_password) {
        store.user.must_change_password = 0;
        navigate('/dashboard');
      }
    } catch (e) {
      toast(e.message, true);
    } finally {
      btn.disabled = false;
    }
  });
}


