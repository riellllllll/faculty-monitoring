import './styles/app.css';
import { register, startRouter, navigate } from './core/router.js';
import { store } from './core/store.js';
import { api } from './core/api.js';

import loginPage from './pages/login.js';
import dashboardPage from './pages/dashboard.js';
import facultyPage from './pages/faculty.js';
import reportsPage from './pages/reports.js';
import schedulesPage from './pages/schedules.js';
import roomsPage from './pages/rooms.js';
import roomCheckPage from './pages/room-check.js';
import verificationPage from './pages/verification.js';
import settingsPage from './pages/settings.js';
import setPasswordPage from './pages/setPassword.js';
import verifyEmailPage from './pages/verifyEmail.js';

register('/login', loginPage);
register('/dashboard', dashboardPage);
register('/faculty', facultyPage, 'faculty.view');
register('/reports', reportsPage, ['report.view_own', 'report.view_program', 'report.view_department']);
register('/schedules', schedulesPage);
register('/rooms', roomsPage, 'room_qr.manage');
register('/room', roomCheckPage);
register('/verification', verificationPage);
register('/settings', settingsPage);
register('/set-password', setPasswordPage);
register('/verify-email', verifyEmailPage);
register('/accounts', () => { navigate('/faculty'); });
register('/', (c) => { navigate('/dashboard'); });

// bootstrap session
(async () => {
  try {
    const res = await api.get('/api/auth/me');
    store.setUser(res.data);
  } catch (e) {
    store.clear();
  }
  startRouter();
})();
