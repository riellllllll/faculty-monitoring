-- 010 — Attendance hours require the layered proof described in the study.
-- The geofence on a session is a historical snapshot of the room's campus area.
ALTER TABLE class_sessions ADD COLUMN planned_geofence_id BIGINT UNSIGNED NULL;
ALTER TABLE class_sessions ADD CONSTRAINT fk_class_sessions_geofence
  FOREIGN KEY (planned_geofence_id) REFERENCES campus_geofences (id)
  ON DELETE RESTRICT ON UPDATE CASCADE;
UPDATE class_sessions cs JOIN rooms r ON r.id = cs.planned_room_id
  SET cs.planned_geofence_id = r.geofence_id
  WHERE cs.planned_geofence_id IS NULL;

DROP VIEW IF EXISTS v_teaching_hours;
DROP VIEW IF EXISTS v_session_attendance;

CREATE OR REPLACE VIEW v_verified_attendance_events AS
SELECT e.id, e.class_session_id, e.event_type, e.recorded_at
FROM attendance_events e
JOIN class_sessions cs ON cs.id = e.class_session_id
JOIN attendance_photos photo ON photo.attendance_event_id = e.id
JOIN attendance_geofence_checks geo ON geo.attendance_event_id = e.id AND geo.passed = 1
JOIN attendance_qr_checks qr ON qr.attendance_event_id = e.id AND qr.passed = 1
JOIN room_qr_credentials credential ON credential.id = qr.qr_credential_id
WHERE e.status = 'verified'
  AND cs.status = 'scheduled'
  AND cs.planned_geofence_id = geo.geofence_id
  AND cs.planned_room_id = credential.room_id
  AND credential.valid_from <= e.recorded_at
  AND (credential.valid_until IS NULL OR e.recorded_at < credential.valid_until)
  AND (credential.revoked_at IS NULL OR e.recorded_at < credential.revoked_at);

CREATE OR REPLACE VIEW v_session_evidence AS
SELECT cs.id AS class_session_id, cs.session_date, cs.schedule_id,
       tl.faculty_id, sec.program_id, cs.planned_room_id,
       cs.planned_start_at, cs.planned_end_at, cs.status AS session_status,
       ci.recorded_at AS check_in_at, co.recorded_at AS check_out_at,
       mr.id AS approved_manual_request_id,
       mr.proposed_start_at AS manual_start_at, mr.proposed_end_at AS manual_end_at,
       EXISTS (SELECT 1 FROM attendance_flags af
               WHERE af.class_session_id = cs.id AND af.severity = 'blocking'
                 AND af.resolved_at IS NULL) AS has_blocking_flag
FROM class_sessions cs
JOIN schedules sc ON sc.id = cs.schedule_id
JOIN teaching_loads tl ON tl.id = sc.teaching_load_id
JOIN sections sec ON sec.id = tl.section_id
LEFT JOIN v_verified_attendance_events ci
  ON ci.class_session_id = cs.id AND ci.event_type = 'check_in'
LEFT JOIN v_verified_attendance_events co
  ON co.class_session_id = cs.id AND co.event_type = 'check_out'
LEFT JOIN manual_time_requests mr ON mr.class_session_id = cs.id
  AND mr.id = (SELECT MAX(mr2.id) FROM manual_time_requests mr2
               JOIN manual_time_decisions md2 ON md2.manual_time_request_id = mr2.id
               WHERE mr2.class_session_id = cs.id AND md2.decision = 'approved');

CREATE OR REPLACE VIEW v_session_attendance AS
SELECT e.class_session_id, e.session_date, e.schedule_id, e.faculty_id,
       e.program_id, e.planned_room_id, e.planned_start_at, e.planned_end_at,
       e.check_in_at, e.check_out_at, e.approved_manual_request_id,
       CASE
         WHEN e.session_status = 'cancelled' OR e.has_blocking_flag = 1 THEN 0
         WHEN e.check_in_at IS NOT NULL AND e.check_out_at IS NOT NULL
              AND e.check_in_at < e.check_out_at
           THEN GREATEST(0, TIMESTAMPDIFF(SECOND,
                GREATEST(e.check_in_at, e.planned_start_at),
                LEAST(e.check_out_at, e.planned_end_at)))
         WHEN e.approved_manual_request_id IS NOT NULL
           THEN GREATEST(0, TIMESTAMPDIFF(SECOND,
                GREATEST(e.manual_start_at, e.planned_start_at),
                LEAST(e.manual_end_at, e.planned_end_at)))
         ELSE 0
       END AS verified_seconds,
       CASE
         WHEN e.session_status = 'cancelled' OR e.has_blocking_flag = 1 THEN 0
         WHEN e.check_in_at IS NOT NULL AND e.check_out_at IS NOT NULL
              AND e.check_in_at < e.check_out_at
           THEN IF(e.check_in_at <= e.planned_start_at
                   AND e.check_out_at >= e.planned_end_at, 1, 0)
         WHEN e.approved_manual_request_id IS NOT NULL
           THEN IF(e.manual_start_at <= e.planned_start_at
                   AND e.manual_end_at >= e.planned_end_at, 1, 0)
         ELSE 0
       END AS full_period_verified
FROM v_session_evidence e;

CREATE OR REPLACE VIEW v_teaching_hours AS
SELECT faculty_id, program_id, COUNT(*) AS scheduled_sessions,
       SUM(full_period_verified) AS full_period_sessions,
       ROUND(SUM(verified_seconds) / 3600, 2) AS verified_hours
FROM v_session_attendance
GROUP BY faculty_id, program_id;
