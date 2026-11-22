import { api } from '../core/api.js';
import { el, mount } from '../core/dom.js';
import { renderNav, bindNav } from '../components/nav.js';
import { pageHead, esc, revealStack } from '../components/ui.js';
import { lineChart } from '../components/attendanceTrend.js';

export default async function dashboardPage(container) {
  const { data: d = {} } = await api.get('/api/dashboard/stats');
  const self = d.scope === 'self';
  const chartWeekly = d.chart_source === 'none' ? [] : (d.chart_weekly || []);
  const chartDemo = d.chart_source === 'demo';
  const chartTerm = d.chart_term ? `${esc(d.chart_term.school_year)} · ${esc(d.chart_term.name)}` : 'No academic term';

  const wrap = el('div', { class: 'layout' });
  const navC = el('div');
  navC.innerHTML = renderNav('/dashboard');
  bindNav(navC);
  wrap.appendChild(navC.firstElementChild);

  const main = el('div', { class: 'main' });
  main.innerHTML = `
    ${pageHead({
      eyebrow: self ? 'My Attendance' : d.scope === 'program' ? 'Program Attendance' : 'Department Attendance',
      title: 'Dashboard',
      sub: 'Teaching hours and attendance preview',
    })}

    <section class="report-chart dashboard-trend" aria-labelledby="dashboardTrendTitle">
      <div class="report-chart-head"><div><h2 id="dashboardTrendTitle">Teaching hours and attendance</h2><p>Weekly trend · ${chartTerm}</p></div><a href="#/reports" class="dashboard-report-link">Open reports</a></div>
      ${chartDemo ? '<p class="report-demo-banner"><strong>Sample data</strong> These figures are fictional. Attendance verification is not available yet.</p>' : '<p class="report-empty">Attendance verification is not available yet.</p>'}
      <div class="report-line-panels">${lineChart(chartWeekly, 'hours', chartDemo)}${lineChart(chartWeekly, 'attendance', chartDemo)}</div>
    </section>
  `;
  wrap.appendChild(main);
  mount(container, wrap);
  revealStack(main);
}
