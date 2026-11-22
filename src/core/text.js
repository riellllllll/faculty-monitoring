/**
 * Text helpers shared across modules.
 *
 * These live apart from the markup primitives in components/ui.js so that a
 * component can build its own HTML (e.g. the account chip) without creating an
 * import cycle back through ui.js.
 */

export function esc(v) {
  return String(v ?? '')
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

export function initials(...parts) {
  const letters = parts.filter(Boolean).map(p => String(p).trim()[0] || '').join('');
  return (letters || '?').toUpperCase().slice(0, 2);
}
