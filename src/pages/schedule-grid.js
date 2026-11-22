import { esc } from '../components/ui.js';

export const scheduleDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
export const firstMinute = 7 * 60;
export const lastMinute = 20 * 60;

export function minutes(value) {
  const [hour, minute] = String(value || '').split(':').map(Number);
  return hour * 60 + minute;
}

export function clockTime(value) {
  const total = typeof value === 'number' ? value : minutes(value);
  const hour = Math.floor(total / 60);
  return `${hour % 12 || 12}:${String(total % 60).padStart(2, '0')} ${hour < 12 ? 'AM' : 'PM'}`;
}

export function renderWeekGrid(slots, { interactive = false, selectedId = null, canDelete = false, occupied = [] } = {}) {
  const visibleDays = scheduleDays;
  const labels = Array.from({ length: 14 }, (_, index) =>
    `<span class="week-time-label" style="top:${index * 60}px">${clockTime(firstMinute + index * 60)}</span>`).join('');
  const columns = visibleDays.map(day => {
    const bookings = occupied.filter(slot => slot.day_of_week === day).map(slot => {
      const start = Math.max(firstMinute, minutes(slot.start_time));
      const end = Math.min(lastMinute, minutes(slot.end_time));
      if (!(end > start)) return '';
      const label = slot.faculty_name || 'Occupied';
      return `<div class="week-occupied" role="note" aria-label="${esc(day)} ${esc(clockTime(slot.start_time))} to ${esc(clockTime(slot.end_time))} occupied by ${esc(label)}" title="${esc(label)} · ${esc(slot.subject_code || 'Room occupied')}" style="top:${start - firstMinute}px;height:${end - start}px"><strong>${esc(label)}</strong><span>${esc(slot.subject_code || 'Room occupied')}</span></div>`;
    }).join('');
    const blocks = slots.filter(slot => slot.day_of_week === day).map(slot => {
      const start = Math.max(firstMinute, minutes(slot.start_time));
      const end = Math.min(lastMinute, minutes(slot.end_time));
      if (!(end > start)) return '';
      const tone = Number(slot.subject_id || 0) % 5;
      const label = `${clockTime(slot.start_time)}–${clockTime(slot.end_time)}`;
      const compactLabel = `${String(slot.start_time).slice(0, 5)}–${String(slot.end_time).slice(0, 5)}`;
      const subject = slot.subject_code || 'Subject';
      const room = slot.room_code || (slot.modality === 'Online' ? 'Online' : 'Room pending');
      const details = `${slot.subject_title || subject} · ${slot.room_name || room}`;
      const selected = String(slot.id) === String(selectedId);
      const popupTop = end - firstMinute > 720 ? start - firstMinute - 44 : end - firstMinute + 6;
      return `<button type="button" class="week-block tone-${tone}${slot.draft ? ' is-draft' : ''}${selected ? ' is-selected' : ''}" data-block="${esc(String(slot.id))}" style="top:${start - firstMinute}px;height:${end - start}px" ${interactive ? '' : 'tabindex="-1"'} aria-label="${esc(day)} ${esc(label)} ${esc(subject)} ${esc(room)}" title="${esc(details)}">
        <strong>${esc(subject)}</strong><span>${esc(room)}</span><small>${esc(compactLabel)}</small></button>${selected && canDelete && !slot.draft ? `<div class="week-block-menu" style="top:${popupTop}px"><button type="button" data-delete-block="${Number(slot.id)}">Delete block</button><button type="button" data-close-block aria-label="Close block actions">×</button></div>` : ''}`;
    }).join('');
    return `<div class="week-day" data-day="${day}">${bookings}${blocks}</div>`;
  }).join('');
  return `<p class="week-swipe-hint">Swipe sideways to see all six days</p><div class="week-scroll"><div class="week-calendar" style="--day-count:${visibleDays.length}" aria-label="Weekly schedule from 7 AM to 8 PM">
    <div class="week-head"><span>Time</span>${visibleDays.map(day => `<span>${day}</span>`).join('')}</div>
    <div class="week-body"><div class="week-time-rail">${labels}</div>${columns}</div>
  </div></div>`;
}

export async function downloadSchedulePng(slots, facultyName, termName) {
  const visibleDays = scheduleDays;
  const canvas = document.createElement('canvas');
  const width = 1340;
  const height = 900;
  const left = 112;
  const top = 104;
  const dayWidth = (width - left - 22) / visibleDays.length;
  const hourHeight = 58;
  canvas.width = width * 2;
  canvas.height = height * 2;
  const ctx = canvas.getContext('2d');
  if (!ctx) throw new Error('Could not prepare the schedule image.');
  ctx.scale(2, 2);
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, width, height);
  ctx.fillStyle = '#173b25';
  ctx.font = 'bold 26px sans-serif';
  ctx.fillText(facultyName, 28, 40);
  ctx.fillStyle = '#65736a';
  ctx.font = '15px sans-serif';
  ctx.fillText(`${termName} · Weekly schedule`, 28, 67);
  ctx.font = 'bold 13px sans-serif';
  visibleDays.forEach((day, index) => ctx.fillText(day, left + index * dayWidth + 10, top - 13));
  ctx.font = '12px sans-serif';
  for (let hour = 7; hour <= 20; hour++) {
    const y = top + (hour - 7) * hourHeight;
    ctx.fillStyle = '#617066';
    ctx.fillText(clockTime(hour * 60), 20, y + 4);
    ctx.fillStyle = '#dbe6dc';
    ctx.fillRect(left, y, width - left - 22, 1);
  }
  visibleDays.forEach((_, index) => {
    ctx.fillStyle = '#dbe6dc';
    ctx.fillRect(left + index * dayWidth, top, 1, 13 * hourHeight);
  });
  ctx.fillRect(width - 22, top, 1, 13 * hourHeight);
  const fills = ['#d8ece0', '#e0e9f6', '#f5e8d6', '#e8e1f2', '#dcebed'];
  slots.forEach(slot => {
    const day = visibleDays.indexOf(slot.day_of_week);
    const start = Math.max(firstMinute, minutes(slot.start_time));
    const end = Math.min(lastMinute, minutes(slot.end_time));
    if (day < 0 || end <= start) return;
    const x = left + day * dayWidth + 4;
    const y = top + (start - firstMinute) * hourHeight / 60 + 3;
    const h = (end - start) * hourHeight / 60 - 6;
    ctx.fillStyle = fills[Number(slot.subject_id || 0) % fills.length];
    ctx.fillRect(x, y, dayWidth - 8, h);
    ctx.fillStyle = '#173b25';
    const subject = slot.subject_code || 'Subject';
    const room = slot.room_code || (slot.modality === 'Online' ? 'Online' : 'Room pending');
    ctx.font = 'bold 13px sans-serif';
    ctx.fillText(`${subject} · ${slot.subject_title || subject}`, x + 8, y + 18, dayWidth - 16);
    ctx.font = '11px sans-serif';
    ctx.fillText(room, x + 8, y + 33, dayWidth - 16);
    ctx.fillText(`${clockTime(slot.start_time)}–${clockTime(slot.end_time)}`, x + 8, y + 48, dayWidth - 16);
  });
  const link = document.createElement('a');
  link.download = `${facultyName.toLowerCase().replace(/[^a-z0-9]+/g, '-')}-schedule.png`;
  const blob = await new Promise(resolve => canvas.toBlob(resolve, 'image/png'));
  if (!blob) throw new Error('Could not prepare the schedule image.');
  const url = URL.createObjectURL(blob);
  link.href = url;
  document.body.appendChild(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 60000);
}
