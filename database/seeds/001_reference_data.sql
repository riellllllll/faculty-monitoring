-- Reference roles and permissions for the working application.
INSERT INTO roles (id, code, name, scope, description) VALUES
  (2, 'chairperson', 'Department Chairperson', 'department', 'Monitors the department and manages faculty schedules.'),
  (3, 'program_coordinator', 'Program Coordinator', 'program', 'Maintains faculty records within the assigned program.'),
  (4, 'faculty', 'Faculty', 'self', 'Views own timetable and account.')
ON DUPLICATE KEY UPDATE name = VALUES(name), scope = VALUES(scope), description = VALUES(description);

INSERT INTO capabilities (id, code, description) VALUES
  (1, 'users.manage', 'Manage user accounts.'),
  (2, 'faculty.manage', 'Manage faculty records.'),
  (3, 'faculty.view', 'View faculty in assigned scope.'),
  (4, 'load.manage', 'Manage teaching loads and schedules.'),
  (5, 'load.view', 'View teaching loads and schedules.'),
  (13, 'report.view_program', 'View program attendance reports.'),
  (14, 'report.view_department', 'View department attendance reports.'),
  (15, 'report.export', 'Export attendance reports.'),
  (16, 'report.view_own', 'View own teaching-hour reports.'),
  (19, 'audit.view', 'View audit records.'),
  (26, 'room_qr.manage', 'View and print room QR cards.')
ON DUPLICATE KEY UPDATE description = VALUES(description);

INSERT IGNORE INTO role_capabilities (role_id, capability_id) VALUES
  (2,1),(2,2),(2,3),(2,4),(2,5),(2,14),(2,15),(2,16),(2,19),
  (2,26),
  (3,2),(3,3),(3,5),(3,13),(3,16),
  (4,5),(4,16);

