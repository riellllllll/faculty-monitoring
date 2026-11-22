/**
 * Small markup primitives so every page speaks the same visual language.
 * Hierarchy comes from: eyebrow -> title -> subtitle -> content.
 */

import { esc, initials } from '../core/text.js';
import { renderAccount } from './account.js';
import { renderNotifications } from './notifications.js';

export { esc, initials };

/** Page title block: eyebrow, H1, supporting line, actions + account chip. */
export function pageHead({ eyebrow, title, sub = '', actions = '' }) {
  return `
    <header class="page-head">
      <div>
        ${eyebrow ? `<div class="eyebrow">${esc(eyebrow)}</div>` : ''}
        <h1>${title}</h1>
        ${sub ? `<p class="page-sub">${sub}</p>` : ''}
      </div>
      <div class="page-actions">${actions}${renderNotifications()}${renderAccount()}</div>
    </header>
  `;
}

/**
 * Scroll-entry reveal for a freshly mounted page.
 *
 * Blocks animate only once they are actually on screen (IntersectionObserver,
 * never a scroll listener), so the header lands first and content follows in
 * reading order with an 80ms cascade. Blocks already in the viewport are
 * revealed synchronously before paint to avoid a flash of full-opacity content
 * snapping back to zero.
 *
 * Nothing is ever pre-hidden in CSS — if the observer never runs, the page is
 * simply already visible. `prefers-reduced-motion` collapses the timeline to
 * zero via the stylesheet.
 */
export function revealStack(root, cap = 4) {
  if (!root) return;

  const blocks = Array.from(root.querySelectorAll(
    ':scope > .page-head, :scope > .notice, ' +
    ':scope > .section-head, :scope > .table-wrap, :scope > .form, ' +
    ':scope > .settings-stack, :scope > .grid-2'
  ));
  if (!blocks.length) return;

  const targets = [];
  blocks.forEach((node, i) => {
    if (node.matches('.grid-2')) {
      // Grids cascade per tile rather than moving as one slab.
      Array.from(node.children).forEach((child, j) => {
        child.style.setProperty('--i', Math.min(j, cap));
        targets.push(child);
      });
    } else {
      node.style.setProperty('--i', Math.min(i, cap));
      targets.push(node);
    }
  });

  const reduced = typeof matchMedia === 'function' &&
                  matchMedia('(prefers-reduced-motion: reduce)').matches;

  if (reduced || typeof IntersectionObserver !== 'function') {
    targets.forEach(t => t.classList.add('reveal'));
    return;
  }

  const io = new IntersectionObserver((entries, observer) => {
    entries.forEach(entry => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add('reveal');
      observer.unobserve(entry.target);
    });
  }, { rootMargin: '0px 0px -6% 0px', threshold: 0.04 });

  targets.forEach(t => {
    const r = t.getBoundingClientRect();
    if (r.top < window.innerHeight * 0.94 && r.bottom > 0) t.classList.add('reveal');
    else io.observe(t);
  });
}
