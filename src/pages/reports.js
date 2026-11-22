import { api } from '../core/api.js';
import { el, mount } from '../core/dom.js';
import { renderNav, bindNav } from '../components/nav.js';
import { pageHead, esc, revealStack } from '../components/ui.js';
import { lineChart, weekLabel } from '../components/attendanceTrend.js';

const hours = value => new Intl.NumberFormat(undefined, { maximumFractionDigits: 2 }).format(Number(value || 0));

function reportContent(data) {
  const rows = data.rows || [];
  const total = rows.reduce((sum, row) => sum + Number(row.planned_hours || 0), 0);
  const samples = rows.reduce((sum, row) => sum + Number(row.sample_hours || 0), 0);
  const slots = rows.reduce((sum, row) => sum + Number(row.slot_count || 0), 0);
  const facultyCount = new Set(rows.map(row => String(row.faculty_id))).size;
  const chartWeekly = data.demo_weekly || [];
  const isDemo = chartWeekly.length > 0;
  const selectedName = (data.faculty || []).find(person => Number(person.id) === Number(data.selected_faculty_id))?.name;

  return `<section class="report-chart" aria-labelledby="reportChartTitle">
      <div class="report-chart-head"><div><h2 id="reportChartTitle">Teaching hours and attendance</h2><p>${data.scope === 'self' ? 'Your weekly preview.' : selectedName ? `${esc(selectedName)} · weekly preview.` : 'Department or program weekly preview.'}</p></div></div>
      ${isDemo ? '<p class="report-demo-banner"><strong>Sample data</strong> These figures are fictional and are not faculty attendance records.</p>' : ''}
      <div class="report-line-panels">${lineChart(chartWeekly, 'hours', isDemo)}${lineChart(chartWeekly, 'attendance', isDemo)}</div>
      ${chartWeekly.length ? `<div class="report-line-data table-wrap"><table><caption>Illustrative weekly values</caption><thead><tr><th>Week of</th><th class="num">Example hours</th><th class="num">Full-period classes</th><th class="num">Scheduled classes</th><th class="num">Attendance rate</th></tr></thead>
        <tbody>${chartWeekly.map(row => `<tr><td>${esc(weekLabel(row.week_start))}</td><td class="num">${hours(row.verified_hours)}</td><td class="num">${Number(row.full_period_sessions)}</td><td class="num">${Number(row.scheduled_sessions)}</td><td class="num">${hours(Number(row.full_period_sessions) / Math.max(1, Number(row.scheduled_sessions)) * 100)}%</td></tr>`).join('')}</tbody></table></div>`
      : `<p class="report-empty">No verified teaching hours or full-period attendance records are available for this selection.</p>`}
    </section>
    <section class="report-detail" aria-labelledby="reportDetailTitle"><h2 id="reportDetailTitle">Planned teaching load</h2>
      <p class="report-detail-intro">Recurring schedule slots are shown separately from verified attendance.</p>
      <div class="report-overview"><span><strong>${facultyCount}</strong> scheduled faculty</span><span><strong>${slots}</strong> weekly slots</span><span><strong>${hours(total)}</strong> planned hours/week</span></div>
      ${samples > 0 ? `<p class="report-provenance">${hours(samples)} planned hours come from sample timetable slots. Confirm these against the approved schedule before using them for decisions.</p>` : ''}
      ${rows.length ? `
      <div class="table-wrap"><table><thead><tr><th>Faculty</th><th>Program</th><th class="num">Subjects</th><th class="num">Weekly slots</th><th class="num">Entered hours</th><th class="num">Sample hours</th><th class="num">Total hours/week</th></tr></thead>
      <tbody>${rows.map(row => `<tr><td>${esc(row.faculty_name)}</td><td>${esc(row.program_code)}</td><td class="num">${Number(row.subject_count)}</td><td class="num">${Number(row.slot_count)}</td><td class="num">${hours(row.entered_hours)}</td><td class="num">${hours(row.sample_hours)}</td><td class="num"><strong>${hours(row.planned_hours)}</strong></td></tr>`).join('')}</tbody></table></div>
      ` : '<p class="report-empty">No active class slots are scheduled for this term and program.</p>'}</section>`;
}

export default function reportsPage(container) {
  const wrap = el('div', { class: 'layout' });
  const navC = el('div');
  navC.innerHTML = renderNav('/reports');
  bindNav(navC);
  wrap.appendChild(navC.firstElementChild);

  const main = el('main', { class: 'main report-main' });
  main.innerHTML = `${pageHead({ eyebrow: 'Attendance', title: 'Reports',
    sub: 'Review teaching hours and attendance for an academic term.' })}
    <div id="reportBody" aria-live="polite"><p class="report-empty">Loading report…</p></div>`;
  wrap.appendChild(main);
  mount(container, wrap);
  revealStack(main);

  let sequence = 0;
  const load = async () => {
    const current = ++sequence;
    const termId = main.querySelector('#reportTerm').value;
    const programId = main.querySelector('#reportProgram')?.value;
    const facultyId = main.querySelector('#reportFaculty')?.value;
    const results = main.querySelector('#reportResults');
    results.innerHTML = '<p class="report-empty">Loading report…</p>';
    const query = new URLSearchParams();
    if (termId) query.set('semester_id', termId);
    if (programId) query.set('program_id', programId);
    if (facultyId) query.set('faculty_id', facultyId);
    try {
      const response = await api.get(`/api/reports/scheduled-load?${query}`);
      if (current === sequence) results.innerHTML = reportContent(response.data);
    } catch (error) {
      if (current === sequence) results.innerHTML = `<p class="report-empty">${esc(error.message || 'Could not load the report.')}</p>`;
    }
  };
  const loadInitial = async () => {
    const body = main.querySelector('#reportBody');
    try {
      const { data } = await api.get('/api/reports/scheduled-load');
      const ownReport = data.scope === 'self';
      main.querySelector('.page-head h1').textContent = ownReport ? 'My reports' : 'Reports';
      main.querySelector('.page-sub').textContent = ownReport
        ? 'Your teaching schedule and attendance report.' : 'Review planned teaching loads and attendance.';
      body.innerHTML = `<div class="report-controls"><label>Academic term<select id="reportTerm" ${(data.terms || []).length ? '' : 'disabled'}>
        ${(data.terms || []).map(term => `<option value="${Number(term.id)}" ${Number(term.id) === Number(data.selected_term_id) ? 'selected' : ''}>${esc(term.school_year)} · ${esc(term.name)}</option>`).join('')}</select></label>
        ${ownReport ? '' : `<label>Program<select id="reportProgram"><option value="">${data.scope === 'program' ? 'All assigned programs' : 'All programs'}</option>
        ${(data.programs || []).map(program => `<option value="${Number(program.id)}">${esc(program.code)} · ${esc(program.name)}</option>`).join('')}</select></label>`}
        ${data.scope === 'department' ? `<label>Faculty<select id="reportFaculty"><option value="">All faculty</option>
        ${(data.faculty || []).map(person => `<option value="${Number(person.id)}">${esc(person.name)}</option>`).join('')}</select></label>` : ''}</div>
        <div id="reportResults" aria-live="polite">${reportContent(data)}</div>`;
      body.setAttribute('aria-live', 'off');
      main.querySelector('#reportTerm').addEventListener('change', load);
      main.querySelector('#reportProgram')?.addEventListener('change', load);
      main.querySelector('#reportFaculty')?.addEventListener('change', load);
    } catch (error) {
      body.innerHTML = `<div class="report-load-error" role="alert"><p>${esc(error.message || 'Could not load the report.')}</p><button class="btn ghost" type="button" id="retryReport">Retry</button></div>`;
      body.querySelector('#retryReport').addEventListener('click', () => {
        body.innerHTML = '<p class="report-empty">Loading report…</p>';
        loadInitial();
      });
    }
  };
  loadInitial();
}
