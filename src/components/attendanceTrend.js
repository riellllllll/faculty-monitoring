import { esc } from './ui.js';

const number = value => new Intl.NumberFormat('en-PH', { maximumFractionDigits: 1 }).format(Number(value || 0));
export const weekLabel = value => new Intl.DateTimeFormat('en-PH', { month: 'short', day: 'numeric' }).format(new Date(`${value}T00:00:00`));

function plot(weekly, values, maximum, isHours, compact, title) {
  const width = compact ? 420 : 720;
  const left = compact ? 44 : 48;
  const right = width - (compact ? 14 : 18);
  const topY = 16;
  const bottomY = 172;
  const x = index => weekly.length === 1 ? (left + right) / 2 : left + index * (right - left) / (weekly.length - 1);
  const y = value => bottomY - value / maximum * (bottomY - topY);
  const path = values.map((value, index) => `${index ? 'L' : 'M'}${x(index).toFixed(1)} ${y(value).toFixed(1)}`).join(' ');
  const ticks = [0, 1, 2, 3, 4].map(index => {
    const value = maximum * (4 - index) / 4;
    const position = y(value);
    return `<line x1="${left}" y1="${position}" x2="${right}" y2="${position}" class="report-gridline"/>
      <text x="${left - 8}" y="${position + 4}" text-anchor="end">${number(value)}${isHours ? '' : '%'}</text>`;
  }).join('');
  const count = Math.min(compact ? 4 : 6, weekly.length);
  const labelIndexes = new Set(Array.from({ length: count }, (_, index) => Math.round(index * (weekly.length - 1) / Math.max(1, count - 1))));
  const labels = weekly.map((row, index) => labelIndexes.has(index)
    ? `<text x="${x(index)}" y="208" text-anchor="${index === 0 ? 'start' : index === weekly.length - 1 ? 'end' : 'middle'}">${esc(weekLabel(row.week_start))}</text>` : '').join('');
  const points = weekly.map((row, index) => `<circle cx="${x(index)}" cy="${y(values[index])}" r="4.5" class="report-line-point"><title>Week of ${esc(weekLabel(row.week_start))}: ${number(values[index])}${isHours ? ' hours' : '%'}</title></circle>`).join('');
  return `<svg class="report-line-svg ${compact ? 'compact' : 'wide'} ${isHours ? 'hours' : 'attendance'}" viewBox="0 0 ${width} 224" role="img" aria-label="${esc(title)}: ${number(values[0])}${isHours ? ' hours' : '%'} in the first week, ${number(values[values.length - 1])}${isHours ? ' hours' : '%'} in the latest week">
    ${ticks}<path d="${path}" class="report-line-path"/>${points}${labels}</svg>`;
}

export function lineChart(weekly, metric, demo = false) {
  const isHours = metric === 'hours';
  const title = isHours ? (demo ? 'Example teaching hours' : 'Verified teaching hours')
    : (demo ? 'Example attendance rate' : 'Full-period attendance rate');
  const description = demo
    ? (isHours ? 'Illustrative weekly hours, separate from real attendance.' : 'Illustrative full-period classes as a share of scheduled classes.')
    : (isHours ? 'Hours supported by approved attendance evidence.' : 'Classes verified for the full scheduled period, as a share of scheduled classes.');
  if (!weekly.length) {
    return `<section class="report-line-panel" aria-label="${title}"><h3>${title}</h3><p>${description}</p>
      <div class="report-line-empty-stage"><svg class="report-line-svg empty" viewBox="0 0 720 225" role="img" aria-label="No verified records to plot for ${title.toLowerCase()}">
        <line x1="43" y1="18" x2="690" y2="18" class="report-gridline"/>
        <line x1="43" y1="96" x2="690" y2="96" class="report-gridline"/>
        <line x1="43" y1="174" x2="690" y2="174" class="report-gridline"/>
      </svg><span>No verified records yet</span></div></section>`;
  }
  const values = weekly.map(row => isHours
    ? Math.max(0, Number(row.verified_hours || 0))
    : Math.min(100, Math.max(0, Number(row.full_period_sessions || 0) / Math.max(1, Number(row.scheduled_sessions || 0)) * 100)));
  const maximum = isHours ? Math.max(2, Math.ceil(Math.max(...values, 0) / 2) * 2) : 100;
  const latest = values[values.length - 1];
  const unit = isHours ? 'hours' : '%';
  return `<section class="report-line-panel" aria-label="${title}">
    <div class="report-line-heading"><div><h3>${title}</h3><p>${description}</p></div>
      <div class="report-line-current"><span>Latest week · ${esc(weekLabel(weekly[weekly.length - 1].week_start))}</span><strong>${number(latest)}<small>${unit}</small></strong></div></div>
    ${plot(weekly, values, maximum, isHours, false, title)}
    ${plot(weekly, values, maximum, isHours, true, title)}
    <details class="report-chart-values"><summary>View weekly values</summary><div class="table-wrap"><table><thead><tr><th>Week of</th><th class="num">${isHours ? 'Hours' : 'Attendance rate'}</th></tr></thead><tbody>
      ${weekly.map((row, index) => `<tr><td>${esc(weekLabel(row.week_start))}</td><td class="num">${number(values[index])}${isHours ? '' : '%'}</td></tr>`).join('')}
    </tbody></table></div></details>
  </section>`;
}
