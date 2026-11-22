import { icon } from './icons.js';

export function toast(message, isError = false) {
  let t = document.querySelector('.toast');
  if (!t) {
    t = document.createElement('div');
    t.setAttribute('role', 'status');
    t.setAttribute('aria-live', 'polite');
    document.body.appendChild(t);
  }
  t.innerHTML = `${icon(isError ? 'alert' : 'check', 16)}<span></span>`;
  t.querySelector('span').textContent = message;
  t.className = 'toast show' + (isError ? ' err' : '');
  clearTimeout(t._timer);
  t._timer = setTimeout(() => { t.className = 'toast'; }, 3400);
}
