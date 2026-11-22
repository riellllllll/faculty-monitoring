import { api } from '../core/api.js';
import { icon } from '../components/icons.js';

export default async function verifyEmailPage(container) {
  const token = new URLSearchParams(location.hash.split('?')[1] || '').get('token') || '';
  container.innerHTML = `<div class="login-wrap"><div class="login-card">
    <div class="mark">${icon('cap', 22)}</div>
    <div class="eyebrow">Faculty Monitoring System</div>
    <h2>Confirm your email</h2>
    <p class="lead">Use the one-use link sent to your new address. Your current address stays active until confirmation.</p>
    <button class="btn primary" id="confirmEmailBtn" type="button">Confirm email</button>
    <div class="err" id="confirmEmailStatus" role="status"></div>
  </div></div>`;
  const button = container.querySelector('#confirmEmailBtn');
  const status = container.querySelector('#confirmEmailStatus');
  button.addEventListener('click', async () => {
    button.disabled = true;
    try {
      await api.post('/api/auth/verify-email', { token });
      status.textContent = 'Email confirmed. You can now sign in with the new address.';
      button.remove();
      window.history.replaceState(null, '', '#/verify-email');
    } catch (error) {
      status.textContent = error.message || 'Could not confirm this email.';
      button.disabled = false;
    }
  });
}
