const BASE = '';
let csrfToken = null;
let csrfPending = null;

async function securityToken() {
  if (csrfToken) return csrfToken;
  if (!csrfPending) {
    csrfPending = fetch(BASE + '/api/auth/csrf', { credentials: 'include', headers: { Accept: 'application/json' } })
      .then(async response => {
        const payload = await response.json();
        if (!response.ok || !payload?.data?.token) throw new Error('Could not start a secure session. Refresh and try again.');
        return payload.data.token;
      }).finally(() => { csrfPending = null; });
  }
  csrfToken = await csrfPending;
  return csrfToken;
}

export async function request(method, url, body = null, retried = false) {
  const changing = !['GET', 'HEAD'].includes(method);
  const opts = {
    method,
    headers: { 'Accept': 'application/json' },
    credentials: 'include',
  };
  if (changing) opts.headers['X-CSRF-Token'] = await securityToken();
  if (body !== null) {
    opts.headers['Content-Type'] = 'application/json';
    opts.body = JSON.stringify(body);
  }
  const res = await fetch(BASE + url, opts);
  let data = null;
  try { data = await res.json(); } catch (e) { data = { success: false, message: 'Invalid response' }; }
  if (!res.ok || data?.success === false) {
    if (res.status === 403 && data?.errors?.code === 'csrf' && changing && !retried) {
      csrfToken = null;
      return request(method, url, body, true);
    }
    const err = new Error(data?.message || `HTTP ${res.status}`);
    err.status = res.status;
    err.data = data;
    throw err;
  }
  if (url === '/api/auth/logout') csrfToken = null;
  return data;
}

export const api = {
  get: (u) => request('GET', u),
  post: (u, b) => request('POST', u, b),
  put: (u, b) => request('PUT', u, b),
  delete: (u, b = {}) => request('DELETE', u, b),
};
