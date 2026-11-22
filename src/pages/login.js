import { api } from '../core/api.js';
import { store } from '../core/store.js';
import { navigate } from '../core/router.js';
import { toast } from '../components/toast.js';
import { icon } from '../components/icons.js';
import { esc } from '../components/ui.js';

export default async function loginPage(container) {
  container.innerHTML = `
    <div class="login-wrap">
      <div class="login-card">
        <div class="mark">${icon('cap', 22)}</div>
        <div class="eyebrow">Faculty Monitoring System</div>
        <h2>Sign in to your record</h2>
        <p class="lead">Verify classroom attendance and track teaching hours against scheduled classes.</p>
        ${store.user ? `<p class="login-session-note">Signed in as <strong>${esc(store.user.email)}</strong>. Enter the emailed credentials below to switch accounts.</p>` : ''}

        <div class="row"><label for="email">Email</label><input id="email" type="email" placeholder="Enter your email" autocomplete="username" /></div>
        <div class="row">
          <label for="password">Password</label>
          <div class="pw">
            <input id="password" type="password" placeholder="Enter your password" autocomplete="current-password" />
            <button type="button" class="pw-toggle" id="pwToggle" aria-pressed="false" aria-label="Show password"></button>
          </div>
        </div>

        <button class="btn primary" id="loginBtn"><span id="loginLabel">Sign in</span>${icon('arrowRight', 16)}</button>
        <div class="hint-row">Press <kbd>Enter</kbd> to continue</div>
        <div class="err" id="err" role="alert"></div>

      </div>
    </div>
  `;

  const btn = container.querySelector('#loginBtn');
  const label = container.querySelector('#loginLabel');
  const err = container.querySelector('#err');
  const email = container.querySelector('#email');
  const password = container.querySelector('#password');

  const doLogin = async () => {
    err.textContent = '';
    btn.disabled = true;
    label.textContent = 'Signing in';
    try {
      const res = await api.post('/api/auth/login', {
        email: email.value.trim(),
        password: password.value,
      });
      store.setUser(res.data.user);
      toast('Welcome back.');
      const pendingRoom = sessionStorage.getItem('postLoginRoom');
      sessionStorage.removeItem('postLoginRoom');
      navigate(res.data.user.must_change_password ? '/settings'
        : /^\/room\?code=[a-f0-9]{32}$/.test(pendingRoom || '') ? pendingRoom : '/dashboard');
    } catch (e) {
      err.textContent = e.message || 'Login failed.';
      btn.disabled = false;
      label.textContent = 'Sign in';
    }
  };

  btn.addEventListener('click', doLogin);
  email.addEventListener('keydown', (e) => { if (e.key === 'Enter') doLogin(); });
  password.addEventListener('keydown', (e) => { if (e.key === 'Enter') doLogin(); });

  // Reveal toggle: flips the field in place so the value can be checked
  // before submitting, without moving the row or losing focus.
  const pwToggle = container.querySelector('#pwToggle');
  let pwVisible = false;

  const paintPw = () => {
    password.type = pwVisible ? 'text' : 'password';
    pwToggle.innerHTML = icon(pwVisible ? 'eyeSlash' : 'eye', 18);
    pwToggle.classList.toggle('on', pwVisible);
    pwToggle.setAttribute('aria-pressed', String(pwVisible));
    pwToggle.setAttribute('aria-label', pwVisible ? 'Hide password' : 'Show password');
  };

  pwToggle.addEventListener('click', () => {
    pwVisible = !pwVisible;
    paintPw();
    password.focus();
  });

  paintPw();
}
