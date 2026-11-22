import { api } from '../core/api.js';
import { navigate } from '../core/router.js';
import { store } from '../core/store.js';
import { icon } from '../components/icons.js';

export default async function setPasswordPage(container) {
  const token = new URLSearchParams(location.hash.split('?')[1] || '').get('token') || '';
  container.innerHTML = `<div class="login-wrap"><div class="login-card">
    <div class="mark">${icon('cap', 22)}</div>
    <div class="eyebrow">Faculty Monitoring System</div>
    <h2>Set your password</h2>
    <p class="lead">Use the secure link from your account email. It is valid once for 24 hours.</p>
    <div class="row"><label for="newPassword">New password</label><input id="newPassword" type="password" minlength="8" maxlength="72" autocomplete="new-password"></div>
    <div class="row"><label for="confirmPassword">Confirm password</label><input id="confirmPassword" type="password" minlength="8" maxlength="72" autocomplete="new-password"></div>
    <button class="btn primary" id="setPasswordBtn">Set password</button>
    <div class="err" id="setupError" role="alert"></div>
  </div></div>`;
  const button = container.querySelector('#setPasswordBtn');
  const error = container.querySelector('#setupError');
  button.addEventListener('click', async () => {
    const password = container.querySelector('#newPassword').value;
    const confirm = container.querySelector('#confirmPassword').value;
    if (!token || password.length < 8 || password !== confirm) {
      error.textContent = 'Check the link and enter matching passwords of at least 8 characters.';
      return;
    }
    button.disabled = true;
    error.textContent = '';
    try {
      await api.post('/api/auth/set-password', { token, password, confirm_password: confirm });
      if (store.user) {
        try { await api.post('/api/auth/logout', {}); } catch (_) { /* Password is already set. */ }
        store.clear();
      }
      navigate('/login');
    } catch (e) {
      error.textContent = e.message;
      button.disabled = false;
    }
  });
}
