-- Attendance collection has no routes yet. Refuse to discard any collected data.
CREATE TEMPORARY TABLE attendance_cleanup_guard (
  rows_found BIGINT NOT NULL CHECK (rows_found = 0)
);
INSERT INTO attendance_cleanup_guard (rows_found)
SELECT (SELECT COUNT(*) FROM class_sessions)
     + (SELECT COUNT(*) FROM attendance_events)
     + (SELECT COUNT(*) FROM attendance_photos)
     + (SELECT COUNT(*) FROM attendance_qr_checks)
     + (SELECT COUNT(*) FROM room_qr_credentials)
     + (SELECT COUNT(*) FROM manual_time_requests)
     + (SELECT COUNT(*) FROM manual_time_decisions);
DROP TEMPORARY TABLE attendance_cleanup_guard;

DROP VIEW IF EXISTS v_teaching_hours;
DROP VIEW IF EXISTS v_session_attendance;
DROP VIEW IF EXISTS v_session_evidence;
DROP VIEW IF EXISTS v_verified_attendance_events;

DROP TABLE manual_time_decisions;
DROP TABLE manual_time_requests;
DROP TABLE attendance_photos;
DROP TABLE attendance_qr_checks;
DROP TABLE attendance_events;
DROP TABLE room_qr_credentials;
DROP TABLE class_sessions;

DELETE FROM capabilities WHERE code IN (
  'attendance.record', 'attendance.view_own', 'attendance.view_department',
  'attendance.review_manual', 'attendance.flag_review', 'geofence.manage'
);
UPDATE capabilities SET description = 'View and print room QR cards.'
  WHERE code = 'room_qr.manage';
UPDATE roles SET description = 'Manages accounts, schedules, and room QR cards.' WHERE code = 'admin';
UPDATE roles SET description = 'Monitors the department and manages faculty schedules.' WHERE code = 'chairperson';
UPDATE roles SET description = 'Views own timetable and account.' WHERE code = 'faculty';
